-- Batch B: lifecycle, evidence, formula provenance and trusted gateway hardening.
-- Every statement is intentionally rerunnable; this migration supersedes the
-- permissive overloads in 001-006 without requiring a destructive reset.

alter table public.formula_versions add column if not exists economic_factor numeric not null default 1;
alter table public.transactions add column if not exists formula_id uuid references public.formula_versions(id);
alter table public.transactions add column if not exists points_per_kg numeric;
alter table public.transactions add column if not exists emissions_factor numeric;
alter table public.transactions add column if not exists economic_factor numeric;
alter table public.transactions add column if not exists resolved_at timestamptz;
alter table public.submissions add column if not exists resolved_at timestamptz;

drop function if exists public.dlh_city_metrics();
create or replace function public.dlh_city_metrics()
returns table(city_id uuid,completed_transactions bigint,organic_kg numeric,inorganic_kg numeric,
  active_sources bigint,active_processors bigint,formula_version text,baseline_id uuid,
  points_per_kg numeric,emissions_factor numeric,economic_factor numeric,monthly_target_kg numeric)
language plpgsql stable security definer set search_path=public as $$
begin
  if not (public.is_role('dlh') or public.is_role('admin')) then raise exception 'dlh_required'; end if;
  return query
  select s.city_id,count(*)::bigint,
    coalesce(sum(t.actual_weight_kg) filter(where s.material_category='organik'),0),
    coalesce(sum(t.actual_weight_kg) filter(where s.material_category='anorganik'),0),
    count(distinct s.source_user_id)::bigint,count(distinct s.selected_processor_id)::bigint,
    t.formula_version,t.baseline_id,t.points_per_kg,t.emissions_factor,t.economic_factor,b.target_kg
  from public.submissions s join public.transactions t on t.submission_id=s.id
    left join public.baselines b on b.id=t.baseline_id
  where s.status='completed'
  group by s.city_id,t.formula_version,t.baseline_id,t.points_per_kg,t.emissions_factor,t.economic_factor,b.target_kg;
end; $$;
revoke execute on function public.dlh_city_metrics() from public,anon;
grant execute on function public.dlh_city_metrics() to authenticated;

-- There can only be one live offer for a submission. Selecting again safely
-- closes the previous pending offer before creating the new one.
delete from public.offers a using public.offers b
where a.status='pending' and b.status='pending' and a.submission_id=b.submission_id
  and (a.created_at>b.created_at or (a.created_at=b.created_at and a.id>b.id));
create unique index if not exists offers_one_pending_submission
  on public.offers(submission_id) where status='pending';

create table if not exists public.sari_rate_limits(
  user_id uuid primary key references public.profiles(id) on delete cascade,
  window_started timestamptz not null default now(),
  request_count integer not null default 0
);
alter table public.sari_rate_limits enable row level security;
revoke all on public.sari_rate_limits from anon,authenticated;

create or replace function public.consume_sari_rate_limit(
  p_user_id uuid, p_max_requests integer default 20
) returns boolean language plpgsql security definer set search_path=public as $$
declare r public.sari_rate_limits; allowed boolean;
begin
  if auth.uid() is null or auth.uid()<>p_user_id or not public.is_role('sumber') then
    raise exception 'sumber_required';
  end if;
  select * into r from public.sari_rate_limits where user_id=p_user_id for update;
  if r.user_id is null then
    insert into public.sari_rate_limits(user_id,window_started,request_count)
      values(p_user_id,now(),1);
    return true;
  end if;
  if r.window_started < now()-interval '1 minute' then
    update public.sari_rate_limits set window_started=now(),request_count=1 where user_id=p_user_id;
    return true;
  end if;
  allowed:=r.request_count < greatest(1,p_max_requests);
  if allowed then update public.sari_rate_limits set request_count=request_count+1 where user_id=p_user_id; end if;
  return allowed;
end; $$;
revoke execute on function public.consume_sari_rate_limit(uuid,integer) from public,anon;
grant execute on function public.consume_sari_rate_limit(uuid,integer) to authenticated;

