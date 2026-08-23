-- Security/workflow remediation. This migration is re-runnable on a fresh or
-- existing project and moves every sensitive write behind authenticated RPCs.
insert into storage.buckets(id,name,public)
values ('source-photos','source-photos',false),
       ('processor-evidence','processor-evidence',false),
       ('weighing-evidence','weighing-evidence',false)
on conflict (id) do update set public=false;
create table if not exists public.submission_locations(
  submission_id uuid primary key references public.submissions(id) on delete cascade,
  source_user_id uuid not null references public.profiles(id),
  city_id uuid not null references public.cities(id),
  district text not null default '',
  administrative_area text not null default '',
  precise_latitude numeric,
  precise_longitude numeric,
  created_at timestamptz not null default now()
);
alter table public.submission_locations add column if not exists precise_address text;
-- Preserve legacy precise values before removing them from the processor-readable
-- submissions row. The source-owned location table is the sole precise store.
do $$ begin
  if exists(select 1 from information_schema.columns where table_schema='public' and table_name='submissions' and column_name='precise_latitude') then
    execute $migration$
      insert into public.submission_locations(
        submission_id,source_user_id,city_id,district,administrative_area,precise_address,
        precise_latitude,precise_longitude
      )
      select s.id,s.source_user_id,s.city_id,'',coalesce(s.administrative_area,''),
        nullif(s.administrative_area,''),s.precise_latitude,s.precise_longitude
      from public.submissions s
      where (s.precise_latitude is not null or s.precise_longitude is not null or s.administrative_area<>'')
      on conflict (submission_id) do update set
        precise_address=coalesce(public.submission_locations.precise_address,excluded.precise_address),
        precise_latitude=coalesce(public.submission_locations.precise_latitude,excluded.precise_latitude),
        precise_longitude=coalesce(public.submission_locations.precise_longitude,excluded.precise_longitude)
    $migration$;
  end if;
end $$;
alter table public.submissions add column if not exists material_subtype text not null default '';
alter table public.submissions add column if not exists source_photo_path text;
alter table public.submissions drop column if exists precise_latitude;
alter table public.submissions drop column if exists precise_longitude;
alter table public.submissions add column if not exists capacity_reserved_kg numeric not null default 0;
alter table public.submissions add column if not exists capacity_released_at timestamptz;
alter table public.transactions add column if not exists formula_version text;
alter table public.transactions add column if not exists baseline_id uuid references public.baselines(id);
alter table public.point_ledger add column if not exists redeem_request_id uuid references public.redeem_requests(id);
alter table public.offers add column if not exists responded_at timestamptz;
alter table public.redeem_requests add column if not exists reviewed_at timestamptz;
alter table public.formula_versions add column if not exists created_at timestamptz not null default now();
create unique index if not exists point_ledger_transaction_earn on public.point_ledger(transaction_id) where entry_type='earn';
create unique index if not exists point_ledger_redeem_once on public.point_ledger(redeem_request_id) where redeem_request_id is not null;

create or replace function public.prevent_role_escalation() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='UPDATE' and old.primary_role is distinct from new.primary_role then
    if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception 'primary_role_is_immutable'; end if;
  end if;
  if new.primary_role in ('admin','dlh') and coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'privileged_role_requires_server_provisioning';
  end if;
  return new;
end; $$;
drop trigger if exists profiles_role_guard on public.profiles;
create trigger profiles_role_guard before insert or update of primary_role on public.profiles for each row execute procedure public.prevent_role_escalation();

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
declare requested text; safe_role public.app_role;
begin
  requested:=lower(coalesce(new.raw_user_meta_data->>'primary_role','sumber'));
  safe_role:=case when requested='pengolah' then 'pengolah'::public.app_role else 'sumber'::public.app_role end;
  insert into public.profiles(id,name,email,primary_role)
  values(new.id,coalesce(new.raw_user_meta_data->>'name','Pengguna'),new.email,safe_role)
  on conflict(id) do nothing;
  return new;
end; $$;

create or replace function public.provision_privileged_profile(
  p_user_id uuid,p_role public.app_role,p_name text,p_email text default null
) returns void language plpgsql security definer set search_path=public as $$
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' or p_role not in ('admin','dlh') then
    raise exception 'admin_provisioning_required';
  end if;
  insert into public.profiles(id,name,email,primary_role)
  values(p_user_id,coalesce(nullif(trim(p_name),''),'Privileged user'),p_email,p_role)
  on conflict(id) do update set name=excluded.name,email=excluded.email,primary_role=excluded.primary_role;
  insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),'provision_privileged_profile','profile',p_user_id,jsonb_build_object('role',p_role));
