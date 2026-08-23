-- Batch C: explicit read grants, processor application coordinates, candidate
-- decision data, event participation RPC, and versioned aggregate provenance.
-- RLS remains the authorization boundary; these grants only make permitted
-- reads reachable by the authenticated client role.

grant select on table public.cities, public.profiles, public.processor_profiles,
  public.processor_materials, public.submissions, public.submission_locations,
  public.match_candidates, public.offers, public.transactions,
  public.point_ledger, public.redeem_requests, public.notifications,
  public.content, public.events, public.event_participation,
  public.formula_versions, public.baselines, public.audit_events
  to authenticated;
grant select on table public.cities, public.content, public.events to anon;
revoke insert, update, delete on table public.event_participation from anon, authenticated;

alter table public.match_candidates
  add column if not exists approximate_distance_km numeric;

create or replace function public.join_event(p_event_id uuid)
returns void
language plpgsql security definer set search_path=public
as $$
declare v_event public.events;
begin
  if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid()) then
    raise exception 'authentication_required';
  end if;
  select * into v_event from public.events where id=p_event_id for update;
  if v_event.id is null or v_event.status <> 'approved' then
    raise exception 'event_not_available';
  end if;
  insert into public.event_participation(event_id,user_id)
    values(p_event_id,auth.uid()) on conflict(event_id,user_id) do nothing;
  insert into public.audit_events(actor_id,action,entity_type,entity_id)
    values(auth.uid(),'join_event','event',p_event_id);
end;
$$;
revoke execute on function public.join_event(uuid) from public, anon;
grant execute on function public.join_event(uuid) to authenticated;

