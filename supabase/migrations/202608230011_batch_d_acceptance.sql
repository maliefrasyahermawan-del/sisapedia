-- Batch D forward-only hardening.
-- Storage owns storage.objects in Supabase.  Revoke capabilities as the
-- storage owner rather than relying on a revoke issued by postgres.
-- On Supabase-hosted projects this block must run as the storage owner role.
-- The local CLI migration role cannot assume that reserved role, so retain a
-- safe no-op fallback there and expose the required owner operation in the
-- migration text for the hosted migration runner.
do $$
begin
  begin
    execute 'set local role supabase_storage_admin';
    execute 'revoke truncate, references, trigger on table storage.objects from anon, authenticated';
    execute 'revoke all on table storage.objects from anon';
    execute 'revoke all on table storage.objects from authenticated';
    execute 'grant select, insert, update, delete on table storage.objects to authenticated';
  exception when insufficient_privilege then
    raise warning 'storage ACL remediation requires supabase_storage_admin owner session';
  end;
end;
$$;

-- Repeat the public-table capability boundary for every table, including
-- tables introduced by later migrations. RLS remains the data boundary.
revoke truncate, references, trigger on all tables in schema public from anon, authenticated;

-- Durable retention outbox.  A failed Storage API delete never loses the
-- relational path: only retention_acknowledge(true) clears it.
create table if not exists public.retention_object_queue(
  id bigint generated always as identity primary key,
  bucket_id text not null check(bucket_id in ('source-photos','weighing-evidence')),
  object_path text not null,
  status text not null default 'queued' check(status in ('queued','processing','failed','deleted')),
  attempts integer not null default 0 check(attempts>=0),
  last_error text,
  claimed_at timestamptz,
  next_attempt_at timestamptz not null default now(),
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  unique(bucket_id,object_path)
);
create index if not exists retention_object_queue_claim_idx
  on public.retention_object_queue(status,next_attempt_at,claimed_at);
alter table public.retention_object_queue enable row level security;
revoke all on table public.retention_object_queue from public,anon,authenticated;
grant select,insert,update,delete on table public.retention_object_queue to service_role;

drop function if exists public.retention_cleanup();
create or replace function public.retention_cleanup()
returns table(queue_id bigint,bucket_id text,object_path text)
language plpgsql security definer set search_path=public,storage as $$
begin
  if session_user not in ('postgres','service_role') and coalesce(auth.jwt()->>'role','')<>'service_role' then
    raise exception 'retention_scheduler_required';
  end if;

  insert into public.retention_object_queue(bucket_id,object_path)
  select 'source-photos',s.source_photo_path
    from public.submissions s
   where s.source_photo_path is not null
     and s.status in ('completed','cancelled','rejected','expired')
     and s.resolved_at<now()-interval '90 days'
  union
  select 'weighing-evidence',t.weighing_evidence_path
    from public.transactions t join public.submissions s on s.id=t.submission_id
   where t.weighing_evidence_path is not null
     and s.status in ('completed','cancelled','rejected','expired')
     and coalesce(t.resolved_at,s.resolved_at)<now()-interval '90 days'
  on conflict on constraint retention_object_queue_bucket_id_object_path_key do nothing;

  return query
  with claimable as (
    select q.id from public.retention_object_queue q
     where (q.status in ('queued','failed') and q.next_attempt_at<=now())
        or (q.status='processing' and q.claimed_at<now()-interval '30 minutes')
     order by q.id
     limit 100
     for update skip locked
  ), claimed as (
    update public.retention_object_queue q
       set status='processing',attempts=q.attempts+1,claimed_at=now(),last_error=null
      from claimable c where q.id=c.id
    returning q.id,q.bucket_id,q.object_path
  ) select claimed.id,claimed.bucket_id,claimed.object_path from claimed;
end;
$$;
revoke all on function public.retention_cleanup() from public,anon,authenticated;
grant execute on function public.retention_cleanup() to service_role;

create or replace function public.retention_acknowledge(
  p_queue_id bigint,p_success boolean,p_error text default null
) returns void language plpgsql security definer set search_path=public as $$
declare q public.retention_object_queue;
begin
  if session_user not in ('postgres','service_role') and coalesce(auth.jwt()->>'role','')<>'service_role' then
    raise exception 'retention_scheduler_required';
  end if;
  select * into q from public.retention_object_queue where id=p_queue_id for update;
  if q.id is null or q.status not in ('processing','failed','queued') then
    raise exception 'retention_queue_item_invalid';
  end if;
  if p_success then
    update public.retention_object_queue set status='deleted',deleted_at=now(),claimed_at=null where id=q.id;
    if q.bucket_id='source-photos' then
      update public.submissions set source_photo_path=null
       where source_photo_path=q.object_path
         and status in ('completed','cancelled','rejected','expired');
    elsif q.bucket_id='weighing-evidence' then
      update public.transactions set weighing_evidence_path=null
       where weighing_evidence_path=q.object_path;
    end if;
  else
    update public.retention_object_queue
       set status='failed',claimed_at=null,last_error=left(coalesce(p_error,'storage_delete_failed'),1000),
           next_attempt_at=now()+make_interval(mins=>least(1440,greatest(5,5*greatest(attempts,1))))
     where id=q.id;
  end if;
end;
$$;
revoke all on function public.retention_acknowledge(bigint,boolean,text) from public,anon,authenticated;
grant execute on function public.retention_acknowledge(bigint,boolean,text) to service_role;

-- Remove the ambiguous 3-argument PostgREST overload. Clients always send
-- the five named arguments, using null for article scheduling fields.
drop function if exists public.create_content_draft(text,text,text);
drop function if exists public.create_content_draft(text,text,text,timestamptz,text);
create or replace function public.create_content_draft(
  p_kind text,p_title text,p_body text,p_event_at timestamptz,p_event_location text
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
  if auth.uid() is null or not public.is_role('pengolah') or nullif(trim(coalesce(p_title,'')),'') is null then raise exception 'draft_forbidden'; end if;
  if p_kind='article' then
    insert into public.content(author_id,title,summary,body,status)
      values(auth.uid(),trim(p_title),trim(p_body),trim(p_body),'draft') returning id into v_id;
  elsif p_kind='event' then
    if p_event_at is null or p_event_at<=now() or nullif(trim(coalesce(p_event_location,'')),'') is null then raise exception 'event_schedule_required'; end if;
    insert into public.events(organizer_id,title,organizer,date,location,status)
      values(auth.uid(),trim(p_title),trim(p_title),p_event_at,trim(p_event_location),'draft') returning id into v_id;
  else raise exception 'draft_kind_invalid'; end if;
  insert into public.audit_events(actor_id,action,entity_type,entity_id)
    values(auth.uid(),'content_draft_create',p_kind,v_id);
  return v_id;
end;
$$;
revoke all on function public.create_content_draft(text,text,text,timestamptz,text) from public,anon;
grant execute on function public.create_content_draft(text,text,text,timestamptz,text) to authenticated;

-- Keep the durable queue and lifecycle tables available to Realtime clients
-- only where RLS/policies already authorize their rows.
do $$
begin
  begin alter publication supabase_realtime add table public.retention_object_queue; exception when duplicate_object or undefined_object then null; end;
end;
$$;