end; $$;

create or replace function public.prevent_processor_self_approval() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='UPDATE' and old.status is distinct from new.status and not public.is_role('admin') then raise exception 'processor_review_is_admin_only'; end if;
  return new;
end; $$;
drop trigger if exists processor_status_guard on public.processor_profiles;
create trigger processor_status_guard before update of status on public.processor_profiles for each row execute procedure public.prevent_processor_self_approval();

drop policy if exists profiles_update on public.profiles;
drop policy if exists processors_manage on public.processor_profiles;
drop policy if exists submissions_update on public.submissions;
drop policy if exists submissions_insert on public.submissions;
drop policy if exists submissions_read on public.submissions;
drop policy if exists candidates_member_read on public.match_candidates;
drop policy if exists offers_member_read on public.offers;
drop policy if exists transactions_member_read on public.transactions;
drop policy if exists ledger_read on public.point_ledger;
drop policy if exists redeem_read on public.redeem_requests;
drop policy if exists redeem_insert on public.redeem_requests;
drop policy if exists baseline_dlh_admin on public.baselines;
drop policy if exists audit_admin_only on public.audit_events;
drop policy if exists source_photo_members on storage.objects;
drop policy if exists source_photo_owner_upload on storage.objects;
drop policy if exists processor_evidence_private on storage.objects;
drop policy if exists processor_evidence_upload on storage.objects;
drop policy if exists weighing_evidence_members on storage.objects;
drop policy if exists weighing_evidence_upload on storage.objects;
drop policy if exists source_photos_participant on storage.objects;
drop policy if exists source_photos_owner_insert on storage.objects;
drop policy if exists processor_evidence_admin on storage.objects;
drop policy if exists processor_evidence_upload on storage.objects;
drop policy if exists weighing_photos_participant on storage.objects;
drop policy if exists weighing_photos_processor_insert on storage.objects;
drop policy if exists profiles_update_self_safe on public.profiles;
drop policy if exists processors_self_operational on public.processor_profiles;
drop policy if exists processors_admin_review on public.processor_profiles;
drop policy if exists submissions_member_select_safe on public.submissions;
drop policy if exists submissions_source_create_rpc on public.submissions;
drop policy if exists candidates_participant_select on public.match_candidates;
drop policy if exists offers_participant_select on public.offers;
drop policy if exists transactions_participant_select on public.transactions;
drop policy if exists ledger_owner_select on public.point_ledger;
drop policy if exists redeem_owner_select on public.redeem_requests;
drop policy if exists redeem_owner_insert_rpc on public.redeem_requests;
drop policy if exists baselines_aggregate_read on public.baselines;
drop policy if exists audit_admin_read on public.audit_events;
drop policy if exists locations_source_admin_after_accept on public.submission_locations;
drop policy if exists locations_rpc_insert on public.submission_locations;

create policy profiles_update_self_safe on public.profiles for update using(id=auth.uid()) with check(id=auth.uid() and primary_role=(select p.primary_role from public.profiles p where p.id=auth.uid()));
create policy processors_self_operational on public.processor_profiles for update using(id=auth.uid()) with check(id=auth.uid() and status=(select p.status from public.processor_profiles p where p.id=auth.uid()));
create policy processors_admin_review on public.processor_profiles for update using(public.is_role('admin')) with check(public.is_role('admin'));
create policy submissions_member_select_safe on public.submissions for select using(source_user_id=auth.uid() or selected_processor_id=auth.uid() or public.is_role('admin'));
create policy submissions_source_create_rpc on public.submissions for insert with check(false);
create policy candidates_participant_select on public.match_candidates for select using(exists(select 1 from public.submissions s where s.id=submission_id and (s.source_user_id=auth.uid() or s.selected_processor_id=auth.uid())) or public.is_role('admin'));
create policy offers_participant_select on public.offers for select using(processor_id=auth.uid() or exists(select 1 from public.submissions s where s.id=submission_id and s.source_user_id=auth.uid()) or public.is_role('admin'));
create policy transactions_participant_select on public.transactions for select using(processor_id=auth.uid() or exists(select 1 from public.submissions s where s.id=submission_id and s.source_user_id=auth.uid()) or public.is_role('admin'));
create policy ledger_owner_select on public.point_ledger for select using(user_id=auth.uid() or public.is_role('admin'));
create policy redeem_owner_select on public.redeem_requests for select using(user_id=auth.uid() or public.is_role('admin'));
create policy redeem_owner_insert_rpc on public.redeem_requests for insert with check(user_id=auth.uid() and public.is_role('sumber'));
create policy baselines_aggregate_read on public.baselines for select using(public.is_role('dlh') or public.is_role('admin'));
create policy audit_admin_read on public.audit_events for select using(public.is_role('admin'));
alter table public.formula_versions enable row level security;
drop policy if exists formula_versions_dlh_admin on public.formula_versions;
create policy formula_versions_dlh_admin on public.formula_versions for select using(public.is_role('dlh') or public.is_role('admin'));
alter table public.submission_locations enable row level security;
create policy locations_source_admin_after_accept on public.submission_locations for select using(source_user_id=auth.uid() or public.is_role('admin') or exists(select 1 from public.submissions s where s.id=submission_id and s.selected_processor_id=auth.uid() and s.status in('accepted','en_route','weighed','completed','disputed')));
create policy locations_rpc_insert on public.submission_locations for insert with check(false);