-- The ten-argument overload is the canonical application contract. The old
-- overload remains as a compatibility shim for older clients but cannot
-- create an application without valid facility coordinates.
create or replace function public.upsert_processor_application(
  p_display_name text,p_processor_type text,p_materials text[],
  p_total_capacity_kg numeric,p_service_radius_km numeric,
  p_minimum_pickup_kg numeric,p_administrative_area text,p_evidence_path text,
  p_latitude numeric,p_longitude numeric
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid; v_path text;
begin
  if auth.uid() is null or not public.is_role('pengolah') then
    raise exception 'pengolah_required';
  end if;
  if nullif(trim(coalesce(p_display_name,'')),'') is null
     or p_total_capacity_kg is null or p_total_capacity_kg <= 0
     or p_service_radius_km is null or p_service_radius_km <= 0
     or p_minimum_pickup_kg is null or p_minimum_pickup_kg <= 0
     or p_latitude is null or p_latitude < -90 or p_latitude > 90
     or p_longitude is null or p_longitude < -180 or p_longitude > 180 then
    raise exception 'invalid_processor_application';
  end if;
  v_path := nullif(trim(p_evidence_path),'');
  if v_path is not null and (
    v_path !~ ('^' || auth.uid()::text || '/[^/]+$')
    or not exists(select 1 from storage.objects o
      where o.bucket_id='processor-evidence' and o.name=v_path
        and o.owner_id=auth.uid()::text)
  ) then raise exception 'processor_evidence_not_owned'; end if;
  insert into public.processor_profiles(
    id,display_name,processor_type,status,materials,total_capacity_kg,
    available_capacity_kg,service_radius_km,minimum_pickup_kg,
    administrative_area,evidence_path,latitude,longitude
  ) values(
    auth.uid(),trim(p_display_name),trim(p_processor_type),'pending',coalesce(p_materials,'{}'),
    p_total_capacity_kg,p_total_capacity_kg,p_service_radius_km,p_minimum_pickup_kg,
    coalesce(trim(p_administrative_area),''),v_path,p_latitude,p_longitude
  ) on conflict(id) do update set
    display_name=excluded.display_name,processor_type=excluded.processor_type,
    materials=excluded.materials,total_capacity_kg=excluded.total_capacity_kg,
    available_capacity_kg=least(public.processor_profiles.available_capacity_kg,excluded.total_capacity_kg),
    service_radius_km=excluded.service_radius_km,minimum_pickup_kg=excluded.minimum_pickup_kg,
    administrative_area=excluded.administrative_area,evidence_path=excluded.evidence_path,
    latitude=excluded.latitude,longitude=excluded.longitude,updated_at=now();
  delete from public.processor_materials where processor_id=auth.uid();
  insert into public.processor_materials(processor_id,material_category,material_subtype)
    select auth.uid(),case when lower(trim(m)) in ('organik','kompos','sisa makanan','sayur','buah')
      then 'organik' else 'anorganik' end,lower(trim(m))
    from unnest(coalesce(p_materials,'{}')) m where nullif(trim(m),'') is not null
    on conflict do nothing;
  v_id := auth.uid();
  insert into public.audit_events(actor_id,action,entity_type,entity_id)
    values(auth.uid(),'upsert_processor_application','processor',v_id);
  return v_id;
end;
$$;

create or replace function public.upsert_processor_application(
  p_display_name text,p_processor_type text,p_materials text[],
  p_total_capacity_kg numeric,p_service_radius_km numeric,
  p_minimum_pickup_kg numeric,p_administrative_area text,p_evidence_path text
) returns uuid language plpgsql security definer set search_path=public as $$
declare p public.processor_profiles;
begin
  select * into p from public.processor_profiles where id=auth.uid();
  return public.upsert_processor_application(
    p_display_name,p_processor_type,p_materials,p_total_capacity_kg,
    p_service_radius_km,p_minimum_pickup_kg,p_administrative_area,p_evidence_path,
    p.latitude,p.longitude);
end;
$$;
revoke execute on function public.upsert_processor_application(text,text,text[],numeric,numeric,numeric,text,text) from public,anon;
revoke execute on function public.upsert_processor_application(text,text,text[],numeric,numeric,numeric,text,text,numeric,numeric) from public,anon;
grant execute on function public.upsert_processor_application(text,text,text[],numeric,numeric,numeric,text,text) to authenticated;
grant execute on function public.upsert_processor_application(text,text,text[],numeric,numeric,numeric,text,text,numeric,numeric) to authenticated;

drop policy if exists processor_evidence_upload on storage.objects;
drop policy if exists processor_evidence_admin on storage.objects;
drop policy if exists processor_evidence_owner_insert on storage.objects;
create policy processor_evidence_owner_insert on storage.objects for insert to authenticated
  with check(bucket_id='processor-evidence' and owner_id=auth.uid()::text
    and name ~ ('^' || auth.uid()::text || '/[^/]+$')
    and public.is_role('pengolah'));
create policy processor_evidence_admin on storage.objects for select to authenticated
  using(bucket_id='processor-evidence' and
    (owner_id=auth.uid()::text or public.is_role('admin')));

create or replace function public.approve_processor(
  p_processor_id uuid,p_approve boolean,p_reason text
) returns void language plpgsql security definer set search_path=public as $$
declare p public.processor_profiles;
begin
  if not public.is_role('admin') or nullif(trim(coalesce(p_reason,'')),'') is null then
    raise exception 'admin_required';
  end if;
  select * into p from public.processor_profiles where id=p_processor_id for update;
  if p.id is null or p.status not in ('pending','rejected') then raise exception 'processor_not_reviewable'; end if;
  if p_approve and (p.latitude is null or p.longitude is null or p.evidence_path is null
      or not exists(select 1 from storage.objects o where o.bucket_id='processor-evidence'
        and o.name=p.evidence_path and o.owner_id=p.id::text)) then
    raise exception 'processor_application_incomplete';
  end if;
  update public.processor_profiles set status=case when p_approve then 'approved' else 'rejected' end,updated_at=now()
    where id=p.id and status in ('pending','rejected');
  insert into public.notifications(user_id,title,body,kind) values(p.id,'Hasil verifikasi Pengolah',
    case when p_approve then 'Pengajuan disetujui.' else 'Pengajuan ditolak: '||trim(p_reason) end,'processor_review');
  insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata)
    values(auth.uid(),'processor_review','processor',p.id,jsonb_build_object('approve',p_approve,'reason',trim(p_reason)));
end;
$$;

