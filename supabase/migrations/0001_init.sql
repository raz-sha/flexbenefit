-- Profile table: one row per app user, keyed to auth.users.
-- Created only by the "admin-users" Edge Function (service role), never
-- directly by clients, so there is no public insert policy.
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique,
  full_name text not null default '',
  role text not null default 'user' check (role in ('admin', 'user')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Security-definer helper so policies can check "is this caller an admin"
-- without recursively evaluating the RLS policy on profiles itself.
create or replace function public.is_admin(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles where id = uid and role = 'admin'
  );
$$;

-- Read: a user can see their own row; an admin can see everyone's.
create policy "profiles_select_own_or_admin"
on public.profiles
for select
using (auth.uid() = id or public.is_admin(auth.uid()));

-- Update: a user can update their own row (full_name); an admin can update
-- any row. The trigger below stops non-admins from smuggling in a role or
-- username change through their "own row" grant.
create policy "profiles_update_own"
on public.profiles
for update
using (auth.uid() = id)
with check (auth.uid() = id);

create policy "profiles_update_admin"
on public.profiles
for update
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

create or replace function public.guard_profile_self_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin(auth.uid()) then
    if new.role is distinct from old.role
      or new.username is distinct from old.username then
      raise exception 'Only an admin can change role or username';
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_guard_profile_self_update
before update on public.profiles
for each row execute function public.guard_profile_self_update();

-- No insert/delete policies for authenticated/anon: those only happen via
-- the Edge Function using the service role key, which bypasses RLS.