drop view if exists public.dlh_city_metrics;
create or replace function public.dlh_city_metrics()
returns table(city_id uuid,completed_transactions bigint,organic_kg numeric,inorganic_kg numeric,active_sources bigint,active_processors bigint)
language sql stable security definer set search_path=public as $$
  select s.city_id,count(*) filter(where s.status='completed')::bigint,
    coalesce(sum(s.actual_weight_kg) filter(where s.status='completed' and s.material_category='organik'),0),
    coalesce(sum(s.actual_weight_kg) filter(where s.status='completed' and s.material_category='anorganik'),0),
    count(distinct s.source_user_id) filter(where s.status='completed')::bigint,
    count(distinct s.selected_processor_id) filter(where s.status='completed')::bigint
  from public.submissions s
  where public.is_role('dlh') or public.is_role('admin')
  group by s.city_id;
$$;

create or replace function public.create_submission(
  p_category text,p_subtype text,p_description text,p_estimated_weight_kg numeric,
  p_district text default '',p_administrative_area text default '',p_latitude numeric default null,p_longitude numeric default null,
  p_pickup_start timestamptz default null,p_pickup_end timestamptz default null,p_source_photo_path text default null
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid; v_city uuid; begin
  if auth.uid() is null or not public.is_role('sumber') then raise exception 'sumber_required'; end if;
  if p_category not in('organik','anorganik') or p_estimated_weight_kg is null or p_estimated_weight_kg<=0 or length(trim(coalesce(p_subtype,'')))=0 then raise exception 'invalid_submission'; end if;
  select id into v_city from public.cities where code='semarang' and enabled for update;
  if v_city is null then raise exception 'city_not_configured'; end if;
  insert into public.submissions(city_id,source_user_id,material_category,material_subtype,description,estimated_weight_kg,pickup_window,administrative_area,status,source_photo_path)
  values(v_city,auth.uid(),p_category,p_subtype,coalesce(p_description,''),p_estimated_weight_kg,case when p_pickup_start is not null and p_pickup_end is not null then tstzrange(p_pickup_start,p_pickup_end,'[]') end,'','submitted',p_source_photo_path) returning id into v_id;
  insert into public.submission_locations(submission_id,source_user_id,city_id,district,administrative_area,precise_address,precise_latitude,precise_longitude) values(v_id,auth.uid(),v_city,p_district,'',p_administrative_area,p_latitude,p_longitude);
  perform public.refresh_match_candidates(v_id);
  insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'create','submission',v_id,jsonb_build_object('category',p_category));
  return v_id;
end; $$;

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
    from public.processor_profiles pp
    left join public.submission_locations sl on sl.submission_id=p_submission_id
    where pp.status='approved' and pp.available_capacity_kg>=s.estimated_weight_kg
      and (sl.precise_latitude is null or pp.latitude is null or pp.longitude is null or
           (abs(pp.latitude-sl.precise_latitude)+abs(pp.longitude-sl.precise_longitude))*111<=pp.service_radius_km)
      and s.estimated_weight_kg>=pp.minimum_pickup_kg
      and exists(select 1 from unnest(pp.materials) m where
        lower(trim(m))=lower(trim(s.material_category)) or
        lower(trim(m))=lower(trim(s.material_subtype)) or
        (s.material_category='organik' and lower(trim(m)) in ('kompos','sisa makanan','sayur','buah')) or
        (s.material_category='anorganik' and lower(trim(m)) in ('plastik','kertas','kardus','logam','kaleng','botol')))
  ), ranked as (
    select *,row_number() over(order by (case when s.material_category='organik' then .5*1+.3*distance_score+.2*capacity_score else .4*1+.3*reference_score+.3*minimum_score end) desc,processor_id) as candidate_rank,
      (case when s.material_category='organik' then .5*1+.3*distance_score+.2*capacity_score else .4*1+.3*reference_score+.3*minimum_score end) as total_score
    from scored
  )
  insert into public.match_candidates(submission_id,processor_id,rank,compatibility_score,distance_score,capacity_score,reference_value_score,minimum_volume_score,total_score)
  select p_submission_id,processor_id,candidate_rank,1,distance_score,capacity_score,reference_score,minimum_score,total_score from ranked where candidate_rank<=3;
  update public.submissions set status='matching',updated_at=now() where id=p_submission_id and status='submitted';