-- Exact matching uses normalized processor_materials rows. Every candidate is
-- scored before the top three are selected; no substring match can make
-- Anorganik look like Organik.
create or replace function public.refresh_match_candidates(p_submission_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare s public.submissions;
begin
  select * into s from public.submissions where id=p_submission_id for update;
  if s.id is null or (auth.uid() is not null and s.source_user_id<>auth.uid() and not public.is_role('admin')) then
    raise exception 'submission_forbidden';
  end if;
  delete from public.match_candidates where submission_id=p_submission_id;
  with scored as (
    select pp.id processor_id,
      pm.reference_value,
      case when sl.precise_latitude is null or sl.precise_longitude is null then null
        else round((abs(pp.latitude-sl.precise_latitude)+abs(pp.longitude-sl.precise_longitude))*111,2) end approximate_distance_km,
      case when sl.precise_latitude is null or sl.precise_longitude is null or pp.latitude is null or pp.longitude is null then 1
        else greatest(0,1-least(1,(abs(pp.latitude-sl.precise_latitude)+abs(pp.longitude-sl.precise_longitude))*111/greatest(pp.service_radius_km,1))) end distance_score,
      least(1,pp.available_capacity_kg/greatest(pp.total_capacity_kg,1)) capacity_score,
      case when s.estimated_weight_kg>=pp.minimum_pickup_kg then 1 else 0 end minimum_score
    from public.processor_profiles pp
    join public.processor_materials pm on pm.processor_id=pp.id and pm.active
      and pm.material_category=s.material_category
      and lower(trim(pm.material_subtype))=lower(trim(s.material_subtype))
    left join public.submission_locations sl on sl.submission_id=p_submission_id
    where pp.status='approved' and pp.active and pp.pickup_available
      and pp.latitude is not null and pp.longitude is not null
      and pp.available_capacity_kg>=s.estimated_weight_kg
      and s.estimated_weight_kg>=pp.minimum_pickup_kg
      and (sl.precise_latitude is null or (abs(pp.latitude-sl.precise_latitude)+abs(pp.longitude-sl.precise_longitude))*111<=pp.service_radius_km)
      and public.processor_pickup_window_matches(s.pickup_window,pp.pickup_start_time,pp.pickup_end_time)
  ), scored_total as (
    select *,case when s.material_category='organik'
      then .5*1+.3*distance_score+.2*capacity_score
      else .4*1+.3*reference_value+.3*minimum_score end total_score
    from scored
  ), ranked as (
    select *,row_number() over(order by total_score desc,processor_id) candidate_rank from scored_total
  )
  insert into public.match_candidates(submission_id,processor_id,rank,compatibility_score,distance_score,
    capacity_score,reference_value_score,minimum_volume_score,total_score,approximate_distance_km)
  select p_submission_id,processor_id,candidate_rank,1,distance_score,capacity_score,reference_value,minimum_score,total_score,approximate_distance_km
    from ranked where candidate_rank<=3;
  update public.submissions set status='matching',updated_at=now() where id=p_submission_id and status='submitted';
end;
$$;

-- Historical transactions retain exactly the formula and baseline used at
-- completion. The aggregate includes every stored component group.
drop function if exists public.dlh_city_metrics();
create or replace function public.dlh_city_metrics()
returns table(city_id uuid,completed_transactions bigint,organic_kg numeric,inorganic_kg numeric,
  active_sources bigint,active_processors bigint,formula_version text,baseline_id uuid,
  points_per_kg numeric,emissions_factor numeric,economic_factor numeric,target_kg numeric,
  provenance_components jsonb)
language plpgsql stable security definer set search_path=public as $$
begin
  if not (public.is_role('dlh') or public.is_role('admin')) then raise exception 'aggregate_role_required'; end if;
  return query
  with grouped as (
    select s.city_id,t.formula_version,t.baseline_id,t.points_per_kg,t.emissions_factor,t.economic_factor,
      b.target_kg,count(*) filter(where s.status='completed')::bigint completed_transactions,
      coalesce(sum(s.actual_weight_kg) filter(where s.status='completed' and s.material_category='organik'),0) organic_kg,
      coalesce(sum(s.actual_weight_kg) filter(where s.status='completed' and s.material_category='anorganik'),0) inorganic_kg,
      count(distinct s.source_user_id) filter(where s.status='completed')::bigint active_sources,
      count(distinct s.selected_processor_id) filter(where s.status='completed')::bigint active_processors
    from public.submissions s join public.transactions t on t.submission_id=s.id
      left join public.baselines b on b.id=t.baseline_id
    where s.status='completed' group by s.city_id,t.formula_version,t.baseline_id,t.points_per_kg,t.emissions_factor,t.economic_factor,b.target_kg
  )
  select g.city_id,sum(g.completed_transactions)::bigint,sum(g.organic_kg),sum(g.inorganic_kg),
    sum(g.active_sources)::bigint,sum(g.active_processors)::bigint,
    case when count(*)=1 then min(g.formula_version) else 'multiple' end,
    case when count(*)=1 then min(g.baseline_id::text)::uuid else null end,
    case when count(*)=1 then min(g.points_per_kg) else null end,
    case when count(*)=1 then min(g.emissions_factor) else null end,
    case when count(*)=1 then min(g.economic_factor) else null end,
    sum(coalesce(g.target_kg,0)),jsonb_agg(jsonb_build_object('formula_version',g.formula_version,'baseline_id',g.baseline_id,'points_per_kg',g.points_per_kg,'emissions_factor',g.emissions_factor,'economic_factor',g.economic_factor,'target_kg',g.target_kg))
  from grouped g group by g.city_id;
end;
$$;
revoke execute on function public.dlh_city_metrics() from public,anon;
grant execute on function public.dlh_city_metrics() to authenticated;

-- Terminal cancellation/rejection timestamps make retention deterministic.
create or replace function public.cancel_submission(p_submission_id uuid,p_reason text default null)
returns void language plpgsql security definer set search_path=public as $$
declare s public.submissions; v_reason text;
begin
  select * into s from public.submissions where id=p_submission_id for update;
  if s.id is null or s.source_user_id<>auth.uid() or s.status not in ('submitted','matching','offered','accepted') then raise exception 'cancel_forbidden'; end if;
  if s.status='accepted' and nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'cancel_reason_required'; end if;
  v_reason:=coalesce(nullif(trim(p_reason),''),'Dibatalkan sebelum pickup');
  update public.submissions set status='cancelled',cancellation_reason=v_reason,resolved_at=now(),updated_at=now() where id=s.id and status=s.status;
  if s.capacity_released_at is null and s.capacity_reserved_kg>0 then
    update public.processor_profiles set available_capacity_kg=least(total_capacity_kg,available_capacity_kg+s.capacity_reserved_kg) where id=s.selected_processor_id;
    update public.submissions set capacity_released_at=now() where id=s.id and capacity_released_at is null;
  end if;
  insert into public.notifications(user_id,title,body,kind) values(s.source_user_id,'Setoran dibatalkan',v_reason,'pickup');
  if s.status='accepted' and s.selected_processor_id is not null then
    insert into public.notifications(user_id,title,body,kind) values(s.selected_processor_id,'Pickup dibatalkan',v_reason,'pickup');
  end if;
  insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'cancel_submission','submission',s.id,jsonb_build_object('reason',v_reason));
