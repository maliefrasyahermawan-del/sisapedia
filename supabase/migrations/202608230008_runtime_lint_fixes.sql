-- Runtime lint fixes after applying migrations 001-007.

create or replace function public.approve_redeem(
  p_request_id uuid,p_approve boolean,p_reason text default null
) returns void language plpgsql security definer set search_path=public as $$
declare r public.redeem_requests; balance bigint;
begin
  if not public.is_role('admin') then raise exception 'admin_required'; end if;
  select * into r from public.redeem_requests where id=p_request_id for update;
  if r.id is null then raise exception 'redeem_not_found'; end if;
  if r.status<>'submitted' then return; end if;
  perform pg_advisory_xact_lock(hashtextextended(r.user_id::text,0));
  select coalesce(sum(points),0) into balance from public.point_ledger where user_id=r.user_id and status='posted';
  if p_approve and balance<r.points then raise exception 'insufficient_points'; end if;
  update public.redeem_requests set status=case when p_approve then 'approved' else 'rejected' end,
    reviewed_by=auth.uid(),review_reason=p_reason,reviewed_at=now() where id=r.id and status='submitted';
  if p_approve then
    insert into public.point_ledger(user_id,redeem_request_id,entry_type,points,description,status)
      values(r.user_id,r.id,'redeem',-r.points,r.description,'posted')
      on conflict(redeem_request_id) where redeem_request_id is not null do nothing;
  end if;
  insert into public.notifications(user_id,title,body,kind)
    values(r.user_id,'Status redeem diperbarui',case when p_approve then 'Redeem disetujui.' else 'Redeem ditolak.' end,'redeem');
  insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata)
    values(auth.uid(),'redeem_review','redeem_request',r.id,jsonb_build_object('approved',p_approve,'reason',p_reason));
end; $$;
revoke execute on function public.approve_redeem(uuid,boolean,text) from public,anon;
grant execute on function public.approve_redeem(uuid,boolean,text) to authenticated;

drop function if exists public.resolve_dispute(uuid,boolean,text);
create or replace function public.resolve_dispute(
  p_submission_id uuid,p_approve boolean,p_reason text,p_corrected_weight_kg numeric default null
) returns void language plpgsql security definer set search_path=public as $$
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
  update public.submissions set status=(case when p_approve then 'completed' else 'cancelled' end)::public.submission_status,
    actual_weight_kg=case when p_approve then final_weight else actual_weight_kg end,
    formula_version=case when p_approve then f.version else formula_version end,resolved_at=now(),updated_at=now()
    where id=s.id and status='disputed';
  if t.id is not null then
    update public.transactions set actual_weight_kg=case when p_approve then final_weight else actual_weight_kg end,
      completed_at=case when p_approve then now() else completed_at end,resolved_at=now(),
      formula_id=case when p_approve then f.id else formula_id end,
      formula_version=case when p_approve then f.version else formula_version end,
      baseline_id=case when p_approve then b.id else baseline_id end,
      points_per_kg=case when p_approve then f.points_per_kg else points_per_kg end,
      emissions_factor=case when p_approve then f.emissions_factor else emissions_factor end,
      economic_factor=case when p_approve then f.economic_factor else economic_factor end where id=t.id;
  end if;
  if s.capacity_released_at is null and s.capacity_reserved_kg>0 then
    update public.processor_profiles set available_capacity_kg=least(total_capacity_kg,available_capacity_kg+s.capacity_reserved_kg) where id=s.selected_processor_id;
    update public.submissions set capacity_released_at=now() where id=s.id and capacity_released_at is null;
  end if;
  if p_approve and t.id is not null then
    insert into public.point_ledger(user_id,transaction_id,entry_type,points,description,status)
      values(s.source_user_id,t.id,'earn',round(final_weight*f.points_per_kg),'Sengketa diselesaikan','posted')
      on conflict(transaction_id) where entry_type='earn' do nothing;
  end if;
  insert into public.notifications(user_id,title,body,kind) values(s.source_user_id,'Sengketa selesai',case when p_approve then 'Sengketa disetujui.' else 'Transaksi dibatalkan.' end,'dispute');
  insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'resolve_dispute','submission',s.id,jsonb_build_object('approve',p_approve,'reason',trim(p_reason),'corrected_weight',p_corrected_weight_kg));
end; $$;
revoke execute on function public.resolve_dispute(uuid,boolean,text,numeric) from public,anon;
grant execute on function public.resolve_dispute(uuid,boolean,text,numeric) to authenticated;