end; $$;

create or replace function public.select_submission_candidate(p_submission_id uuid,p_processor_id uuid) returns void language plpgsql security definer set search_path=public as $$ declare s public.submissions; c public.match_candidates; begin select * into s from submissions where id=p_submission_id for update; if s.source_user_id<>auth.uid() or s.status not in('matching','offered') then raise exception 'source_selection_forbidden'; end if; select * into c from match_candidates where submission_id=p_submission_id and processor_id=p_processor_id; if c.id is null then raise exception 'candidate_not_found'; end if; update submissions set selected_processor_id=p_processor_id,status='offered',updated_at=now() where id=p_submission_id; insert into offers(submission_id,processor_id,candidate_rank,status,expires_at) values(p_submission_id,p_processor_id,c.rank,'pending',now()+interval '20 minutes'); insert into notifications(user_id,title,body,kind) values(p_processor_id,'Tawaran pickup baru','Tawaran baru tersedia selama 20 menit.','offer'); end; $$;

create or replace function public.accept_offer(p_offer_id uuid) returns void language plpgsql security definer set search_path=public as $$ declare o offers; s submissions; begin select * into o from offers where id=p_offer_id for update; select * into s from submissions where id=o.submission_id for update; if o.processor_id<>auth.uid() or o.status<>'pending' or s.status<>'offered' or not exists(select 1 from processor_profiles pp where pp.id=auth.uid() and pp.status='approved') then raise exception 'offer_forbidden'; end if; if o.expires_at<now() then perform public.expire_offer(p_offer_id); return; end if; if s.selected_processor_id<>auth.uid() then raise exception 'offer_not_selected'; end if; update offers set status='accepted',responded_at=now() where id=o.id; update processor_profiles set available_capacity_kg=available_capacity_kg-s.estimated_weight_kg where id=auth.uid() and available_capacity_kg>=s.estimated_weight_kg; if not found then raise exception 'capacity_unavailable'; end if; update submissions set status='accepted',capacity_reserved_kg=s.estimated_weight_kg,capacity_released_at=null,updated_at=now() where id=s.id; insert into audit_events(actor_id,action,entity_type,entity_id) values(auth.uid(),'accept_offer','offer',o.id); insert into notifications(user_id,title,body,kind) values(s.source_user_id,'Pickup diterima','Pengolah menerima permintaan pickup.','offer'); end; $$;

create or replace function public.reject_offer(p_offer_id uuid,p_reason text) returns void language plpgsql security definer set search_path=public as $$ declare o offers; s submissions; c match_candidates; begin select * into o from offers where id=p_offer_id for update; select * into s from submissions where id=o.submission_id for update; if o.processor_id<>auth.uid() or o.status<>'pending' or s.status<>'offered' then raise exception 'offer_forbidden'; end if; update offers set status='rejected',rejection_reason=p_reason,responded_at=now() where id=o.id; select * into c from match_candidates where submission_id=s.id and rank>coalesce(o.candidate_rank,0) order by rank limit 1; if c.id is null then update submissions set status='rejected',updated_at=now() where id=s.id; else update submissions set selected_processor_id=c.processor_id,status='offered',updated_at=now() where id=s.id; insert into offers(submission_id,processor_id,candidate_rank,status,expires_at) values(s.id,c.processor_id,c.rank,'pending',now()+interval '20 minutes'); insert into notifications(user_id,title,body,kind) values(c.processor_id,'Tawaran pickup baru','Tawaran fallback tersedia selama 20 menit.','offer'); end if; insert into audit_events(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'reject_offer','offer',o.id,jsonb_build_object('reason',p_reason)); end; $$;

