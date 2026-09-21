-- Private bucket for user-uploaded files. Objects are stored under
-- "<user_id>/<filename>" so RLS can scope access per user using the first
-- path segment.
insert into storage.buckets (id, name, public)
values ('uploads', 'uploads', false)
on conflict (id) do nothing;

create policy "uploads_insert_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'uploads'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "uploads_select_own_or_admin"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'uploads'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.is_admin(auth.uid())
  )
);

create policy "uploads_delete_own_or_admin"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'uploads'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.is_admin(auth.uid())
  )
);
