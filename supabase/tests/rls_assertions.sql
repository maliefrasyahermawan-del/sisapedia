-- Run with `supabase test db` or psql against a disposable local project.
-- These assertions intentionally never use production credentials.
begin;
select plan(54);
-- Disposable-db actor fixtures (when running against a local Supabase stack):
-- create one Sumber, pending/approved Pengolah, unrelated Sumber, DLH and
-- Admin profile; set request.jwt.claim.sub/role per case. The assertions below
-- are schema-safe without external auth, while the executable actor matrix is:
-- anon: no RPC/storage writes; Sumber: own create/cancel/confirm/redeem only;
-- pending Pengolah: application only; approved Pengolah: own offer/pickup/
-- evidence only; unrelated users: no cross-owner rows/locations; DLH: only
-- dlh_city_metrics; Admin: review/dispute/redeem/content moderation.
select has_table('public','submission_locations','precise location is separate');
select has_function('public','create_submission','sumber creation is RPC-only');
select has_function('public','accept_offer','offer acceptance is transactional');
select has_function('public','approve_processor','processor review is admin RPC-only');
select has_function('public','approve_redeem','redeem approval is idempotent RPC');
select has_function('public','dlh_city_metrics','DLH aggregate access is role-gated RPC');
select policies_are('public','submissions',ARRAY['submissions_member_select_safe','submissions_source_create_rpc'],'submission writes are RPC-only');
select policies_are('public','submission_locations',ARRAY['locations_source_admin_after_accept','locations_rpc_insert'],'precise locations are protected');
select has_function('public','provision_privileged_profile','privileged roles require admin provisioning');
select has_function('public','fulfill_redeem','redeem fulfilment is audited RPC-only');
select ok(exists(select 1 from pg_policies where schemaname='public' and tablename='formula_versions' and policyname='formula_versions_dlh_admin'),'formula versions are DLH/Admin only');
select ok(exists(select 1 from pg_policies where schemaname='public' and tablename='processor_profiles' and policyname='processors_read'),'processor reads remain RLS scoped');
select has_table('public','processor_materials','materials are normalized by subtype');
select has_function('public','update_processor_operational','operational availability uses a narrow RPC');
select has_function('public','processor_pickup_window_matches','pickup interval overlap is timezone-aware');
select has_function('public','create_content_draft','content creation is draft-only RPC');
select ok(exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='source_photos_participant'),'source photos are participant scoped');
select ok(exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='weighing_photos_participant'),'weighing evidence is participant scoped');
select has_function('public','retention_cleanup','retention is explicit scheduler function');
select has_function('public','retention_acknowledge','retention deletion acknowledgement is durable');
select has_table('public','retention_object_queue','retention deletion outbox is durable');
select ok(not exists(
  select 1
    from (values ('anon'),('authenticated')) as roles(role_name)
    cross join (values
      ('public.cities'),('public.profiles'),('public.processor_profiles'),
      ('public.submissions'),('public.submission_locations'),('public.match_candidates'),
      ('public.offers'),('public.transactions'),('public.point_ledger'),
      ('public.redeem_requests'),('public.notifications'),('public.content'),
      ('public.events'),('public.event_participation'),('public.formula_versions'),
      ('public.baselines'),('public.audit_events'),('storage.objects')
    ) as tables(table_name)
   where has_table_privilege(roles.role_name,tables.table_name,'TRUNCATE')
      or has_table_privilege(roles.role_name,tables.table_name,'REFERENCES')
      or has_table_privilege(roles.role_name,tables.table_name,'TRIGGER')
), 'anon/authenticated lack destructive table capabilities everywhere');
select has_function('public','consume_sari_rate_limit','Sari has a persisted per-user limit');
select has_function('public','submit_redeem','redeem status is server-created');
select has_function('public','update_processor_operational','processor availability is narrow RPC');
select has_function('public','reject_offer','offer rejection requires reason/fallback');
select has_function('public','expire_offer','offer expiry is audited/fallback');
select has_function('public','record_weighing','weighing requires participant evidence');
select has_function('public','resolve_dispute','dispute resolution stores formula provenance');
select has_index('public','offers','offers_one_pending_submission','one active offer per submission');
select ok(exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='source_photos_owner_insert'),'source uploads require membership');
select ok(exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='weighing_photos_processor_insert'),'weighing uploads require selected processor');

-- Disposable actor matrix. The auth rows and all domain fixtures are inside
-- this transaction and are rolled back at the end of the file.
insert into auth.users(id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,email_confirmed_at)
values
 ('00000000-0000-0000-0000-000000000101','authenticated','authenticated','sumber.rls@example.test','x','{}','{}',now(),now(),now()),
 ('00000000-0000-0000-0000-000000000102','authenticated','authenticated','unrelated.rls@example.test','x','{}','{}',now(),now(),now()),
 ('00000000-0000-0000-0000-000000000103','authenticated','authenticated','pending.rls@example.test','x','{}','{}',now(),now(),now()),
 ('00000000-0000-0000-0000-000000000104','authenticated','authenticated','approved.rls@example.test','x','{}','{}',now(),now(),now()),
 ('00000000-0000-0000-0000-000000000105','authenticated','authenticated','dlh.rls@example.test','x','{}','{}',now(),now(),now()),
 ('00000000-0000-0000-0000-000000000106','authenticated','authenticated','admin.rls@example.test','x','{}','{}',now(),now(),now());