create or replace function public.expire_offer(p_offer_id uuid) returns void language plpgsql security definer set search_path=public as $$ declare o offers; s submissions; c match_candidates; begin select * into o from offers where id=p_offer_id for update; if o.status<>'pending' or o.expires_at>now() then return; end if; select * into s from submissions where id=o.submission_id for update; update offers set status='expired',responded_at=now() where id=o.id; select * into c from match_candidates where submission_id=s.id and rank>coalesce(o.candidate_rank,0) order by rank limit 1; if c.id is null then update submissions set status='rejected',updated_at=now() where id=s.id; else update submissions set selected_processor_id=c.processor_id,status='offered',updated_at=now() where id=s.id; insert into offers(submission_id,processor_id,candidate_rank,status,expires_at) values(s.id,c.processor_id,c.rank,'pending',now()+interval '20 minutes'); insert into notifications(user_id,title,body,kind) values(c.processor_id,'Tawaran pickup baru','Tawaran fallback tersedia selama 20 menit.','offer'); end if; end; $$;
create or replace function public.record_weighing(p_submission_id uuid,p_actual_weight_kg numeric,p_evidence_path text) returns void language plpgsql security definer set search_path=public as $$ declare s submissions; begin select * into s from submissions where id=p_submission_id for update; if s.selected_processor_id<>auth.uid() or s.status<>'en_route' or not exists(select 1 from processor_profiles pp where pp.id=auth.uid() and pp.status='approved') or p_actual_weight_kg is null or p_actual_weight_kg<=0 or length(trim(coalesce(p_evidence_path,'')))=0 then raise exception 'weighing_forbidden_or_invalid'; end if; update submissions set actual_weight_kg=p_actual_weight_kg,status='weighed',updated_at=now() where id=s.id; insert into transactions(submission_id,processor_id,actual_weight_kg,weighing_evidence_path) values(s.id,auth.uid(),p_actual_weight_kg,p_evidence_path) on conflict(submission_id) do update set actual_weight_kg=excluded.actual_weight_kg,weighing_evidence_path=excluded.weighing_evidence_path; insert into notifications(user_id,title,body,kind) values(s.source_user_id,'Berat aktual dicatat','Pengolah mengunggah bukti timbang. Konfirmasi atau ajukan sengketa.','weighing'); insert into audit_events(actor_id,action,entity_type,entity_id) values(auth.uid(),'record_weighing','submission',s.id); end; $$;
create or replace function public.confirm_weight(p_submission_id uuid) returns void language plpgsql security definer set search_path=public as $$ declare s submissions; t transactions; f formula_versions; begin select * into s from submissions where id=p_submission_id for update; if s.source_user_id<>auth.uid() or s.status<>'weighed' then raise exception 'confirmation_forbidden'; end if; select * into t from transactions where submission_id=s.id for update; select * into f from formula_versions where active order by created_at desc limit 1; update submissions set status='completed',formula_version=coalesce(f.version,'semarang-2026-v1'),updated_at=now() where id=s.id; update transactions set completed_at=now(),formula_version=coalesce(f.version,'semarang-2026-v1') where id=t.id; if s.capacity_released_at is null and s.capacity_reserved_kg>0 then update processor_profiles set available_capacity_kg=least(total_capacity_kg,available_capacity_kg+s.capacity_reserved_kg) where id=s.selected_processor_id; update submissions set capacity_released_at=now() where id=s.id; end if; insert into point_ledger(user_id,transaction_id,entry_type,points,description,status) values(s.source_user_id,t.id,'earn',round(s.actual_weight_kg*10),'Setoran terverifikasi','posted') on conflict(transaction_id) where entry_type='earn' do nothing; insert into notifications(user_id,title,body,kind) values(s.source_user_id,'Poin bertambah','Setoran dikonfirmasi dan poin 10/kg dicatat.','poin'); insert into audit_events(actor_id,action,entity_type,entity_id) values(auth.uid(),'confirm_weight','submission',s.id); end; $$;
create or replace function public.dispute_weight(p_submission_id uuid,p_reason text) returns void language plpgsql security definer set search_path=public as $$ begin if not exists(select 1 from submissions where id=p_submission_id and source_user_id=auth.uid() and status='weighed') then raise exception 'dispute_forbidden'; end if; update submissions set status='disputed',dispute_reason=p_reason where id=p_submission_id; insert into audit_events(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'dispute','submission',p_submission_id,jsonb_build_object('reason',p_reason)); end; $$;
create or replace function public.resolve_dispute(p_submission_id uuid,p_approve boolean,p_reason text) returns void language plpgsql security definer set search_path=public as $$ declare s submissions; t transactions; f formula_versions; begin if not public.is_role('admin') then raise exception 'admin_required'; end if; select * into s from submissions where id=p_submission_id and status='disputed' for update; if s.id is null then raise exception 'dispute_not_found'; end if; select * into t from transactions where submission_id=s.id for update; select * into f from formula_versions where active order by created_at desc limit 1; update submissions set status=case when p_approve then 'completed' else 'cancelled' end,formula_version=case when p_approve then coalesce(f.version,'semarang-2026-v1') else formula_version end,updated_at=now() where id=s.id; if t.id is not null then update transactions set completed_at=case when p_approve then now() else completed_at end,formula_version=case when p_approve then coalesce(f.version,'semarang-2026-v1') else formula_version end where id=t.id; end if; if s.capacity_released_at is null and s.capacity_reserved_kg>0 then update processor_profiles set available_capacity_kg=least(total_capacity_kg,available_capacity_kg+s.capacity_reserved_kg) where id=s.selected_processor_id; update submissions set capacity_released_at=now() where id=s.id; end if; if p_approve then insert into point_ledger(user_id,transaction_id,entry_type,points,description,status) values(s.source_user_id,t.id,'earn',round(s.actual_weight_kg*10),'Setoran sengketa diselesaikan','posted') on conflict(transaction_id) where entry_type='earn' do nothing; end if; insert into notifications(user_id,title,body,kind) values(s.source_user_id,'Sengketa selesai',case when p_approve then 'Sengketa disetujui dan transaksi selesai.' else 'Sengketa ditolak dan transaksi dibatalkan.' end,'dispute'); insert into audit_events(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'resolve_dispute','submission',p_submission_id,jsonb_build_object('approve',p_approve,'reason',p_reason)); end; $$;
create or replace function public.approve_processor(p_processor_id uuid,p_approve boolean,p_reason text) returns void language plpgsql security definer set search_path=public as $$ begin if not public.is_role('admin') then raise exception 'admin_required'; end if; update processor_profiles set status=case when p_approve then 'approved' else 'rejected' end where id=p_processor_id; insert into audit_events(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'processor_review','processor',p_processor_id,jsonb_build_object('approve',p_approve,'reason',p_reason)); end; $$;

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
  on conflict(id) do update set display_name=excluded.display_name,processor_type=excluded.processor_type,materials=excluded.materials,total_capacity_kg=excluded.total_capacity_kg,available_capacity_kg=excluded.total_capacity_kg,service_radius_km=excluded.service_radius_km,minimum_pickup_kg=excluded.minimum_pickup_kg,administrative_area=excluded.administrative_area,evidence_path=excluded.evidence_path,updated_at=now()
  returning id into v_id;
  insert into public.audit_events(actor_id,action,entity_type,entity_id) values(auth.uid(),'upsert_processor_application','processor',v_id);
  return v_id;