end;
$$;

create or replace function public.retention_cleanup() returns void
language plpgsql security definer set search_path=public,storage as $$
begin
  delete from storage.objects o where o.bucket_id in ('source-photos','weighing-evidence') and exists(
    select 1 from public.submissions s left join public.transactions t on t.submission_id=s.id
    where (s.source_photo_path=o.name or t.weighing_evidence_path=o.name)
      and s.status in ('completed','cancelled','rejected') and coalesce(t.resolved_at,s.resolved_at)<now()-interval '90 days');
  update public.submission_locations l set precise_address=null,precise_latitude=null,precise_longitude=null
    where exists(select 1 from public.submissions s where s.id=l.submission_id and s.status in ('completed','cancelled','rejected') and s.resolved_at<now()-interval '90 days');
end;
$$;

-- Completion provenance is selected at completion time, not submission time.
create or replace function public.confirm_weight(p_submission_id uuid) returns void
language plpgsql security definer set search_path=public as $$
declare s public.submissions; t public.transactions; f public.formula_versions; b public.baselines; changed integer;
begin
  select * into s from public.submissions where id=p_submission_id for update;
  if s.id is null or s.source_user_id<>auth.uid() or s.status<>'weighed' then raise exception 'confirmation_forbidden'; end if;
  select * into t from public.transactions where submission_id=s.id for update;
  if t.id is null or t.actual_weight_kg is null then raise exception 'transaction_not_found'; end if;
  select * into f from public.formula_versions where active order by created_at desc nulls last limit 1;
  select * into b from public.baselines where city_id=s.city_id and month<=date_trunc('month',now())::date order by month desc limit 1;
  if f.id is null or b.id is null then raise exception 'formula_or_baseline_not_configured'; end if;
  update public.submissions set status='completed',formula_version=f.version,resolved_at=now(),updated_at=now()
    where id=s.id and status='weighed'; get diagnostics changed=row_count;
  if changed<>1 then raise exception 'confirmation_race'; end if;
  update public.transactions set completed_at=now(),resolved_at=now(),formula_id=f.id,formula_version=f.version,
    baseline_id=b.id,points_per_kg=f.points_per_kg,emissions_factor=f.emissions_factor,economic_factor=f.economic_factor where id=t.id;
  if s.capacity_released_at is null and s.capacity_reserved_kg>0 then
    update public.processor_profiles set available_capacity_kg=least(total_capacity_kg,available_capacity_kg+s.capacity_reserved_kg) where id=s.selected_processor_id;
    update public.submissions set capacity_released_at=now() where id=s.id and capacity_released_at is null;
  end if;
  insert into public.point_ledger(user_id,transaction_id,entry_type,points,description,status)
    values(s.source_user_id,t.id,'earn',round(t.actual_weight_kg*f.points_per_kg),'Setoran terverifikasi','posted')
    on conflict(transaction_id) where entry_type='earn' do nothing;
  insert into public.notifications(user_id,title,body,kind) values(s.source_user_id,'Poin bertambah','Setoran dikonfirmasi dan poin dicatat.','poin');
  insert into public.audit_events(actor_id,action,entity_type,entity_id) values(auth.uid(),'confirm_weight','submission',s.id);
