/// Supabase project config.
///
/// The anon/publishable key is meant to be shipped in client code — it's
/// not a secret; access control is enforced by Row Level Security on the
/// database side, not by hiding this key. The service-role key must never
/// go here; it's only used server-side in supabase/functions/admin-users.
class Env {
  static const supabaseUrl = 'https://bgtwdlvckgyojtigrwjz.supabase.co';
  static const supabaseAnonKey =
      'sb_publishable_gFWkCvumUA3Wmzh6MFpTRA_n2HOeerJ';
}