create or replace function public.select_submission_candidate(
  p_submission_id uuid,p_processor_id uuid
) returns void language plpgsql security definer set search_path=public as $$
declare s public.submissions; c public.match_candidates; old_offer public.offers;
begin
  select * into s from public.submissions where id=p_submission_id for update;
  if s.id is null or s.source_user_id<>auth.uid() or s.status not in('matching','offered') then
    raise exception 'source_selection_forbidden';
  end if;
  select * into c from public.match_candidates where submission_id=s.id and processor_id=p_processor_id;
  if c.id is null then raise exception 'candidate_not_found'; end if;
  select * into old_offer from public.offers where submission_id=s.id and status='pending' for update;
  if old_offer.id is not null then
    update public.offers set status='rejected',rejection_reason='Sumber memilih kandidat lain',responded_at=now() where id=old_offer.id;
    insert into public.notifications(user_id,title,body,kind) values(old_offer.processor_id,'Tawaran ditutup','Sumber memilih kandidat lain.','offer');
  end if;
  update public.submissions set selected_processor_id=p_processor_id,status='offered',updated_at=now() where id=s.id;
  insert into public.offers(submission_id,processor_id,candidate_rank,status,expires_at)
    values(s.id,p_processor_id,c.rank,'pending',now()+interval '20 minutes');
  insert into public.notifications(user_id,title,body,kind) values(p_processor_id,'Tawaran pickup baru','Tawaran baru tersedia selama 20 menit.','offer');
  insert into public.audit_events(actor_id,action,entity_type,entity_id) values(auth.uid(),'select_candidate','submission',s.id);
end; $$;

create or replace function public.reject_offer(p_offer_id uuid,p_reason text) returns void
language plpgsql security definer set search_path=public as $$
declare o public.offers; s public.submissions; c public.match_candidates;
begin
  if nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'offer_reason_required'; end if;
  select * into o from public.offers where id=p_offer_id for update;
  select * into s from public.submissions where id=o.submission_id for update;
  if o.id is null or o.processor_id<>auth.uid() or o.status<>'pending' or s.status<>'offered' then raise exception 'offer_forbidden'; end if;
  update public.offers set status='rejected',rejection_reason=trim(p_reason),responded_at=now() where id=o.id;
  insert into public.notifications(user_id,title,body,kind) values(s.source_user_id,'Tawaran ditolak','Pengolah menolak tawaran: '||trim(p_reason),'offer');
  select * into c from public.match_candidates where submission_id=s.id and rank>coalesce(o.candidate_rank,0) order by rank limit 1;
  if c.id is null then
    update public.submissions set status='rejected',updated_at=now() where id=s.id and status='offered';
    insert into public.notifications(user_id,title,body,kind) values(s.source_user_id,'Tidak ada kandidat berikutnya','Semua kandidat telah menolak tawaran.','offer');
  else
    update public.submissions set selected_processor_id=c.processor_id,status='offered',updated_at=now() where id=s.id;
    insert into public.offers(submission_id,processor_id,candidate_rank,status,expires_at) values(s.id,c.processor_id,c.rank,'pending',now()+interval '20 minutes');
    insert into public.notifications(user_id,title,body,kind) values(c.processor_id,'Tawaran fallback pickup','Kandidat sebelumnya menolak; tawaran baru tersedia.','offer');
    insert into public.notifications(user_id,title,body,kind) values(s.source_user_id,'Kandidat fallback aktif','Tawaran diteruskan ke kandidat berikutnya.','offer');
  end if;
  insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'reject_offer','offer',o.id,jsonb_build_object('reason',trim(p_reason)));
end; $$;

create or replace function public.expire_offer(p_offer_id uuid) returns void
language plpgsql security definer set search_path=public as $$
declare o public.offers; s public.submissions; c public.match_candidates;
begin
  select * into o from public.offers where id=p_offer_id for update;
  if o.id is null or o.status<>'pending' or o.expires_at>now() then return; end if;
  select * into s from public.submissions where id=o.submission_id for update;
  update public.offers set status='expired',rejection_reason='Tawaran melewati batas waktu',responded_at=now() where id=o.id;
  insert into public.notifications(user_id,title,body,kind) values(s.source_user_id,'Tawaran kedaluwarsa','Tawaran tidak dijawab dalam 20 menit.','offer');
  select * into c from public.match_candidates where submission_id=s.id and rank>coalesce(o.candidate_rank,0) order by rank limit 1;
  if c.id is null then
    update public.submissions set status='rejected',updated_at=now() where id=s.id and status='offered';
    insert into public.notifications(user_id,title,body,kind) values(s.source_user_id,'Pencocokan berakhir','Tidak ada kandidat berikutnya.','offer');
  else
    update public.submissions set selected_processor_id=c.processor_id,status='offered',updated_at=now() where id=s.id;
    insert into public.offers(submission_id,processor_id,candidate_rank,status,expires_at) values(s.id,c.processor_id,c.rank,'pending',now()+interval '20 minutes');
    insert into public.notifications(user_id,title,body,kind) values(c.processor_id,'Tawaran fallback pickup','Kandidat sebelumnya melewati batas waktu.','offer');
    insert into public.notifications(user_id,title,body,kind) values(s.source_user_id,'Kandidat fallback aktif','Tawaran diteruskan ke kandidat berikutnya.','offer');
  end if;
  insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata) values(null,'expire_offer','offer',o.id,jsonb_build_object('reason','timeout'));
