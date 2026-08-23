-- Create private buckets in the Supabase dashboard/CLI, then apply policies.
insert into storage.buckets(id,name,public) values ('source-photos','source-photos',false),('processor-evidence','processor-evidence',false),('weighing-evidence','weighing-evidence',false) on conflict(id) do nothing;
drop policy if exists source_photo_members on storage.objects;
drop policy if exists source_photo_owner_upload on storage.objects;
drop policy if exists processor_evidence_private on storage.objects;
drop policy if exists processor_evidence_upload on storage.objects;
drop policy if exists weighing_evidence_members on storage.objects;
drop policy if exists weighing_evidence_upload on storage.objects;
create policy source_photo_members on storage.objects for select using(bucket_id='source-photos' and (owner_id=auth.uid()::text or public.is_role('admin')));
create policy source_photo_owner_upload on storage.objects for insert with check(bucket_id='source-photos' and owner_id=auth.uid()::text);
create policy processor_evidence_private on storage.objects for select using(bucket_id='processor-evidence' and (owner_id=auth.uid()::text or public.is_role('admin')));
create policy processor_evidence_upload on storage.objects for insert with check(bucket_id='processor-evidence' and owner_id=auth.uid()::text and public.is_role('pengolah'));
create policy weighing_evidence_members on storage.objects for select using(bucket_id='weighing-evidence' and (owner_id=auth.uid()::text or public.is_role('admin')));
create policy weighing_evidence_upload on storage.objects for insert with check(bucket_id='weighing-evidence' and owner_id=auth.uid()::text and public.is_role('pengolah'));
