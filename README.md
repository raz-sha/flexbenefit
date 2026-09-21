# flexbenefit

Flutter web app with role-based login (admin / user) backed by Supabase, deployed to GitHub Pages for free.

Login uses a **username + password**, not a real email address. Under the hood each username is
mapped to a stable, non-routable pseudo-email (`<username>@app.internal`) so Supabase's
email/password auth can be reused without ever requiring or sending a real email.

There is no public sign-up screen. Admins create every account (including the first admin, see
below) from the in-app "Manage users" screen.

## Architecture

- `lib/` — Flutter app (login screen, role-based routing, admin CRUD screens).
- `supabase/migrations/0001_init.sql` — `profiles` table (username, full_name, role) + RLS policies.
- `supabase/functions/admin-users/` — Edge Function that performs privileged actions (create user,
  delete user, reset password) using the Supabase **service-role key**. That key must never be
  embedded in the Flutter app, since it ships to the browser on GitHub Pages — this function is the
  only place it's used.
- `.github/workflows/deploy.yml` — builds `flutter build web` and publishes it to GitHub Pages.

Non-privileged profile edits (full name, role) go straight through a table update, allowed by an
admin-only Row Level Security policy — no Edge Function round trip needed for those.

## 1. Create the Supabase project

1. Create a free project at [supabase.com](https://supabase.com).
2. In **SQL Editor**, run `supabase/migrations/0001_init.sql`.
3. In **Authentication → Providers → Email**, turn **off** "Confirm email" (not required, since
   accounts are created server-side with `email_confirm: true`, but simplest to disable it).
4. In **Project Settings → API**, note down:
   - `Project URL` → `SUPABASE_URL`
   - `anon public` key → `SUPABASE_ANON_KEY`
   - `service_role` key → used only for the Edge Function secret below. **Never** put this in the
     Flutter app or in a GitHub Actions secret consumed by the client build.

## 2. Deploy the Edge Function

Requires the [Supabase CLI](https://supabase.com/docs/guides/cli).

```bash
supabase login
supabase link --project-ref <your-project-ref>
supabase functions deploy admin-users
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<service_role key from step 1.4>
```

`SUPABASE_URL` is provided to Edge Functions automatically; you only need to set the service-role
key as a secret.

## 3. Create the first admin

There's no public sign-up, so bootstrap one admin manually:

1. Supabase Dashboard → **Authentication → Users → Add user** → create with email
   `admin@app.internal` and a password. Enable "Auto Confirm User".
2. Copy the new user's UUID, then in **SQL Editor**:
   ```sql
   insert into public.profiles (id, username, full_name, role)
   values ('<uuid from step 1>', 'admin', 'Administrator', 'admin');
   ```
3. Log in to the app with username `admin` and the password you set.

From there, use **Manage users** in the app to create every other account (the form takes a
username, password, full name and role — no Edge Function/SQL needed again).

## 4. Configure GitHub Pages + secrets

1. Repo **Settings → Pages → Source** → set to **GitHub Actions**.
2. Repo **Settings → Secrets and variables → Actions**, add:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`

   (The anon key is designed to be public and safe in a client bundle; it's still passed as a
   secret here just to keep it out of the workflow file.)
3. Push to `main` — the `deploy.yml` workflow builds and publishes to
   `https://<your-username>.github.io/flexbenefit/`.

## Local development

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=xxxxx
```

## Notes / next steps

- `web/favicon.png` and `web/icons/*.png` are 1×1 placeholders — swap in real branding art.
- Username rules: lowercase letters, digits, underscore, 3–20 chars (enforced client-side and in
  the Edge Function).
- To promote/demote a role or rename a user's full name, tap them in **Manage users**; to change
  their password, use the "New password" field in the same edit sheet.