end; $$;

create or replace function public.cancel_submission(p_submission_id uuid,p_reason text) returns void
language plpgsql security definer set search_path=public as $$
declare s public.submissions; v_reason text;
begin
  select * into s from public.submissions where id=p_submission_id for update;
  if s.id is null or s.source_user_id<>auth.uid() or s.status not in('submitted','matching','offered','accepted') then raise exception 'cancel_forbidden'; end if;
  if s.status='accepted' and nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'cancel_reason_required'; end if;
  v_reason:=coalesce(nullif(trim(p_reason),''),'Dibatalkan sebelum pickup');
  update public.submissions set status='cancelled',cancellation_reason=v_reason,resolved_at=case when s.status='accepted' then now() else resolved_at end,updated_at=now() where id=s.id and status=s.status;
  if s.capacity_released_at is null and s.capacity_reserved_kg>0 then
    update public.processor_profiles set available_capacity_kg=least(total_capacity_kg,available_capacity_kg+s.capacity_reserved_kg) where id=s.selected_processor_id;
    update public.submissions set capacity_released_at=now() where id=s.id and capacity_released_at is null;
  end if;
  if s.selected_processor_id is not null and s.status='accepted' then insert into public.notifications(user_id,title,body,kind) values(s.selected_processor_id,'Pickup dibatalkan','Sumber membatalkan pickup: '||v_reason,'pickup'); end if;
  insert into public.notifications(user_id,title,body,kind) values(s.source_user_id,'Setoran dibatalkan','Setoran berhasil dibatalkan.','pickup');
  insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'cancel_submission','submission',s.id,jsonb_build_object('reason',v_reason));
end; $$;

create or replace function public.record_weighing(p_submission_id uuid,p_actual_weight_kg numeric,p_evidence_path text)
returns void language plpgsql security definer set search_path=public,storage as $$
declare s public.submissions; object_owner text;
begin
  select * into s from public.submissions where id=p_submission_id for update;
  if s.id is null or s.selected_processor_id<>auth.uid() or s.status<>'en_route'
    or not exists(select 1 from public.processor_profiles pp where pp.id=auth.uid() and pp.status='approved' and pp.active)
    or p_actual_weight_kg is null or p_actual_weight_kg<=0
    or p_evidence_path !~ ('^'||p_submission_id::text||'/[^/]+$') then raise exception 'weighing_forbidden_or_invalid'; end if;
  select o.owner_id::text into object_owner from storage.objects o where o.bucket_id='weighing-evidence' and o.name=p_evidence_path;
  if object_owner is null or object_owner<>auth.uid()::text then raise exception 'evidence_object_not_found'; end if;
  update public.submissions set actual_weight_kg=p_actual_weight_kg,status='weighed',updated_at=now() where id=s.id and status='en_route';
  if not found then raise exception 'weighing_race'; end if;
  insert into public.transactions(submission_id,processor_id,actual_weight_kg,weighing_evidence_path)
    values(s.id,auth.uid(),p_actual_weight_kg,p_evidence_path)
    on conflict(submission_id) do update set actual_weight_kg=excluded.actual_weight_kg,weighing_evidence_path=excluded.weighing_evidence_path;
  insert into public.notifications(user_id,title,body,kind) values(s.source_user_id,'Berat aktual dicatat','Bukti timbang tersedia untuk konfirmasi.','weighing');
  insert into public.audit_events(actor_id,action,entity_type,entity_id) values(auth.uid(),'record_weighing','submission',s.id);
end; $$;

create or replace function public.attach_source_photo(p_submission_id uuid,p_storage_path text) returns void
language plpgsql security definer set search_path=public,storage as $$
declare s public.submissions; owner text;
begin
  select * into s from public.submissions where id=p_submission_id for update;
  if s.id is null or s.source_user_id<>auth.uid() or p_storage_path !~ ('^'||p_submission_id::text||'/[^/]+$') then raise exception 'photo_forbidden'; end if;
  select o.owner_id::text into owner from storage.objects o where o.bucket_id='source-photos' and o.name=p_storage_path;
  if owner is null or owner<>auth.uid()::text then raise exception 'photo_object_not_found'; end if;
  update public.submissions set source_photo_path=p_storage_path where id=s.id;
end; $$;