end; $$;
create or replace function public.approve_redeem(p_request_id uuid,p_approve boolean,p_reason text default null) returns void language plpgsql security definer set search_path=public as $$ declare r redeem_requests; balance bigint; begin if not public.is_role('admin') then raise exception 'admin_required'; end if; select * into r from redeem_requests where id=p_request_id for update; if r.status<>'submitted' then return; end if; select coalesce(sum(points),0) into balance from point_ledger where user_id=r.user_id and status='posted'; if p_approve and balance<r.points then raise exception 'insufficient_points'; end if; update redeem_requests set status=case when p_approve then 'approved' else 'rejected' end,reviewed_by=auth.uid(),review_reason=p_reason,reviewed_at=now() where id=r.id; if p_approve then insert into point_ledger(user_id,redeem_request_id,entry_type,points,description,status) values(r.user_id,r.id,'redeem',-r.points,r.description,'posted') on conflict(redeem_request_id) do nothing; end if; insert into audit_events(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'redeem_review','redeem_request',r.id,jsonb_build_object('approved',p_approve)); end; $$;
create or replace function public.fulfill_redeem(p_request_id uuid,p_reason text default null) returns void language plpgsql security definer set search_path=public as $$ declare r redeem_requests; begin if not public.is_role('admin') then raise exception 'admin_required'; end if; select * into r from redeem_requests where id=p_request_id for update; if r.status<>'approved' then raise exception 'redeem_not_approved'; end if; update redeem_requests set status='fulfilled',review_reason=coalesce(p_reason,review_reason),reviewed_at=now() where id=r.id; insert into audit_events(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'redeem_fulfilled','redeem_request',r.id,jsonb_build_object('reason',p_reason)); end; $$;

