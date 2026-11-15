import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.118.0'
import { corsHeaders } from '../_shared/cors.ts'
import { MEMBERSHIP_LIMITS, sandboxAccountAllowed, founderAccountConfirmed } from '../_shared/membership.ts'
import { refreshAppleSubscription } from '../_shared/apple-store.ts'
import { checkRateLimit } from '../_shared/ratelimit.ts'

Deno.serve(async req => {
  const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } })
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)
  try {
    const auth = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } } })
    const { data: { user }, error: authError } = await auth.auth.getUser()
    if (authError || !user) return json({ error: 'Sign in to view your membership.' }, 401)
    if (!await checkRateLimit(user.id, 'membership', 60, 3600)) return json({ error: 'Try again shortly.' }, 429)
    const raw = await req.text()
    if (raw.length > 1024) return json({ error: 'Request too large' }, 413)
    const body = JSON.parse(raw)
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
    const allowSandbox = sandboxAccountAllowed(user.id, Deno.env.get('APP_STORE_SANDBOX_USER_IDS'))
    if (body.action === 'claim') {
      if (Deno.env.get('MEMBERSHIP_ENFORCED') !== 'true') return json({ error: 'Founding memberships aren’t open yet.' }, 409)
      if (!founderAccountConfirmed(user)) return json({ error: 'Confirm your email before claiming founding access.' }, 403)
      const { error } = await admin.rpc('claim_founding_membership', { p_user_id: user.id })
      if (error) {
        const message = error.message.includes('confirmed_account_required') ? 'Confirm your email before claiming founding access.'
          : error.message.includes('already_subscribed') ? 'Your subscription already includes premium access.'
          : 'Founding access is not available. You can still use free tracking or choose a subscription.'
        return json({ error: message }, 409)
      }
    } else if (body.action === 'sync') {
      if (typeof body.transactionId !== 'string' || !/^\d{1,40}$/.test(body.transactionId)) return json({ error: 'Invalid transaction' }, 400)
      if (!['Production','Sandbox'].includes(body.environment) || (body.environment === 'Sandbox' && !allowSandbox)) return json({ error: 'This purchase environment is not enabled for this account.' }, 403)
      await refreshAppleSubscription(admin, body.transactionId, user.id, body.environment)
    } else if (body.action === 'status') {
      const { data, error } = await admin.from('apple_subscriptions').select('original_transaction_id,environment,checked_at').eq('user_id', user.id)
      if (error) throw Error('Could not check subscription')
      for (const row of data ?? []) if ((row.environment === 'Production' || allowSandbox) && Date.parse(row.checked_at) < Date.now() - 15 * 60000) {
        await refreshAppleSubscription(admin, row.original_transaction_id, user.id, row.environment)
      }
    } else return json({ error: 'Unknown membership action' }, 400)
    const { data, error } = await admin.rpc('membership_snapshot', { p_user_id: user.id, p_allow_sandbox: allowSandbox })
    if (error || !data) throw Error('Could not load membership')
    return json({ ...data, enforced: Deno.env.get('MEMBERSHIP_ENFORCED') === 'true' || allowSandbox, pulse_limit: MEMBERSHIP_LIMITS.pulse, food_limit: MEMBERSHIP_LIMITS.food })
  } catch {
    // Provider failures can contain signed purchase data. Never log raw exceptions.
    return json({ error: 'Couldn’t verify your membership. Try again when you’re connected.' }, 503)
  }
})
