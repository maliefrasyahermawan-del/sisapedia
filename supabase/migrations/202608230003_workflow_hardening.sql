-- Follow-up hardening is intentionally idempotent and safe to re-run.
-- It closes concurrent redemption and preserves reserved processor capacity.
create or replace function public.approve_redeem(p_request_id uuid,p_approve boolean,p_reason text default null)
returns void language plpgsql security definer set search_path=public as $$
declare r public.redeem_requests; balance bigint;
begin
  if not public.is_role('admin') then raise exception 'admin_required'; end if;
  select * into r from public.redeem_requests where id=p_request_id for update;
  if r.id is null then raise exception 'redeem_not_found'; end if;
  if r.status<>'submitted' then return; end if;
  -- Serialize all requests for one account before checking its ledger balance.
  perform pg_advisory_xact_lock(hashtextextended(r.user_id::text,0));
  select coalesce(sum(points),0) into balance from public.point_ledger
    where user_id=r.user_id and status='posted';
  if p_approve and balance<r.points then raise exception 'insufficient_points'; end if;
  update public.redeem_requests set status=case when p_approve then 'approved' else 'rejected' end,
    reviewed_by=auth.uid(),review_reason=p_reason,reviewed_at=now() where id=r.id;
  if p_approve then
    insert into public.point_ledger(user_id,redeem_request_id,entry_type,points,description,status)
      values(r.user_id,r.id,'redeem',-r.points,r.description,'posted')
      on conflict(redeem_request_id) do nothing;
  end if;
  insert into public.notifications(user_id,title,body,kind)
    values(r.user_id,'Status redeem diperbarui',case when p_approve then 'Redeem disetujui.' else 'Redeem ditolak.' end,'redeem');
  insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata)
    values(auth.uid(),'redeem_review','redeem_request',r.id,jsonb_build_object('approved',p_approve,'reason',p_reason));
end; $$;

create or replace function public.upsert_processor_application(
  p_display_name text,p_processor_type text,p_materials text[],p_total_capacity_kg numeric,
  p_service_radius_km numeric,p_minimum_pickup_kg numeric,p_administrative_area text,p_evidence_path text
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
  if auth.uid() is null or not public.is_role('pengolah') then raise exception 'pengolah_required'; end if;
  if p_total_capacity_kg is null or p_total_capacity_kg<=0 or p_service_radius_km<=0 or p_minimum_pickup_kg<=0 then raise exception 'invalid_processor_application'; end if;
  insert into public.processor_profiles(id,display_name,processor_type,status,materials,total_capacity_kg,available_capacity_kg,service_radius_km,minimum_pickup_kg,administrative_area,evidence_path)
    values(auth.uid(),nullif(trim(p_display_name),''),nullif(trim(p_processor_type),''),'pending',coalesce(p_materials,'{}'),p_total_capacity_kg,p_total_capacity_kg,p_service_radius_km,p_minimum_pickup_kg,coalesce(p_administrative_area,''),nullif(trim(p_evidence_path),''))
  on conflict(id) do update set display_name=excluded.display_name,processor_type=excluded.processor_type,
    materials=excluded.materials,total_capacity_kg=excluded.total_capacity_kg,
    available_capacity_kg=least(excluded.total_capacity_kg,public.processor_profiles.available_capacity_kg),
    service_radius_km=excluded.service_radius_km,minimum_pickup_kg=excluded.minimum_pickup_kg,
    administrative_area=excluded.administrative_area,evidence_path=excluded.evidence_path,updated_at=now()
  returning id into v_id;
  insert into public.audit_events(actor_id,action,entity_type,entity_id)
    values(auth.uid(),'upsert_processor_application','processor',v_id);
  return v_id;
end; $$;

revoke execute on function public.approve_redeem(uuid,boolean,text) from public,anon;
grant execute on function public.approve_redeem(uuid,boolean,text) to authenticated;
grant execute on function public.provision_privileged_profile(uuid,public.app_role,text,text) to service_role;
revoke execute on function public.upsert_processor_application(text,text,text[],numeric,numeric,numeric,text,text) from public,anon;
grant execute on function public.upsert_processor_application(text,text,text[],numeric,numeric,numeric,text,text) to authenticated;

create or replace function public.attach_source_photo(p_submission_id uuid,p_storage_path text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if nullif(trim(coalesce(p_storage_path,'')),'') is null then raise exception 'photo_path_required'; end if;
  if not exists(select 1 from public.submissions where id=p_submission_id and source_user_id=auth.uid()) then raise exception 'submission_forbidden'; end if;
  update public.submissions set source_photo_path=p_storage_path,updated_at=now() where id=p_submission_id;
  insert into public.audit_events(actor_id,action,entity_type,entity_id) values(auth.uid(),'attach_source_photo','submission',p_submission_id);
end; $$;
revoke execute on function public.attach_source_photo(uuid,text) from public,anon;
grant execute on function public.attach_source_photo(uuid,text) to authenticated;

create or replace function public.submit_redeem(p_points integer,p_description text)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
  if auth.uid() is null or not public.is_role('sumber') or p_points is null or p_points<=0 or nullif(trim(coalesce(p_description,'')),'') is null then raise exception 'invalid_redeem'; end if;
  insert into public.redeem_requests(user_id,points,description,status) values(auth.uid(),p_points,trim(p_description),'submitted') returning id into v_id;
  insert into public.audit_events(actor_id,action,entity_type,entity_id) values(auth.uid(),'redeem_submit','redeem_request',v_id);
  return v_id;
end; $$;
revoke execute on function public.submit_redeem(integer,text) from public,anon;
grant execute on function public.submit_redeem(integer,text) to authenticated;
revoke insert on public.redeem_requests from authenticated,anon;