revoke execute on function public.create_submission(text,text,text,numeric,text,text,numeric,numeric,timestamptz,timestamptz,text) from public,anon;
grant execute on function public.create_submission(text,text,text,numeric,text,text,numeric,numeric,timestamptz,timestamptz,text) to authenticated;
revoke execute on function public.refresh_match_candidates(uuid) from public,anon;
grant execute on function public.refresh_match_candidates(uuid) to authenticated;
revoke execute on function public.select_submission_candidate(uuid,uuid) from public,anon;
grant execute on function public.select_submission_candidate(uuid,uuid) to authenticated;
revoke execute on function public.accept_offer(uuid) from public,anon;
grant execute on function public.accept_offer(uuid) to authenticated;
revoke execute on function public.reject_offer(uuid,text) from public,anon;
grant execute on function public.reject_offer(uuid,text) to authenticated;
revoke execute on function public.expire_offer(uuid) from public,anon;
grant execute on function public.expire_offer(uuid) to authenticated;
revoke execute on function public.record_weighing(uuid,numeric,text) from public,anon;
grant execute on function public.record_weighing(uuid,numeric,text) to authenticated;
revoke execute on function public.confirm_weight(uuid) from public,anon;
grant execute on function public.confirm_weight(uuid) to authenticated;
revoke execute on function public.dispute_weight(uuid,text) from public,anon;
grant execute on function public.dispute_weight(uuid,text) to authenticated;
revoke execute on function public.resolve_dispute(uuid,boolean,text) from public,anon;
grant execute on function public.resolve_dispute(uuid,boolean,text) to authenticated;
revoke execute on function public.approve_processor(uuid,boolean,text) from public,anon;
grant execute on function public.approve_processor(uuid,boolean,text) to authenticated;
revoke execute on function public.upsert_processor_application(text,text,text[],numeric,numeric,numeric,text,text) from public,anon;
grant execute on function public.upsert_processor_application(text,text,text[],numeric,numeric,numeric,text,text) to authenticated;
revoke execute on function public.approve_redeem(uuid,boolean,text) from public,anon;
grant execute on function public.approve_redeem(uuid,boolean,text) to authenticated;
revoke execute on function public.fulfill_redeem(uuid,text) from public,anon;
grant execute on function public.fulfill_redeem(uuid,text) to authenticated;
revoke execute on function public.provision_privileged_profile(uuid,public.app_role,text,text) from public,anon;
revoke execute on function public.provision_privileged_profile(uuid,public.app_role,text,text) from authenticated;
revoke execute on function public.dlh_city_metrics() from public,anon;
grant execute on function public.dlh_city_metrics() to authenticated;
revoke all on function public.retention_cleanup() from public,anon,authenticated;
revoke all on public.submission_locations from anon;
create policy source_photos_participant on storage.objects for select using(
  bucket_id='source-photos' and (
    public.is_role('admin') or (
      split_part(name,'/',1) ~* '^[0-9a-f-]{36}$' and exists(
        select 1 from public.submissions s
        where s.id=split_part(name,'/',1)::uuid
          and (s.source_user_id=auth.uid() or (
            s.selected_processor_id=auth.uid() and
            s.status in('accepted','en_route','weighed','completed','disputed')
          ))
      )
    )
  )
);
create policy source_photos_owner_insert on storage.objects for insert with check(bucket_id='source-photos' and owner_id=auth.uid()::text);
create policy processor_evidence_admin on storage.objects for select using(bucket_id='processor-evidence' and (owner_id=auth.uid()::text or public.is_role('admin')));
create policy processor_evidence_upload on storage.objects for insert with check(bucket_id='processor-evidence' and owner_id=auth.uid()::text and public.is_role('pengolah'));
create policy weighing_photos_participant on storage.objects for select using(bucket_id='weighing-evidence' and (public.is_role('admin') or exists(select 1 from public.transactions t join public.submissions s on s.id=t.submission_id where t.weighing_evidence_path=name and (s.source_user_id=auth.uid() or s.selected_processor_id=auth.uid()))));
create policy weighing_photos_processor_insert on storage.objects for insert with check(bucket_id='weighing-evidence' and owner_id=auth.uid()::text and public.is_role('pengolah'));

create or replace function public.retention_cleanup() returns void language plpgsql security definer set search_path=public,storage as $$
begin
  delete from storage.objects o where o.bucket_id='source-photos' and o.created_at<now()-interval '90 days' and split_part(o.name,'/',1) ~* '^[0-9a-f-]{36}$'
    and exists(select 1 from public.submissions s where s.id=split_part(o.name,'/',1)::uuid and s.status in('completed','cancelled','rejected'));
  delete from storage.objects o where o.bucket_id='weighing-evidence' and o.created_at<now()-interval '90 days'
    and exists(select 1 from public.transactions t where t.weighing_evidence_path=o.name and t.completed_at is not null and t.completed_at<now()-interval '90 days');
  update public.submission_locations l set precise_latitude=null,precise_longitude=null
    where l.created_at<now()-interval '90 days' and exists(select 1 from public.submissions s where s.id=l.submission_id and s.status in('completed','cancelled','rejected'));
