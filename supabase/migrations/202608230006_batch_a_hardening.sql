-- Batch A hardening: all statements are rerunnable and supersede broad policies
-- and legacy overloads from migrations 001-005.
create table if not exists public.processor_materials(
  processor_id uuid not null references public.processor_profiles(id) on delete cascade,
  material_category text not null check(material_category in ('organik','anorganik')),
  material_subtype text not null,
  reference_value numeric not null default 0 check(reference_value between 0 and 1),
  active boolean not null default true,
  primary key(processor_id, material_category, material_subtype)
);
alter table public.processor_materials enable row level security;
drop policy if exists processor_materials_read on public.processor_materials;
create policy processor_materials_read on public.processor_materials for select using(
  public.is_role('admin') or exists(
    select 1 from public.processor_profiles p
    where p.id=processor_id and (p.status='approved' or p.id=auth.uid())
  )
);
revoke insert,update,delete on public.processor_materials from anon,authenticated;

-- Existing array values are migrated into the normalized table without treating
-- the substring "anorganik" as organic.
insert into public.processor_materials(processor_id,material_category,material_subtype)
select p.id,
  case when lower(trim(m)) in ('organik','kompos','sisa makanan','sayur','buah') then 'organik' else 'anorganik' end,
  trim(m)
from public.processor_profiles p cross join unnest(p.materials) m
where nullif(trim(m),'') is not null
on conflict (processor_id,material_category,material_subtype) do nothing;

create or replace function public.prevent_role_escalation() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  if tg_op='UPDATE' and old.primary_role is distinct from new.primary_role
     and session_user not in ('postgres','service_role')
     and coalesce(auth.jwt()->>'role','')<>'service_role' then
    raise exception 'primary_role_is_immutable';
  end if;
  if new.primary_role in ('admin','dlh')
     and session_user not in ('postgres','service_role')
     and coalesce(auth.jwt()->>'role','')<>'service_role' then
    raise exception 'privileged_role_requires_server_provisioning';
  end if;
  return new;
end; $$;
drop trigger if exists profiles_role_guard on public.profiles;
create trigger profiles_role_guard before insert or update of primary_role on public.profiles
for each row execute procedure public.prevent_role_escalation();

create or replace function public.provision_privileged_profile(
  p_user_id uuid,p_role public.app_role,p_name text,p_email text default null
) returns void language plpgsql security definer set search_path=public as $$
begin
  if not (
    session_user in ('postgres','service_role') or
    coalesce(auth.jwt()->>'role','')='service_role'
  ) or p_role not in ('admin','dlh') then
    raise exception 'admin_provisioning_required';
  end if;
  insert into public.profiles(id,name,email,primary_role)
  values(p_user_id,coalesce(nullif(trim(p_name),''),'Privileged user'),p_email,p_role)
  on conflict(id) do update set name=excluded.name,email=excluded.email,primary_role=excluded.primary_role;
  insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),'provision_privileged_profile','profile',p_user_id,jsonb_build_object('role',p_role));
end; $$;
revoke execute on function public.provision_privileged_profile(uuid,public.app_role,text,text) from public,anon,authenticated;
grant execute on function public.provision_privileged_profile(uuid,public.app_role,text,text) to service_role;

drop policy if exists processors_manage on public.processor_profiles;
drop policy if exists processors_self_operational on public.processor_profiles;
drop policy if exists processors_admin_review on public.processor_profiles;
revoke insert,update,delete on public.processor_profiles from anon,authenticated;

