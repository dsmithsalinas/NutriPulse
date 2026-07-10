import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Per-user fixed-window rate limit, backed by the public.check_rate_limit() Postgres function
// (see migration 20260710000000_rate_limits.sql). The function derives the user from the JWT, so
// the client-scoped `supabase` created with the caller's Authorization header is all that's needed.
//
// Returns true when the call is allowed. Fails OPEN (allowed) on an unexpected RPC error: a
// transient DB problem shouldn't take the whole feature down, and per-request input caps still
// bound the cost of any single call. A genuine over-limit returns false (allowed = data === false).
export async function checkRateLimit(
  supabase: SupabaseClient,
  bucket: string,
  max: number,
  windowSeconds: number,
): Promise<boolean> {
  const { data, error } = await supabase.rpc('check_rate_limit', {
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