end; $$;
create or replace function public.transition_submission(p_submission_id uuid,p_next_status text,p_reason text default null,p_actual_weight_kg numeric default null) returns public.submissions language plpgsql security definer set search_path=public as $$
declare s public.submissions; old_status text; allowed boolean:=false; result public.submissions;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  select * into s from public.submissions where id=p_submission_id for update;
  if s.id is null then raise exception 'submission_not_found'; end if;
  old_status:=s.status::text;
  if s.source_user_id=auth.uid() and p_next_status in('cancelled','disputed') and old_status in('submitted','matching','offered','accepted','weighed') then allowed:=true; end if;
  if s.selected_processor_id=auth.uid() and p_next_status in('en_route','weighed') and old_status in('accepted','en_route') then allowed:=true; end if;
  if public.is_role('admin') and p_next_status in('completed','cancelled') and old_status in('disputed','accepted','en_route','weighed') then allowed:=true; end if;
  if not allowed then raise exception 'transition_forbidden'; end if;
  update public.submissions set status=p_next_status::public.submission_status,actual_weight_kg=coalesce(p_actual_weight_kg,actual_weight_kg),cancellation_reason=case when p_next_status='cancelled' then p_reason else cancellation_reason end,dispute_reason=case when p_next_status='disputed' then p_reason else dispute_reason end,updated_at=now() where id=s.id returning * into result;
  if p_next_status in ('cancelled','completed') and s.capacity_released_at is null and s.capacity_reserved_kg>0 then
    update public.processor_profiles set available_capacity_kg=least(total_capacity_kg,available_capacity_kg+s.capacity_reserved_kg) where id=s.selected_processor_id;
    update public.submissions set capacity_released_at=now() where id=s.id;
  end if;
  insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'transition','submission',s.id,jsonb_build_object('from',old_status,'to',p_next_status,'reason',p_reason));
  return result;
end; $$;
revoke execute on function public.transition_submission(uuid,text,text,numeric) from public;
revoke execute on function public.transition_submission(uuid,text,text,numeric) from authenticated;

create or replace function public.mark_en_route(p_submission_id uuid) returns void language plpgsql security definer set search_path=public as $$
declare s public.submissions;
begin
  select * into s from public.submissions where id=p_submission_id for update;
  if s.selected_processor_id<>auth.uid() or s.status<>'accepted' or not exists(select 1 from public.processor_profiles where id=auth.uid() and status='approved') then raise exception 'en_route_forbidden'; end if;
  update public.submissions set status='en_route',updated_at=now() where id=s.id;
  insert into public.notifications(user_id,title,body,kind) values(s.source_user_id,'Pickup berangkat','Pengolah sedang menuju lokasi pickup.','pickup');
  insert into public.audit_events(actor_id,action,entity_type,entity_id) values(auth.uid(),'mark_en_route','submission',s.id);
end; $$;
create or replace function public.cancel_submission(p_submission_id uuid,p_reason text) returns void language plpgsql security definer set search_path=public as $$
declare s public.submissions;
begin
  if nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'cancel_reason_required'; end if;
  select * into s from public.submissions where id=p_submission_id for update;
  if s.source_user_id<>auth.uid() or s.status not in('submitted','matching','offered','accepted') then raise exception 'cancel_forbidden'; end if;
  update public.submissions set status='cancelled',cancellation_reason=p_reason,updated_at=now() where id=s.id;
  if s.capacity_released_at is null and s.capacity_reserved_kg>0 then update public.processor_profiles set available_capacity_kg=least(total_capacity_kg,available_capacity_kg+s.capacity_reserved_kg) where id=s.selected_processor_id; update public.submissions set capacity_released_at=now() where id=s.id; end if;
  insert into public.notifications(user_id,title,body,kind) values(s.source_user_id,'Setoran dibatalkan','Setoran berhasil dibatalkan.','pickup');
  insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'cancel_submission','submission',s.id,jsonb_build_object('reason',p_reason));
end; $$;
revoke execute on function public.mark_en_route(uuid) from public,anon;
grant execute on function public.mark_en_route(uuid) to authenticated;
revoke execute on function public.cancel_submission(uuid,text) from public,anon;
grant execute on function public.cancel_submission(uuid,text) to authenticated;
