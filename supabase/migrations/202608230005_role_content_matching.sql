alter table public.processor_profiles add column if not exists active boolean not null default true;
alter table public.processor_profiles add column if not exists pickup_available boolean not null default true;
alter table public.processor_profiles add column if not exists pickup_start_time time;
alter table public.processor_profiles add column if not exists pickup_end_time time;

create or replace function public.provision_privileged_profile(p_user_id uuid,p_role public.app_role,p_name text,p_email text default null)
returns void language plpgsql security definer set search_path=public as $$
begin
  if current_user not in ('postgres','service_role') and coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'admin_provisioning_required'; end if;
  if p_role not in ('admin','dlh') then raise exception 'privileged_role_required'; end if;
  insert into public.profiles(id,name,email,primary_role) values(p_user_id,coalesce(nullif(trim(p_name),''),'Privileged user'),p_email,p_role)
    on conflict(id) do update set name=excluded.name,email=excluded.email,primary_role=excluded.primary_role;
  insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'provision_privileged_profile','profile',p_user_id,jsonb_build_object('role',p_role));
end; $$;
revoke execute on function public.provision_privileged_profile(uuid,public.app_role,text,text) from public,anon,authenticated;
grant execute on function public.provision_privileged_profile(uuid,public.app_role,text,text) to service_role;

-- Recreate the matcher with explicit operational availability and pickup-window hard filters.
create or replace function public.refresh_match_candidates(p_submission_id uuid) returns void language plpgsql security definer set search_path=public as $$
declare s public.submissions;
begin
  select * into s from public.submissions where id=p_submission_id for update;
  if s.id is null or (auth.uid() is not null and s.source_user_id<>auth.uid() and not public.is_role('admin')) then raise exception 'submission_forbidden'; end if;
  delete from public.match_candidates where submission_id=p_submission_id;
  with scored as (
    select pp.id as processor_id,
      case when sl.precise_latitude is null or sl.precise_longitude is null or pp.latitude is null or pp.longitude is null then 1 else greatest(0,1-least(1,(abs(pp.latitude-sl.precise_latitude)+abs(pp.longitude-sl.precise_longitude))*111/greatest(pp.service_radius_km,1))) end as distance_score,
      least(1,pp.available_capacity_kg/greatest(pp.total_capacity_kg,1)) as capacity_score,
      0::numeric as reference_score,
      case when s.estimated_weight_kg>=pp.minimum_pickup_kg then 1 else 0 end::numeric as minimum_score
    from public.processor_profiles pp left join public.submission_locations sl on sl.submission_id=p_submission_id
    where pp.active and pp.pickup_available and pp.status='approved' and pp.available_capacity_kg>=s.estimated_weight_kg
      and (sl.precise_latitude is null or pp.latitude is null or pp.longitude is null or (abs(pp.latitude-sl.precise_latitude)+abs(pp.longitude-sl.precise_longitude))*111<=pp.service_radius_km)
      and s.estimated_weight_kg>=pp.minimum_pickup_kg
      and (s.pickup_window is null or pp.pickup_start_time is null or pp.pickup_end_time is null or lower(s.pickup_window)::time between pp.pickup_start_time and pp.pickup_end_time)
      and exists(select 1 from unnest(pp.materials) m where lower(trim(m))=lower(trim(s.material_category)) or lower(trim(m))=lower(trim(s.material_subtype)) or (s.material_category='organik' and lower(trim(m)) in ('kompos','sisa makanan','sayur','buah')) or (s.material_category='anorganik' and lower(trim(m)) in ('plastik','kertas','kardus','logam','kaleng','botol')))
  ), ranked as (
    select *,row_number() over(order by (case when s.material_category='organik' then .5*1+.3*distance_score+.2*capacity_score else .4*1+.3*reference_score+.3*minimum_score end) desc,processor_id) as candidate_rank,
      (case when s.material_category='organik' then .5*1+.3*distance_score+.2*capacity_score else .4*1+.3*reference_score+.3*minimum_score end) as total_score from scored
  )
  insert into public.match_candidates(submission_id,processor_id,rank,compatibility_score,distance_score,capacity_score,reference_value_score,minimum_volume_score,total_score)
    select p_submission_id,processor_id,candidate_rank,1,distance_score,capacity_score,reference_score,minimum_score,total_score from ranked where candidate_rank<=3;
  update public.submissions set status='matching',updated_at=now() where id=p_submission_id and status='submitted';
end; $$;