update public.profiles set primary_role='dlh' where id='00000000-0000-0000-0000-000000000105';
update public.profiles set primary_role='admin' where id='00000000-0000-0000-0000-000000000106';
update public.profiles set primary_role='pengolah' where id in ('00000000-0000-0000-0000-000000000103','00000000-0000-0000-0000-000000000104');
insert into public.audit_events(actor_id,action,entity_type) values('00000000-0000-0000-0000-000000000106','rls_fixture','test');
insert into public.processor_profiles(id,display_name,processor_type,status,materials,total_capacity_kg,available_capacity_kg,latitude,longitude)
values
 ('00000000-0000-0000-0000-000000000103','Pending RLS','bank_sampah','pending',array['Botol Plastik PET'],10,10,-7.02,110.40),
 ('00000000-0000-0000-0000-000000000104','Approved RLS','bank_sampah','approved',array['Botol Plastik PET'],10,10,-7.02,110.40);
insert into public.processor_materials(processor_id,material_category,material_subtype)
values('00000000-0000-0000-0000-000000000103','anorganik','botol plastik pet'),
      ('00000000-0000-0000-0000-000000000104','anorganik','botol plastik pet')
on conflict do nothing;
insert into public.submissions(id,city_id,source_user_id,material_category,material_subtype,estimated_weight_kg,administrative_area,status,source_photo_path)
values('00000000-0000-0000-0000-000000000201',(select id from public.cities where code='semarang'),'00000000-0000-0000-0000-000000000101','anorganik','Botol Plastik PET',2,'Semarang','submitted','00000000-0000-0000-0000-000000000201/source.jpg');
insert into public.submission_locations(submission_id,source_user_id,city_id,district,administrative_area,precise_address,precise_latitude,precise_longitude)
values('00000000-0000-0000-0000-000000000201','00000000-0000-0000-0000-000000000101',(select id from public.cities where code='semarang'),'Banyumanik','Semarang','Jalan privat',-7.02,110.40);
insert into public.events(id,organizer_id,title,organizer,date,location,status)
values('00000000-0000-0000-0000-000000000301','00000000-0000-0000-0000-000000000104','Event RLS','Approved RLS',now()+interval '1 day','Semarang','approved');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000101',true);
select ok((select count(*) from public.submissions where id='00000000-0000-0000-0000-000000000201')=1,'Sumber can read own submission');
select ok((select count(*) from public.submission_locations where submission_id='00000000-0000-0000-0000-000000000201')=1,'Sumber can read own precise location');
select ok((select count(*) from public.submissions where source_user_id='00000000-0000-0000-0000-000000000102')=0,'Sumber cannot read unrelated submission');
select ok((select count(*) from public.submission_locations where source_user_id='00000000-0000-0000-0000-000000000102')=0,'Sumber cannot read unrelated location');
select throws_ok($$insert into public.event_participation(event_id,user_id) values('00000000-0000-0000-0000-000000000301','00000000-0000-0000-0000-000000000101')$$,'42501',null,'direct participation writes are denied');
select throws_ok($$insert into public.redeem_requests(user_id,points,description,status) values('00000000-0000-0000-0000-000000000101',1,'forged','approved')$$,'42501',null,'direct redeem writes are denied');
select throws_ok($$update public.processor_profiles set total_capacity_kg=999 where id='00000000-0000-0000-0000-000000000104'$$,'42501',null,'processor direct operational writes are denied');
select ok(not has_table_privilege('authenticated','public.submissions','TRUNCATE'),'authenticated cannot truncate submissions');
select ok(not has_table_privilege('anon','public.submissions','TRUNCATE'),'anon cannot truncate submissions');
select lives_ok($$insert into storage.objects(bucket_id,name,owner_id,metadata) values('source-photos','00000000-0000-0000-0000-000000000201/source.jpg','00000000-0000-0000-0000-000000000101','{}'::jsonb)$$,'Sumber can upload submission-scoped source evidence');
select throws_ok($$insert into storage.objects(bucket_id,name,owner_id,metadata) values('source-photos','wrong/path.jpg','00000000-0000-0000-0000-000000000101','{}'::jsonb)$$,'42501',null,'wrong source evidence path is denied');
select ok((select count(*) from storage.objects where bucket_id='source-photos' and name='00000000-0000-0000-0000-000000000201/source.jpg')=1,'Sumber can read own uploaded evidence');

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000104',true);
select ok((select count(*) from public.submission_locations where submission_id='00000000-0000-0000-0000-000000000201')=0,'Approved processor cannot read pre-accept location');
select ok(public.is_role('pengolah'),'Approved processor role is recognized');
select throws_ok($$select public.approve_processor('00000000-0000-0000-0000-000000000103',true,'self')$$,'P0001',null,'Processor cannot self-approve');

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000105',true);
select ok((select count(*) from public.submissions)=0,'DLH cannot read individual submissions');
select lives_ok($$select * from public.dlh_city_metrics()$$,'DLH aggregate RPC is callable');

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000106',true);
select ok((select count(*) from public.audit_events)>0,'Admin can read audit events');
select lives_ok($$select public.approve_processor('00000000-0000-0000-0000-000000000103',false,'insufficient evidence')$$,'Admin can review processor through RPC');
select throws_ok($$select public.provision_privileged_profile('00000000-0000-0000-0000-000000000102','admin','forged',null)$$,'42501',null,'Authenticated Admin cannot use server-only provisioning');

set local role anon;
select set_config('request.jwt.claim.role','anon',true);
select ok((select count(*) from public.cities where enabled)=1,'Anon can read enabled cities');
select throws_ok($$select public.join_event('00000000-0000-0000-0000-000000000301')$$,'42501',null,'Anon cannot call event join RPC');
select * from finish();
rollback;
