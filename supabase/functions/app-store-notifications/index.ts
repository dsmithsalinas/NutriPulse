import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.118.0'
import { sandboxAccountAllowed } from '../_shared/membership.ts'
import { appleStore, refreshAppleSubscription } from '../_shared/apple-store.ts'

// Public Apple webhook. Authentication is Apple's signed payload and certificate chain,
// not a Supabase JWT. Invalid notifications never change membership state.
Deno.serve(async req => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 })
  try {
    const raw = await req.text()
    if (raw.length > 100000) return new Response('Too large', { status: 413 })
    const { signedPayload } = JSON.parse(raw)
    if (typeof signedPayload !== 'string') return new Response('Invalid payload', { status: 400 })
    let verified
    for (const environment of ['Production','Sandbox']) {
      try {
        const { verifier } = appleStore(environment)
        const notification = await verifier.verifyAndDecodeNotification(signedPayload)
        verified = { notification, verifier, environment }; break
      } catch { /* Try the other Apple environment; no decoded data is trusted yet. */ }
    }
    if (!verified) return new Response('Invalid signature or unavailable configuration', { status: 503 })
    const { notification, verifier, environment } = verified
    if (notification.notificationType === 'TEST') return new Response('ok')
    if (!notification.data?.signedTransactionInfo) return new Response('ok')
    const tx = await verifier.verifyAndDecodeTransaction(notification.data.signedTransactionInfo)
    if (environment === 'Sandbox' && !sandboxAccountAllowed(tx.appAccountToken ?? '', Deno.env.get('APP_STORE_SANDBOX_USER_IDS'))) return new Response('Unsupported test account', { status: 400 })
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
    // Deleted accounts stay deleted. Do not recreate a user or attach a purchase to someone else.
    const { data, error } = await admin.from('apple_subscriptions').select('user_id').eq('original_transaction_id', tx.originalTransactionId!).eq('environment', environment).maybeSingle()
    if (error) throw Error('Lookup failed')
    if (!data) return new Response('ok') // Device sync can establish the initial owner.
    await refreshAppleSubscription(admin, tx.originalTransactionId!, data.user_id, environment)
    return new Response('ok')
  } catch { return new Response('Retry later', { status: 503 }) }
})