create or replace function public.create_content_draft(p_kind text,p_title text,p_body text) returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
  if auth.uid() is null or not public.is_role('pengolah') or nullif(trim(coalesce(p_title,'')),'') is null then raise exception 'draft_forbidden'; end if;
  if p_kind='article' then insert into public.content(author_id,title,summary,body,status) values(auth.uid(),trim(p_title),trim(p_body),trim(p_body),'draft') returning id into v_id;
  elsif p_kind='event' then insert into public.events(organizer_id,title,organizer,date,location,status) values(auth.uid(),trim(p_title),trim(p_title),now(),trim(p_body),'draft') returning id into v_id;
  else raise exception 'draft_kind_invalid'; end if;
  insert into public.audit_events(actor_id,action,entity_type,entity_id) values(auth.uid(),'content_draft_create',p_kind,v_id); return v_id;
end; $$;

create or replace function public.update_content_draft(p_id uuid,p_title text,p_body text) returns void language plpgsql security definer set search_path=public as $$
declare changed integer;
begin
  if auth.uid() is null or not public.is_role('pengolah') or nullif(trim(coalesce(p_title,'')),'') is null then raise exception 'draft_update_forbidden'; end if;
  update public.content set title=trim(p_title),summary=trim(p_body),body=trim(p_body),status='draft'
    where id=p_id and author_id=auth.uid() and status in ('draft','rejected');
  get diagnostics changed=row_count;
  if changed=0 then
    update public.events set title=trim(p_title),organizer=trim(p_title),location=trim(p_body),status='draft'
      where id=p_id and organizer_id=auth.uid() and status in ('draft','rejected');
    get diagnostics changed=row_count;
  end if;
  if changed=0 then raise exception 'draft_update_forbidden'; end if;
  insert into public.audit_events(actor_id,action,entity_type,entity_id) values(auth.uid(),'content_draft_update','content',p_id);
end; $$;

create or replace function public.submit_content_draft(p_id uuid) returns void language plpgsql security definer set search_path=public as $$
declare changed integer; owner_id uuid;
begin
  if auth.uid() is null or not public.is_role('pengolah') then raise exception 'draft_forbidden'; end if;
  update public.content set status='submitted' where id=p_id and author_id=auth.uid() and status in ('draft','rejected');
  get diagnostics changed=row_count;
  if changed=0 then
    update public.events set status='submitted' where id=p_id and organizer_id=auth.uid() and status in ('draft','rejected');
    get diagnostics changed=row_count;
  end if;
  if changed=0 then raise exception 'draft_forbidden'; end if;
  insert into public.audit_events(actor_id,action,entity_type,entity_id) values(auth.uid(),'content_submit','content',p_id);
  for owner_id in select id from public.profiles where primary_role='admin' loop
    insert into public.notifications(user_id,title,body,kind) values(owner_id,'Konten menunggu moderasi','Draft baru menunggu tinjauan Admin.','content');
  end loop;
end; $$;

create or replace function public.moderate_content(p_id uuid,p_approve boolean,p_reason text) returns void language plpgsql security definer set search_path=public as $$
declare changed integer; owner_id uuid;
begin
  if not public.is_role('admin') or nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'moderation_forbidden'; end if;
  update public.content set status=case when p_approve then 'approved' else 'rejected' end where id=p_id and status='submitted' returning author_id into owner_id;
  get diagnostics changed=row_count;
  if changed=0 then
    update public.events set status=case when p_approve then 'approved' else 'rejected' end where id=p_id and status='submitted' returning organizer_id into owner_id;
  end if;
  if changed=0 and owner_id is null then raise exception 'draft_not_submitted'; end if;
  insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'content_review','content',p_id,jsonb_build_object('approve',p_approve,'reason',p_reason));
  if owner_id is not null then
    insert into public.notifications(user_id,title,body,kind) values(owner_id,'Hasil moderasi konten',case when p_approve then 'Konten disetujui Admin.' else 'Konten ditolak: '||trim(p_reason) end,'content');
  end if;
end; $$;
drop policy if exists content_author_insert on public.content;
drop policy if exists events_organizer_insert on public.events;
revoke insert,update on public.content from authenticated;
revoke insert,update on public.events from authenticated;
revoke execute on function public.create_content_draft(text,text,text) from public,anon;
revoke execute on function public.update_content_draft(uuid,text,text) from public,anon;
revoke execute on function public.submit_content_draft(uuid) from public,anon;
revoke execute on function public.moderate_content(uuid,boolean,text) from public,anon;
grant execute on function public.create_content_draft(text,text,text) to authenticated;
grant execute on function public.update_content_draft(uuid,text,text) to authenticated;
grant execute on function public.submit_content_draft(uuid) to authenticated;
grant execute on function public.moderate_content(uuid,boolean,text) to authenticated;
