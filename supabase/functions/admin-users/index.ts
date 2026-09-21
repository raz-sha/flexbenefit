// Edge Function: admin-users
//
// Every privileged user-management action (creating an auth user, deleting
// one, resetting a password) requires the Supabase service-role key. That
// key must never reach the Flutter/web client, so this function is the only
// place it is used. The caller's JWT is verified and their `profiles.role`
// is checked to be 'admin' before anything runs.
//
// Deploy with:
//   supabase functions deploy admin-users
//   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=... (from project settings)
// (SUPABASE_URL and SUPABASE_ANON_KEY are provided automatically.)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const USERNAME_RE = /^[a-z0-9_]{3,20}$/;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
  if (!jwt) return json({ error: "Missing authorization" }, 401);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const { data: callerData, error: callerError } = await admin.auth.getUser(jwt);
  if (callerError || !callerData?.user) {
    return json({ error: "Invalid session" }, 401);
  }
  const callerId = callerData.user.id;

  const { data: callerProfile, error: profileError } = await admin
    .from("profiles")
    .select("role")
    .eq("id", callerId)
    .maybeSingle();

  if (profileError || callerProfile?.role !== "admin") {
    return json({ error: "Forbidden: admin only" }, 403);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  try {
    switch (body.action) {
      case "create": {
        const username = String(body.username ?? "").trim().toLowerCase();
        const password = String(body.password ?? "");
        const fullName = String(body.full_name ?? "");
        const role = body.role === "admin" ? "admin" : "user";

        if (!USERNAME_RE.test(username)) {
          return json({ error: "Invalid username (3-20 chars: a-z 0-9 _)" }, 400);
        }
        if (password.length < 6) {
          return json({ error: "Password must be at least 6 characters" }, 400);
        }

        const { data: created, error: createError } = await admin.auth.admin.createUser({
          email: `${username}@app.internal`,
          password,
          email_confirm: true,
        });
        if (createError || !created?.user) {
          return json({ error: createError?.message ?? "Failed to create user" }, 400);
        }

        const { error: insertError } = await admin.from("profiles").insert({
          id: created.user.id,
          username,
          full_name: fullName,
          role,
        });
        if (insertError) {
          await admin.auth.admin.deleteUser(created.user.id);
          const msg = insertError.message.includes("duplicate")
            ? "Username already taken"
            : insertError.message;
          return json({ error: msg }, 400);
        }

        return json({ ok: true, user_id: created.user.id });
      }

      case "delete": {
        const userId = String(body.user_id ?? "");
        if (!userId) return json({ error: "user_id is required" }, 400);
        if (userId === callerId) {
          return json({ error: "Cannot delete your own account" }, 400);
        }

        const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
        if (deleteError) return json({ error: deleteError.message }, 400);

        return json({ ok: true });
      }

      case "reset_password": {
        const userId = String(body.user_id ?? "");
        const newPassword = String(body.new_password ?? "");
        if (!userId || newPassword.length < 6) {
          return json(
            { error: "user_id and a password of 6+ characters are required" },
            400,
          );
        }

        const { error: updateError } = await admin.auth.admin.updateUserById(userId, {
          password: newPassword,
        });
        if (updateError) return json({ error: updateError.message }, 400);

        return json({ ok: true });
      }

      default:
        return json({ error: "Unknown action" }, 400);
    }
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});