-- Formula provenance is mandatory: historical aggregates must not silently use
-- today's formula or baseline.
create or replace function public.confirm_weight(p_submission_id uuid) returns void
language plpgsql security definer set search_path=public as $$
declare s public.submissions; t public.transactions; f public.formula_versions; b public.baselines; changed integer;
begin
  select * into s from public.submissions where id=p_submission_id for update;
  if s.id is null or s.source_user_id<>auth.uid() or s.status<>'weighed' then raise exception 'confirmation_forbidden'; end if;
  select * into t from public.transactions where submission_id=s.id for update;
  if t.id is null or t.actual_weight_kg is null then raise exception 'transaction_not_found'; end if;
  select * into f from public.formula_versions where active order by created_at desc nulls last limit 1;
  select * into b from public.baselines where city_id=s.city_id and month<=date_trunc('month',coalesce(s.created_at,now()))::date order by month desc limit 1;
  if f.id is null then raise exception 'formula_not_configured'; end if;
  if b.id is null then raise exception 'baseline_not_configured'; end if;
  update public.submissions set status='completed',formula_version=f.version,resolved_at=now(),updated_at=now() where id=s.id and status='weighed'; get diagnostics changed=row_count;
  if changed<>1 then raise exception 'confirmation_race'; end if;
  update public.transactions set completed_at=now(),resolved_at=now(),formula_id=f.id,formula_version=f.version,baseline_id=b.id,points_per_kg=f.points_per_kg,emissions_factor=f.emissions_factor,economic_factor=f.economic_factor where id=t.id;
  if s.capacity_released_at is null and s.capacity_reserved_kg>0 then update public.processor_profiles set available_capacity_kg=least(total_capacity_kg,available_capacity_kg+s.capacity_reserved_kg) where id=s.selected_processor_id; update public.submissions set capacity_released_at=now() where id=s.id and capacity_released_at is null; end if;
  insert into public.point_ledger(user_id,transaction_id,entry_type,points,description,status) values(s.source_user_id,t.id,'earn',round(t.actual_weight_kg*f.points_per_kg),'Setoran terverifikasi','posted') on conflict(transaction_id) where entry_type='earn' do nothing;
  insert into public.notifications(user_id,title,body,kind) values(s.source_user_id,'Poin bertambah','Setoran dikonfirmasi dan poin dicatat.','poin');
  insert into public.audit_events(actor_id,action,entity_type,entity_id) values(auth.uid(),'confirm_weight','submission',s.id);
end; $$;

create or replace function public.resolve_dispute(p_submission_id uuid,p_approve boolean,p_reason text,p_corrected_weight_kg numeric default null)
returns void language plpgsql security definer set search_path=public as $$
declare s public.submissions; t public.transactions; f public.formula_versions; b public.baselines; final_weight numeric;
begin
  if not public.is_role('admin') or nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'resolution_forbidden'; end if;
  select * into s from public.submissions where id=p_submission_id for update;
  if s.id is null or s.status<>'disputed' then raise exception 'dispute_not_found'; end if;
  select * into t from public.transactions where submission_id=s.id for update;
  if p_approve then
    final_weight:=coalesce(p_corrected_weight_kg,t.actual_weight_kg,s.actual_weight_kg);
    if final_weight is null or final_weight<=0 then raise exception 'corrected_weight_required'; end if;
    select * into f from public.formula_versions where active order by created_at desc nulls last limit 1;
    select * into b from public.baselines where city_id=s.city_id and month<=date_trunc('month',coalesce(s.created_at,now()))::date order by month desc limit 1;
    if f.id is null or b.id is null then raise exception 'formula_or_baseline_not_configured'; end if;
  end if;
  update public.submissions set status=case when p_approve then 'completed' else 'cancelled' end,actual_weight_kg=case when p_approve then final_weight else actual_weight_kg end,formula_version=case when p_approve then f.version else formula_version end,resolved_at=now(),updated_at=now() where id=s.id and status='disputed';
  if t.id is not null then update public.transactions set actual_weight_kg=case when p_approve then final_weight else actual_weight_kg end,completed_at=case when p_approve then now() else completed_at end,resolved_at=now(),formula_id=case when p_approve then f.id else formula_id end,formula_version=case when p_approve then f.version else formula_version end,baseline_id=case when p_approve then b.id else baseline_id end,points_per_kg=case when p_approve then f.points_per_kg else points_per_kg end,emissions_factor=case when p_approve then f.emissions_factor else emissions_factor end,economic_factor=case when p_approve then f.economic_factor else economic_factor end where id=t.id; end if;
  if s.capacity_released_at is null and s.capacity_reserved_kg>0 then update public.processor_profiles set available_capacity_kg=least(total_capacity_kg,available_capacity_kg+s.capacity_reserved_kg) where id=s.selected_processor_id; update public.submissions set capacity_released_at=now() where id=s.id and capacity_released_at is null; end if;
  if p_approve and t.id is not null then insert into public.point_ledger(user_id,transaction_id,entry_type,points,description,status) values(s.source_user_id,t.id,'earn',round(final_weight*f.points_per_kg),'Sengketa diselesaikan','posted') on conflict(transaction_id) where entry_type='earn' do nothing; end if;
  insert into public.notifications(user_id,title,body,kind) values(s.source_user_id,'Sengketa selesai',case when p_approve then 'Sengketa disetujui.' else 'Transaksi dibatalkan.' end,'dispute');
  if s.selected_processor_id is not null then insert into public.notifications(user_id,title,body,kind) values(s.selected_processor_id,'Sengketa selesai',trim(p_reason),'dispute'); end if;
  insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'resolve_dispute','submission',s.id,jsonb_build_object('approve',p_approve,'reason',trim(p_reason),'corrected_weight',p_corrected_weight_kg));
