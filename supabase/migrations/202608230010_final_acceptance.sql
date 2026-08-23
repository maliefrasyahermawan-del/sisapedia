-- Final acceptance hardening. This is a forward-only privilege and retention
-- remediation; earlier migrations are intentionally left immutable.

-- Public client roles never receive table-owner capabilities. RLS remains the
-- row-level boundary for the SELECT grants below.
revoke all on all tables in schema public from anon, authenticated;
revoke truncate, references, trigger on all tables in schema public from anon, authenticated;
grant select on table public.cities, public.profiles, public.processor_profiles,
  public.processor_materials, public.submissions, public.submission_locations,
  public.match_candidates, public.offers, public.transactions,
  public.point_ledger, public.redeem_requests, public.notifications,
  public.content, public.events, public.event_participation,
  public.formula_versions, public.baselines, public.audit_events
  to authenticated;
grant select on table public.cities, public.content, public.events to anon;

-- Storage API writes still use the authenticated table role, but policy checks
-- constrain every row/path. Anonymous users have no storage table privileges.
revoke all on table storage.objects from anon, authenticated;
revoke truncate, references, trigger on table storage.objects from anon, authenticated;
grant select, insert, update, delete on table storage.objects to authenticated;

-- Remove inherited function execution and grant only the RPC surface used by
-- the app. SECURITY DEFINER helpers remain callable only internally.
revoke all on all functions in schema public from anon, authenticated;
grant execute on function public.accept_offer(uuid), public.approve_processor(uuid,boolean,text),
  public.approve_redeem(uuid,boolean,text), public.attach_source_photo(uuid,text),
  public.cancel_submission(uuid,text), public.confirm_weight(uuid),
  public.create_content_draft(text,text,text),
  public.create_submission(text,text,text,numeric,text,text,numeric,numeric,timestamptz,timestamptz,text,text),
  public.dispute_weight(uuid,text), public.dlh_city_metrics(),
  public.expire_offer(uuid), public.fulfill_redeem(uuid,text), public.join_event(uuid),
  public.mark_en_route(uuid), public.moderate_content(uuid,boolean,text),
  public.record_weighing(uuid,numeric,text), public.refresh_match_candidates(uuid),
  public.reject_offer(uuid,text), public.resolve_dispute(uuid,boolean,text,numeric),
  public.select_submission_candidate(uuid,uuid), public.submit_content_draft(uuid),
  public.submit_redeem(integer,text), public.update_content_draft(uuid,text,text),
  public.update_processor_operational(boolean,boolean,time,time),
  public.upsert_processor_application(text,text,text[],numeric,numeric,numeric,text,text),
  public.upsert_processor_application(text,text,text[],numeric,numeric,numeric,text,text,numeric,numeric),
  public.consume_sari_rate_limit(uuid,integer)
  to authenticated;
grant execute on function public.provision_privileged_profile(uuid,public.app_role,text,text) to service_role;

-- Every terminal submission gets a retention timestamp, including legacy
-- reject/expiry paths which predate the resolved_at column.
create or replace function public.set_terminal_resolution() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  if new.status::text in ('completed','cancelled','rejected','expired') then
    new.resolved_at := coalesce(new.resolved_at,now());
  end if;
  return new;
end;
$$;
drop trigger if exists submissions_terminal_resolution on public.submissions;
create trigger submissions_terminal_resolution before insert or update of status on public.submissions
for each row execute procedure public.set_terminal_resolution();

-- Storage cleanup is performed by the Storage API (see retention-cleanup Edge
-- Function). The RPC only anonymizes relational data and returns the exact
-- private objects for the scheduler to remove; direct DELETE is unsupported by
-- storage's allow_delete_query trigger.
drop function if exists public.retention_cleanup();
create or replace function public.retention_cleanup()
returns table(bucket_id text, object_path text)
language plpgsql security definer set search_path=public,storage as $$
begin
  if session_user not in ('postgres','service_role') and coalesce(auth.jwt()->>'role','')<>'service_role' then
    raise exception 'retention_scheduler_required';
  end if;
  return query
  select o.bucket_id,o.name from storage.objects o
  where o.bucket_id in ('source-photos','weighing-evidence') and exists(
    select 1 from public.submissions s left join public.transactions t on t.submission_id=s.id
    where (s.source_photo_path=o.name or t.weighing_evidence_path=o.name)
      and s.status in ('completed','cancelled','rejected','expired')
      and coalesce(t.resolved_at,s.resolved_at)<now()-interval '90 days');
  update public.submission_locations l set precise_address=null,precise_latitude=null,precise_longitude=null
    where exists(select 1 from public.submissions s where s.id=l.submission_id
      and s.status in ('completed','cancelled','rejected','expired') and s.resolved_at<now()-interval '90 days');
  update public.submissions s set source_photo_path=null
    where s.status in ('completed','cancelled','rejected','expired') and s.resolved_at<now()-interval '90 days';
  update public.transactions t set weighing_evidence_path=null
    where t.resolved_at<now()-interval '90 days' and t.submission_id in
      (select id from public.submissions where status in ('completed','cancelled','rejected','expired'));
end;
$$;
revoke all on function public.retention_cleanup() from public,anon,authenticated;
grant execute on function public.retention_cleanup() to service_role;

