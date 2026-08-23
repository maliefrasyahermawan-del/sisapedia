-- Correctness closure. Every statement is safe to re-run after migrations 001-003.
alter table public.submissions add column if not exists resolved_at timestamptz;
alter table public.transactions add column if not exists resolved_at timestamptz;

-- The role trigger remains the authority for primary_role immutability; this
-- policy avoids a recursive SELECT from profiles inside its own check policy.
drop policy if exists profiles_update_self_safe on public.profiles;
create policy profiles_update_self_safe on public.profiles for update
  using (id=auth.uid()) with check (id=auth.uid());

create or replace function public.confirm_weight(p_submission_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare s public.submissions; t public.transactions; f public.formula_versions; b public.baselines; changed integer;
begin
  select * into s from public.submissions where id=p_submission_id for update;
  if s.id is null or s.source_user_id<>auth.uid() or s.status<>'weighed' then raise exception 'confirmation_forbidden'; end if;
  select * into t from public.transactions where submission_id=s.id for update;
  if t.id is null then raise exception 'transaction_not_found'; end if;
  select * into f from public.formula_versions where active order by created_at desc limit 1;
  select * into b from public.baselines where city_id=s.city_id and month=date_trunc('month',now())::date order by month desc limit 1;
  update public.submissions set status='completed',formula_version=coalesce(f.version,'semarang-2026-v1'),updated_at=now()
    where id=s.id and status='weighed'; get diagnostics changed=ROW_COUNT;
  if changed<>1 then raise exception 'confirmation_race'; end if;
  update public.transactions set completed_at=now(),resolved_at=now(),formula_version=coalesce(f.version,'semarang-2026-v1'),baseline_id=b.id where id=t.id;
  if s.capacity_released_at is null and s.capacity_reserved_kg>0 then
    update public.processor_profiles set available_capacity_kg=least(total_capacity_kg,available_capacity_kg+s.capacity_reserved_kg) where id=s.selected_processor_id;
    update public.submissions set capacity_released_at=now() where id=s.id and capacity_released_at is null;
  end if;
  insert into public.point_ledger(user_id,transaction_id,entry_type,points,description,status)
    values(s.source_user_id,t.id,'earn',round(s.actual_weight_kg*coalesce(f.points_per_kg,10)),'Setoran terverifikasi','posted')
    on conflict(transaction_id) where entry_type='earn' do nothing;
  insert into public.notifications(user_id,title,body,kind) values(s.source_user_id,'Poin bertambah','Setoran dikonfirmasi dan poin dicatat.','poin');
  insert into public.audit_events(actor_id,action,entity_type,entity_id) values(auth.uid(),'confirm_weight','submission',s.id);
end; $$;

create or replace function public.dispute_weight(p_submission_id uuid,p_reason text)
returns void language plpgsql security definer set search_path=public as $$
declare s public.submissions;
begin
  if nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'dispute_reason_required'; end if;
  select * into s from public.submissions where id=p_submission_id for update;
  if s.id is null or s.source_user_id<>auth.uid() or s.status<>'weighed' then raise exception 'dispute_forbidden'; end if;
  update public.submissions set status='disputed',dispute_reason=trim(p_reason),updated_at=now() where id=s.id and status='weighed';
  insert into public.notifications(user_id,title,body,kind) values(s.selected_processor_id,'Sengketa berat diajukan','Sumber meminta peninjauan berat aktual.','dispute');
  insert into public.notifications(user_id,title,body,kind) select id,'Sengketa perlu ditinjau','Ada sengketa berat baru.','dispute' from public.profiles where primary_role='admin';
  insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'dispute','submission',s.id,jsonb_build_object('reason',p_reason));
end; $$;

create or replace function public.resolve_dispute(p_submission_id uuid,p_approve boolean,p_reason text,p_corrected_weight_kg numeric default null)
returns void language plpgsql security definer set search_path=public as $$
declare s public.submissions; t public.transactions; f public.formula_versions; b public.baselines; final_weight numeric;
begin
  if not public.is_role('admin') then raise exception 'admin_required'; end if;
  if nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'resolution_reason_required'; end if;
  select * into s from public.submissions where id=p_submission_id for update;
  if s.id is null or s.status<>'disputed' then raise exception 'dispute_not_found'; end if;
  select * into t from public.transactions where submission_id=s.id for update;
  final_weight:=coalesce(p_corrected_weight_kg,s.actual_weight_kg);
  if p_approve and (final_weight is null or final_weight<=0) then raise exception 'corrected_weight_required'; end if;
  select * into f from public.formula_versions where active order by created_at desc limit 1;
  select * into b from public.baselines where city_id=s.city_id and month=date_trunc('month',now())::date order by month desc limit 1;
  update public.submissions set status=case when p_approve then 'completed' else 'cancelled' end,
    actual_weight_kg=case when p_approve then final_weight else actual_weight_kg end,
    formula_version=case when p_approve then coalesce(f.version,'semarang-2026-v1') else formula_version end,
    resolved_at=now(),updated_at=now() where id=s.id and status='disputed';
  if t.id is not null then
    update public.transactions set actual_weight_kg=case when p_approve then final_weight else actual_weight_kg end,
      completed_at=case when p_approve then now() else completed_at end,resolved_at=now(),
      formula_version=case when p_approve then coalesce(f.version,'semarang-2026-v1') else formula_version end,
      baseline_id=case when p_approve then b.id else baseline_id end where id=t.id;
  end if;
  if s.capacity_released_at is null and s.capacity_reserved_kg>0 then
    update public.processor_profiles set available_capacity_kg=least(total_capacity_kg,available_capacity_kg+s.capacity_reserved_kg) where id=s.selected_processor_id;
    update public.submissions set capacity_released_at=now() where id=s.id and capacity_released_at is null;
  end if;
  if p_approve and t.id is not null then
    insert into public.point_ledger(user_id,transaction_id,entry_type,points,description,status)
      values(s.source_user_id,t.id,'earn',round(final_weight*coalesce(f.points_per_kg,10)),'Sengketa diselesaikan','posted')
      on conflict(transaction_id) where entry_type='earn' do nothing;
  end if;
  insert into public.notifications(user_id,title,body,kind) values(s.source_user_id,'Sengketa selesai',case when p_approve then 'Sengketa disetujui.' else 'Transaksi dibatalkan.' end,'dispute');
  insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'resolve_dispute','submission',s.id,jsonb_build_object('approve',p_approve,'reason',p_reason,'corrected_weight',p_corrected_weight_kg));
