import { AppStoreServerAPIClient, Environment } from 'npm:@apple/app-store-server-library@3.1.0'
import { Buffer } from 'node:buffer'
import { SignedDataVerifier } from './apple-signed-data-verifier.ts'
import { APPLE_STORE_ROOTS } from './apple-store-roots.ts'
import { subscriptionRecord } from './membership.ts'

// App Store Server API credentials are distinct from Sign in with Apple credentials.
export function appleStore(environment = 'Production') {
  if (!['Production', 'Sandbox'].includes(environment)) throw Error('Invalid store environment')
  const env = environment === 'Production' ? Environment.PRODUCTION : Environment.SANDBOX
  const key = Deno.env.get('APP_STORE_PRIVATE_KEY')
  const keyId = Deno.env.get('APP_STORE_KEY_ID')
  const issuer = Deno.env.get('APP_STORE_ISSUER_ID')
  if (!key || !keyId || !issuer) throw Error('Store is not configured')
  const verifier = new SignedDataVerifier(APPLE_STORE_ROOTS.map(root => Buffer.from(root, 'base64')),
    true, env, 'com.dustin.nutripulse.app', 6789967509)
  const api = new AppStoreServerAPIClient(key, keyId, issuer, 'com.dustin.nutripulse.app', env)
  return { verifier, api, environment }
}

type Admin = { rpc: (name: string, args: Record<string, unknown>) => PromiseLike<{ error: unknown }> }
// Always fetch current status from Apple. Never let a replayed, once-valid device
// transaction or an out-of-order notification resurrect a refunded subscription.
export async function refreshAppleSubscription(admin: Admin, transactionId: string, expectedOwner?: string, requestedEnvironment = 'Production') {
  const { verifier, api, environment } = appleStore(requestedEnvironment)
  const checkedAt = Date.now()
  const info = await api.getTransactionInfo(transactionId)
  if (!info.signedTransactionInfo) throw Error('Missing signed transaction')
  const requested = await verifier.verifyAndDecodeTransaction(info.signedTransactionInfo)
  subscriptionRecord(requested, 2, undefined, requested.signedDate!, checkedAt, expectedOwner)
  const statuses = await api.getAllSubscriptionStatuses(requested.originalTransactionId!)
  if (statuses.environment !== environment || statuses.bundleId !== 'com.dustin.nutripulse.app') throw Error('Wrong application')
  let recorded = false
  for (const group of statuses.data ?? []) for (const item of group.lastTransactions ?? []) {
    if (item.originalTransactionId !== requested.originalTransactionId || !item.signedTransactionInfo) continue
    const tx = await verifier.verifyAndDecodeTransaction(item.signedTransactionInfo)
    if (tx.originalTransactionId !== requested.originalTransactionId) throw Error('Wrong subscription chain')
    const renewal = item.signedRenewalInfo ? await verifier.verifyAndDecodeRenewalInfo(item.signedRenewalInfo) : undefined
    if (renewal && renewal.originalTransactionId !== tx.originalTransactionId) throw Error('Wrong renewal')
    const record = subscriptionRecord(tx, item.status!, renewal?.gracePeriodExpiresDate,
      Math.max(tx.signedDate ?? 0, renewal?.signedDate ?? 0), checkedAt, expectedOwner ?? requested.appAccountToken)
    const { error } = await admin.rpc('record_apple_subscription', record)
    if (error) throw Error('Could not save subscription')
    recorded = true
  }
  if (!recorded) throw Error('Subscription status unavailable')
}