end; $$;

-- Private evidence is only visible to the source, selected processor and Admin;
-- uploads must be scoped to the UUID prefix and the caller's ownership.
drop policy if exists source_photos_owner_insert on storage.objects;
drop policy if exists weighing_photos_processor_insert on storage.objects;
create policy source_photos_owner_insert on storage.objects for insert with check(
  bucket_id='source-photos' and owner_id::text=auth.uid()::text and name ~* ('^[0-9a-f-]{36}/[^/]+$') and
  exists(select 1 from public.submissions s where s.id=split_part(name,'/',1)::uuid and s.source_user_id=auth.uid())
);
create policy weighing_photos_processor_insert on storage.objects for insert with check(
  bucket_id='weighing-evidence' and owner_id::text=auth.uid()::text and name ~* ('^[0-9a-f-]{36}/[^/]+$') and
  exists(select 1 from public.submissions s join public.processor_profiles p on p.id=s.selected_processor_id where s.id=split_part(name,'/',1)::uuid and s.selected_processor_id=auth.uid() and s.status='en_route' and p.status='approved')
);

create or replace function public.retention_cleanup() returns void language plpgsql security definer set search_path=public,storage as $$
begin
  delete from storage.objects o where o.bucket_id='source-photos' and exists(select 1 from public.submissions s where s.source_photo_path=o.name and s.status in('completed','cancelled','rejected') and s.resolved_at<now()-interval '90 days');
  delete from storage.objects o where o.bucket_id='weighing-evidence' and exists(select 1 from public.transactions t join public.submissions s on s.id=t.submission_id where t.weighing_evidence_path=o.name and s.status in('completed','cancelled','rejected') and coalesce(t.resolved_at,t.completed_at,s.resolved_at)<now()-interval '90 days');
  update public.submission_locations l set precise_address=null,precise_latitude=null,precise_longitude=null where exists(select 1 from public.submissions s where s.id=l.submission_id and s.status in('completed','cancelled','rejected') and s.resolved_at<now()-interval '90 days');
end; $$;

-- No client can forge redeem reviewer/status fields.
drop policy if exists redeem_owner_insert_rpc on public.redeem_requests;
drop policy if exists redeem_insert on public.redeem_requests;
revoke insert,update,delete on public.redeem_requests from anon,authenticated;

-- Realtime publication is additive and safe on projects where it exists.
do $$ declare t text; begin foreach t in array array['submissions','offers','transactions','notifications','redeem_requests','content','events','audit_events'] loop begin execute format('alter publication supabase_realtime add table public.%I',t); exception when duplicate_object or undefined_object then null; end; end loop; end $$;

-- Trusted bootstrap is callable from service_role/postgres migration sessions only.
create or replace function public.provision_privileged_profile(p_user_id uuid,p_role public.app_role,p_name text,p_email text default null)
returns void language plpgsql security definer set search_path=public as $$
begin
  if session_user not in ('postgres','service_role') and coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'admin_provisioning_required'; end if;
  if p_role not in ('admin','dlh') then raise exception 'privileged_role_required'; end if;
  insert into public.profiles(id,name,email,primary_role) values(p_user_id,coalesce(nullif(trim(p_name),''),'Privileged user'),p_email,p_role)
    on conflict(id) do update set name=excluded.name,email=excluded.email,primary_role=excluded.primary_role;
  insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'provision_privileged_profile','profile',p_user_id,jsonb_build_object('role',p_role));
end; $$;
revoke execute on function public.provision_privileged_profile(uuid,public.app_role,text,text) from public,anon,authenticated;
grant execute on function public.provision_privileged_profile(uuid,public.app_role,text,text) to service_role;