-- Completion-month-filtered aggregate. Actor denominators are counted once
-- per city/filter, while provenance components retain every formula/baseline.
drop function if exists public.dlh_city_metrics();
create or replace function public.dlh_city_metrics(p_completion_month date)
returns table(city_id uuid,completion_month date,completed_transactions bigint,organic_kg numeric,inorganic_kg numeric,
  active_sources bigint,active_processors bigint,formula_version text,baseline_id uuid,points_per_kg numeric,
  emissions_factor numeric,economic_factor numeric,target_kg numeric,emissions_avoided_kg numeric,economic_value numeric,
  provenance_components jsonb)
language plpgsql stable security definer set search_path=public as $$
begin
  if not (public.is_role('dlh') or public.is_role('admin')) then raise exception 'aggregate_role_required'; end if;
  return query
  with completed as (
    select s.id,s.city_id,s.source_user_id,s.selected_processor_id,s.material_category,
      s.actual_weight_kg,s.resolved_at,s.status,
      t.completed_at,t.formula_version,t.baseline_id,t.points_per_kg,t.emissions_factor,t.economic_factor,
      b.target_kg,date_trunc('month',coalesce(t.completed_at,s.resolved_at))::date as month_start
    from public.submissions s join public.transactions t on t.submission_id=s.id
      left join public.baselines b on b.id=t.baseline_id
    where s.status='completed' and (p_completion_month is null or date_trunc('month',coalesce(t.completed_at,s.resolved_at))::date=p_completion_month)
  ), grouped as (
    select c.city_id,count(*)::bigint completed_transactions,
      coalesce(sum(c.actual_weight_kg) filter(where c.material_category='organik'),0) organic_kg,
      coalesce(sum(c.actual_weight_kg) filter(where c.material_category='anorganik'),0) inorganic_kg,
      count(distinct c.source_user_id)::bigint active_sources,count(distinct c.selected_processor_id)::bigint active_processors,
      max(c.target_kg) target_kg,
      coalesce(sum(c.actual_weight_kg*coalesce(c.emissions_factor,0)),0) emissions_avoided_kg,
      coalesce(sum(c.actual_weight_kg*coalesce(c.economic_factor,0)),0) economic_value,
      jsonb_agg(distinct jsonb_build_object('formula_version',c.formula_version,'baseline_id',c.baseline_id,'points_per_kg',c.points_per_kg,'emissions_factor',c.emissions_factor,'economic_factor',c.economic_factor,'month',c.month_start)) provenance_components,
      min(c.formula_version) formula_version,min(c.baseline_id::text)::uuid baseline_id,min(c.points_per_kg) points_per_kg,
      min(c.emissions_factor) emissions_factor,min(c.economic_factor) economic_factor
    from completed c group by c.city_id
  )
  select g.city_id,p_completion_month,
    g.completed_transactions,g.organic_kg,g.inorganic_kg,g.active_sources,g.active_processors,
    g.formula_version,g.baseline_id,g.points_per_kg,g.emissions_factor,g.economic_factor,g.target_kg,
    g.emissions_avoided_kg,g.economic_value,g.provenance_components from grouped g;
end;
$$;
revoke all on function public.dlh_city_metrics(date) from public,anon;
grant execute on function public.dlh_city_metrics(date) to authenticated;

-- PostgREST clients use the no-argument RPC. Keep the filtered overload for
-- reports while returning one denominator-safe aggregate for the default call.
create or replace function public.dlh_city_metrics()
returns table(city_id uuid,completion_month date,completed_transactions bigint,organic_kg numeric,inorganic_kg numeric,
  active_sources bigint,active_processors bigint,formula_version text,baseline_id uuid,points_per_kg numeric,
  emissions_factor numeric,economic_factor numeric,target_kg numeric,emissions_avoided_kg numeric,economic_value numeric,
  provenance_components jsonb)
language sql stable security definer set search_path=public as $$
  select * from public.dlh_city_metrics(null::date)
$$;
revoke all on function public.dlh_city_metrics() from public,anon,authenticated;
grant execute on function public.dlh_city_metrics() to authenticated;

-- Scheduled events use an explicit date/time and location rather than now().
create or replace function public.create_content_draft(
  p_kind text,p_title text,p_body text,p_event_at timestamptz default null,p_event_location text default null
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid; v_at timestamptz;
begin
  if auth.uid() is null or not public.is_role('pengolah') or nullif(trim(coalesce(p_title,'')),'') is null then raise exception 'draft_forbidden'; end if;
  if p_kind='article' then
    insert into public.content(author_id,title,summary,body,status) values(auth.uid(),trim(p_title),trim(p_body),trim(p_body),'draft') returning id into v_id;
  elsif p_kind='event' then
    v_at:=coalesce(p_event_at,now());
    if v_at<=now() or nullif(trim(coalesce(p_event_location,'')),'') is null then raise exception 'event_schedule_required'; end if;
    insert into public.events(organizer_id,title,organizer,date,location,status)
      values(auth.uid(),trim(p_title),trim(p_title),v_at,trim(p_event_location),'draft') returning id into v_id;
  else raise exception 'draft_kind_invalid'; end if;
  insert into public.audit_events(actor_id,action,entity_type,entity_id) values(auth.uid(),'content_draft_create',p_kind,v_id);
  return v_id;
end;
$$;
revoke all on function public.create_content_draft(text,text,text,timestamptz,text) from public,anon;
grant execute on function public.create_content_draft(text,text,text,timestamptz,text) to authenticated;