end;
$$;

create or replace function public.resolve_dispute(p_submission_id uuid,p_approve boolean,p_reason text,p_corrected_weight_kg numeric default null)
returns void language plpgsql security definer set search_path=public as $$
declare s public.submissions; t public.transactions; f public.formula_versions; b public.baselines; final_weight numeric; changed integer;
begin
  if not public.is_role('admin') or nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'resolution_forbidden'; end if;
  select * into s from public.submissions where id=p_submission_id for update;
  if s.id is null or s.status<>'disputed' then raise exception 'dispute_not_found'; end if;
  select * into t from public.transactions where submission_id=s.id for update;
  if p_approve then
    final_weight:=coalesce(p_corrected_weight_kg,t.actual_weight_kg,s.actual_weight_kg);
    if final_weight is null or final_weight<=0 then raise exception 'corrected_weight_required'; end if;
    select * into f from public.formula_versions where active order by created_at desc nulls last limit 1;
    select * into b from public.baselines where city_id=s.city_id and month<=date_trunc('month',now())::date order by month desc limit 1;
    if f.id is null or b.id is null then raise exception 'formula_or_baseline_not_configured'; end if;
  end if;
  update public.submissions set status=(case when p_approve then 'completed' else 'cancelled' end)::public.submission_status,
    actual_weight_kg=case when p_approve then final_weight else actual_weight_kg end,
    formula_version=case when p_approve then f.version else formula_version end,resolved_at=now(),updated_at=now()
    where id=s.id and status='disputed'; get diagnostics changed=row_count;
  if changed<>1 then raise exception 'dispute_race'; end if;
  if t.id is not null then update public.transactions set actual_weight_kg=case when p_approve then final_weight else actual_weight_kg end,
    completed_at=case when p_approve then now() else completed_at end,resolved_at=now(),formula_id=case when p_approve then f.id else formula_id end,
    formula_version=case when p_approve then f.version else formula_version end,baseline_id=case when p_approve then b.id else baseline_id end,
    points_per_kg=case when p_approve then f.points_per_kg else points_per_kg end,emissions_factor=case when p_approve then f.emissions_factor else emissions_factor end,
    economic_factor=case when p_approve then f.economic_factor else economic_factor end where id=t.id; end if;
  if s.capacity_released_at is null and s.capacity_reserved_kg>0 then
    update public.processor_profiles set available_capacity_kg=least(total_capacity_kg,available_capacity_kg+s.capacity_reserved_kg) where id=s.selected_processor_id;
    update public.submissions set capacity_released_at=now() where id=s.id and capacity_released_at is null;
  end if;
  if p_approve and t.id is not null then insert into public.point_ledger(user_id,transaction_id,entry_type,points,description,status)
    values(s.source_user_id,t.id,'earn',round(final_weight*f.points_per_kg),'Sengketa diselesaikan','posted') on conflict(transaction_id) where entry_type='earn' do nothing; end if;
  insert into public.notifications(user_id,title,body,kind) values(s.source_user_id,'Sengketa selesai',case when p_approve then 'Sengketa disetujui.' else 'Transaksi dibatalkan.' end,'dispute');
  insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'resolve_dispute','submission',s.id,jsonb_build_object('approve',p_approve,'reason',trim(p_reason),'corrected_weight',p_corrected_weight_kg));
end;
$$;

do $$ begin
  alter publication supabase_realtime add table public.submissions;
exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.offers;
exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.transactions;
exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.notifications;
exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.processor_profiles;
exception when duplicate_object then null; when undefined_object then null; end $$;
