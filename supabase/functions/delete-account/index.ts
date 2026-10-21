import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.118.0'
import { corsHeaders } from '../_shared/cors.ts'
import { AccountDeletionError, deleteAccountWithApple } from '../_shared/apple-account-deletion.ts'
import { appleConfig, appleRevocationClient } from '../_shared/apple-token-revocation.ts'

// Deletes the calling user's auth.users row via the Admin API. Every owned
// table (profiles, food_logs, food_items, favorites/food_favorites,
// weight_logs, water_logs, glp1_logs, feedback, coach_messages,
// body_composition_logs, daily_goals) has an ON DELETE CASCADE FK to
// auth.users(id), so this one call fully removes the user's data —
// satisfies App Store Review Guideline 5.1.1(v).
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405, headers: corsHeaders })

  try {
    const authed = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )
    const { data: { user } } = await authed.auth.getUser()
    if (!user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )
    let body: { appleAuthorizationCode?: unknown; manualAppleRevocation?: unknown } = {}
    if (req.body) {
      try { body = await req.json() } catch {
        throw new AccountDeletionError(400, 'invalid_request', 'Couldn’t read the deletion request. Please try again.')
      }
      if (!body || typeof body !== 'object' || Array.isArray(body)) throw new AccountDeletionError(400, 'invalid_request', 'Invalid deletion request.')
    }
    // Apple code is exchanged just in time; older Apple-linked clients must update rather
    // than silently delete without revocation. Email-only accounts do not require Apple.
    let apple: Awaited<ReturnType<typeof appleRevocationClient>> | undefined
    const getApple = async () => apple ??= await appleRevocationClient(appleConfig(name => Deno.env.get(name)))
    const outcome = await deleteAccountWithApple(user, body.appleAuthorizationCode, {
      exchange: async code => (await getApple()).exchange(code),
      revoke: async token => (await getApple()).revoke(token),
      deleteUser: async id => {
        const { error } = await admin.auth.admin.deleteUser(id)
        if (error) throw new AccountDeletionError(500, 'deletion_failed', 'Couldn’t delete your account. Please try again; Apple may ask you to confirm again.')
      },
    }, body.manualAppleRevocation === true)

    return new Response(JSON.stringify({ success: true, ...outcome }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    // Do not log authorization codes, token responses, request bodies, or signing errors.
    const failure = err instanceof AccountDeletionError ? err : new AccountDeletionError(500, 'deletion_failed', 'Couldn’t delete your account. Please try again.')
    return new Response(JSON.stringify({ error: failure.message, code: failure.code }), {
      status: failure.status,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