create or replace function public.upsert_processor_application(
  p_display_name text,p_processor_type text,p_materials text[],p_total_capacity_kg numeric,
  p_service_radius_km numeric,p_minimum_pickup_kg numeric,p_administrative_area text,p_evidence_path text
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
  if auth.uid() is null or not public.is_role('pengolah') then raise exception 'pengolah_required'; end if;
  if nullif(trim(coalesce(p_display_name,'')),'') is null or p_total_capacity_kg<=0
     or p_service_radius_km<=0 or p_minimum_pickup_kg<=0 then
    raise exception 'invalid_processor_application';
  end if;
  insert into public.processor_profiles(
    id,display_name,processor_type,status,materials,total_capacity_kg,
    available_capacity_kg,service_radius_km,minimum_pickup_kg,administrative_area,evidence_path
  ) values(
    auth.uid(),trim(p_display_name),trim(p_processor_type),'pending',coalesce(p_materials,'{}'),
    p_total_capacity_kg,p_total_capacity_kg,p_service_radius_km,p_minimum_pickup_kg,
    coalesce(trim(p_administrative_area),''),nullif(trim(p_evidence_path),'')
  ) on conflict(id) do update set
    display_name=excluded.display_name,processor_type=excluded.processor_type,
    materials=excluded.materials,total_capacity_kg=excluded.total_capacity_kg,
    available_capacity_kg=least(public.processor_profiles.available_capacity_kg,excluded.total_capacity_kg),
    service_radius_km=excluded.service_radius_km,minimum_pickup_kg=excluded.minimum_pickup_kg,
    administrative_area=excluded.administrative_area,evidence_path=excluded.evidence_path,updated_at=now()
  returning id into v_id;
  delete from public.processor_materials where processor_id=v_id;
  insert into public.processor_materials(processor_id,material_category,material_subtype)
  select v_id,case when lower(trim(m)) in ('organik','kompos','sisa makanan','sayur','buah') then 'organik' else 'anorganik' end,trim(m)
  from unnest(coalesce(p_materials,'{}')) m where nullif(trim(m),'') is not null;
  insert into public.audit_events(actor_id,action,entity_type,entity_id)
  values(auth.uid(),'upsert_processor_application','processor',v_id);
  return v_id;
end; $$;

create or replace function public.update_processor_operational(
  p_active boolean,p_pickup_available boolean,p_pickup_start time,p_pickup_end time
) returns void language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null or not public.is_role('pengolah') then raise exception 'pengolah_required'; end if;
  update public.processor_profiles set active=coalesce(p_active,active),pickup_available=coalesce(p_pickup_available,pickup_available),
    pickup_start_time=p_pickup_start,pickup_end_time=p_pickup_end,updated_at=now() where id=auth.uid();
  if not found then raise exception 'processor_not_found'; end if;
  insert into public.audit_events(actor_id,action,entity_type,entity_id)
  values(auth.uid(),'update_processor_operational','processor',auth.uid());
end; $$;
revoke execute on function public.upsert_processor_application(text,text,text[],numeric,numeric,numeric,text,text) from public,anon;
grant execute on function public.upsert_processor_application(text,text,text[],numeric,numeric,numeric,text,text) to authenticated;
revoke execute on function public.update_processor_operational(boolean,boolean,time,time) from public,anon;
grant execute on function public.update_processor_operational(boolean,boolean,time,time) to authenticated;

-- Replace the legacy overload so coarse administrative area and precise address
-- have distinct destinations. The precise value never enters submissions.
drop function if exists public.create_submission(text,text,text,numeric,text,text,numeric,numeric,timestamptz,timestamptz,text);
create or replace function public.create_submission(
  p_category text,p_subtype text,p_description text,p_estimated_weight_kg numeric,
  p_district text default '',p_administrative_area text default '',p_latitude numeric default null,p_longitude numeric default null,
  p_pickup_start timestamptz default null,p_pickup_end timestamptz default null,p_source_photo_path text default null,
  p_precise_address text default ''
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid; v_city uuid;
begin
  if auth.uid() is null or not public.is_role('sumber') then raise exception 'sumber_required'; end if;
  if p_category not in('organik','anorganik') or p_estimated_weight_kg is null or p_estimated_weight_kg<=0
     or nullif(trim(coalesce(p_subtype,'')),'') is null or p_pickup_start is null or p_pickup_end is null
     or p_pickup_end<p_pickup_start then raise exception 'invalid_submission'; end if;
  select id into v_city from public.cities where code='semarang' and enabled for update;
  if v_city is null then raise exception 'city_not_configured'; end if;
  insert into public.submissions(city_id,source_user_id,material_category,material_subtype,description,estimated_weight_kg,pickup_window,administrative_area,status,source_photo_path)
  values(v_city,auth.uid(),p_category,trim(p_subtype),coalesce(p_description,''),p_estimated_weight_kg,tstzrange(p_pickup_start,p_pickup_end,'[]'),coalesce(trim(p_administrative_area),''),'submitted',p_source_photo_path)
  returning id into v_id;
  insert into public.submission_locations(submission_id,source_user_id,city_id,district,administrative_area,precise_address,precise_latitude,precise_longitude)
  values(v_id,auth.uid(),v_city,coalesce(trim(p_district),''),coalesce(trim(p_administrative_area),''),nullif(trim(p_precise_address),''),p_latitude,p_longitude);
  perform public.refresh_match_candidates(v_id);
  insert into public.audit_events(actor_id,action,entity_type,entity_id) values(auth.uid(),'create','submission',v_id);
  return v_id;
end; $$;
revoke execute on function public.create_submission(text,text,text,numeric,text,text,numeric,numeric,timestamptz,timestamptz,text,text) from public,anon;
grant execute on function public.create_submission(text,text,text,numeric,text,text,numeric,numeric,timestamptz,timestamptz,text,text) to authenticated;

create or replace function public.processor_pickup_window_matches(p_range tstzrange,p_start time,p_end time)
returns boolean language sql immutable as $$
  select p_start is null or p_end is null or (
    case when p_start<=p_end then
      ((lower(p_range) at time zone 'Asia/Jakarta')::time <= p_end and (upper(p_range) at time zone 'Asia/Jakarta')::time >= p_start)
    else
      ((upper(p_range) at time zone 'Asia/Jakarta')::time >= p_start or (lower(p_range) at time zone 'Asia/Jakarta')::time <= p_end)
    end
  );
$$;

create or replace function public.refresh_match_candidates(p_submission_id uuid) returns void
language plpgsql security definer set search_path=public as $$
declare s public.submissions;
begin
  select * into s from public.submissions where id=p_submission_id for update;
  if s.id is null or (auth.uid() is not null and s.source_user_id<>auth.uid() and not public.is_role('admin')) then raise exception 'submission_forbidden'; end if;
  delete from public.match_candidates where submission_id=p_submission_id;
  with scored as (
    select pp.id processor_id,pm.reference_value,
      case when sl.precise_latitude is null or pp.latitude is null then 1 else greatest(0,1-least(1,(abs(pp.latitude-sl.precise_latitude)+abs(pp.longitude-sl.precise_longitude))*111/greatest(pp.service_radius_km,1))) end distance_score,
      least(1,pp.available_capacity_kg/greatest(pp.total_capacity_kg,1)) capacity_score,
      case when s.estimated_weight_kg>=pp.minimum_pickup_kg then 1 else 0 end minimum_score
    from public.processor_profiles pp join public.processor_materials pm on pm.processor_id=pp.id and pm.active
    left join public.submission_locations sl on sl.submission_id=p_submission_id
    where pp.status='approved' and pp.active and pp.pickup_available and pm.material_category=s.material_category
      and lower(trim(pm.material_subtype))=lower(trim(s.material_subtype))
      and pp.available_capacity_kg>=s.estimated_weight_kg and s.estimated_weight_kg>=pp.minimum_pickup_kg
      and (sl.precise_latitude is null or (abs(pp.latitude-sl.precise_latitude)+abs(pp.longitude-sl.precise_longitude))*111<=pp.service_radius_km)
      and public.processor_pickup_window_matches(s.pickup_window,pp.pickup_start_time,pp.pickup_end_time)
  ), ranked as (
    select *,row_number() over(order by (case when s.material_category='organik' then .5+.3*distance_score+.2*capacity_score else .4+.3*reference_value+.3*minimum_score end) desc,processor_id) candidate_rank,
      (case when s.material_category='organik' then .5+.3*distance_score+.2*capacity_score else .4+.3*reference_value+.3*minimum_score end) total_score
    from scored
  )
  insert into public.match_candidates(submission_id,processor_id,rank,compatibility_score,distance_score,capacity_score,reference_value_score,minimum_volume_score,total_score)
  select p_submission_id,processor_id,candidate_rank,1,distance_score,capacity_score,reference_value,minimum_score,total_score from ranked where candidate_rank<=3;
  update public.submissions set status='matching',updated_at=now() where id=p_submission_id and status='submitted';
end; $$;
revoke execute on function public.refresh_match_candidates(uuid) from public,anon;
grant execute on function public.refresh_match_candidates(uuid) to authenticated;
