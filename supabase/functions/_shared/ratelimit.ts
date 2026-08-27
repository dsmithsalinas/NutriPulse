import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Per-user fixed-window rate limit, backed by a service-role-only Postgres function. Keeping the
// RPC off the authenticated Data API prevents a modified client from choosing its own limit or
// window and resetting the counter before calling an expensive Edge Function.
//
// Returns true when the call is allowed. Fails OPEN (allowed) on an unexpected RPC error: a
// transient DB problem shouldn't take the whole feature down, and per-request input caps still
// bound the cost of any single call. A genuine over-limit returns false (allowed = data === false).
export async function checkRateLimit(
  userId: string,
  bucket: string,
  max: number,
  windowSeconds: number,
): Promise<boolean> {
  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  )
  const { data, error } = await admin.rpc('check_rate_limit_for_user', {
    p_user_id: userId,
    p_bucket: bucket,
    p_max: max,
    p_window_seconds: windowSeconds,
  })
  if (error) {
    console.error('rate-limit check failed, allowing:', error.message)
    return true
  }
  return data !== false
}