end; $$;

revoke execute on function public.resolve_dispute(uuid,boolean,text) from authenticated,public,anon;
revoke execute on function public.resolve_dispute(uuid,boolean,text,numeric) from public,anon;
grant execute on function public.resolve_dispute(uuid,boolean,text,numeric) to authenticated;

create or replace function public.retention_cleanup() returns void language plpgsql security definer set search_path=public,storage as $$
begin
  delete from storage.objects o where o.bucket_id='source-photos' and o.created_at<now()-interval '90 days'
    and exists(select 1 from public.submissions s where s.source_photo_path=o.name and s.status in('completed','cancelled','rejected') and coalesce(s.resolved_at,s.updated_at)<now()-interval '90 days');
  delete from storage.objects o where o.bucket_id='weighing-evidence' and exists(select 1 from public.transactions t where t.weighing_evidence_path=o.name and t.completed_at is not null and coalesce(t.resolved_at,t.completed_at)<now()-interval '90 days');
  update public.submission_locations l set precise_address=null,precise_latitude=null,precise_longitude=null
    where exists(select 1 from public.submissions s where s.id=l.submission_id and s.status in('completed','cancelled','rejected') and coalesce(s.resolved_at,s.updated_at)<now()-interval '90 days');
end; $$;
revoke all on function public.retention_cleanup() from public,anon,authenticated;

do $$ declare t text; begin
  foreach t in array array['submissions','match_candidates','offers','transactions','point_ledger','redeem_requests','notifications','audit_events'] loop
    if not exists(select 1 from pg_publication_rel r join pg_class c on c.oid=r.prrelid join pg_publication p on p.oid=r.prpubid where p.pubname='supabase_realtime' and c.relname=t) then execute format('alter publication supabase_realtime add table public.%I',t); end if;
  end loop;
exception when undefined_object then null;
end $$;

drop policy if exists content_author_insert on public.content;
drop policy if exists content_author_update on public.content;
drop policy if exists events_organizer_insert on public.events;
drop policy if exists events_organizer_update on public.events;
create policy content_author_insert on public.content for insert with check(author_id=auth.uid() and public.is_role('pengolah'));
create policy content_author_update on public.content for update using(author_id=auth.uid() and status in('draft','rejected')) with check(author_id=auth.uid() and status in('draft','submitted'));
create policy events_organizer_insert on public.events for insert with check(organizer_id=auth.uid() and public.is_role('pengolah'));
create policy events_organizer_update on public.events for update using(organizer_id=auth.uid() and status in('draft','rejected')) with check(organizer_id=auth.uid() and status in('draft','submitted'));
create or replace function public.submit_content_draft(p_id uuid) returns void language plpgsql security definer set search_path=public as $$ begin
  if not exists(select 1 from public.content where id=p_id and author_id=auth.uid() and status in('draft','rejected')) and not exists(select 1 from public.events where id=p_id and organizer_id=auth.uid() and status in('draft','rejected')) then raise exception 'draft_forbidden'; end if;
  update public.content set status='submitted' where id=p_id and author_id=auth.uid(); update public.events set status='submitted' where id=p_id and organizer_id=auth.uid();
end; $$;
create or replace function public.moderate_content(p_id uuid,p_approve boolean,p_reason text) returns void language plpgsql security definer set search_path=public as $$ declare changed integer; begin
  if not public.is_role('admin') or nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'moderation_forbidden'; end if;
  update public.content set status=case when p_approve then 'approved' else 'rejected' end where id=p_id and status='submitted'; get diagnostics changed=ROW_COUNT;
  update public.events set status=case when p_approve then 'approved' else 'rejected' end where id=p_id and status='submitted';
  if changed=0 and not exists(select 1 from public.events where id=p_id and status in('approved','rejected')) then raise exception 'draft_not_submitted'; end if;
  insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'content_review','content',p_id,jsonb_build_object('approve',p_approve,'reason',p_reason));
end; $$;
revoke execute on function public.submit_content_draft(uuid) from public,anon; grant execute on function public.submit_content_draft(uuid) to authenticated;
revoke execute on function public.moderate_content(uuid,boolean,text) from public,anon; grant execute on function public.moderate_content(uuid,boolean,text) to authenticated;
