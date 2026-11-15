export const PREMIUM_PRODUCT = 'com.dustin.nutripulse.premium.monthly'
export function founderAccountConfirmed(user: { email_confirmed_at?: string; phone_confirmed_at?: string }) {
  return Boolean(user.email_confirmed_at || user.phone_confirmed_at)
}
export function sandboxAccountAllowed(userId: string, configured: string | undefined) {
  return (configured ?? '').split(',').map(id => id.trim().toLowerCase()).filter(Boolean).includes(userId.toLowerCase())
}
export const MEMBERSHIP_LIMITS = { pulse: 60, food: 60, global: 10000 }
type Rpc = { rpc: (name: string, args: Record<string, unknown>) => PromiseLike<{ data: unknown; error: unknown }> }

// Disabled only during coordinated rollout. Once enabled, every AI request checks
// current server entitlements, not a device boolean or user-editable metadata.
export async function requireMembership(admin: Rpc, userId: string, bucket: 'pulse' | 'food', enabled: boolean, allowSandbox = false) {
  if (!enabled) return null
  try {
    const { data, error } = await admin.rpc('reserve_membership_ai', {
      p_user_id: userId, p_bucket: bucket, p_limit: MEMBERSHIP_LIMITS[bucket], p_global_limit: MEMBERSHIP_LIMITS.global, p_allow_sandbox: allowSandbox,
    })
    if (!error && data === 'allowed') return null
    if (!error && data === 'membership_required') return { status: 402, code: data, error: 'Pulse and AI food logging are included with Footing premium. Your tracking and saved records are still available.' }
    if (!error && data === 'membership_limit_reached') return { status: 429, code: data, error: 'You’ve used this month’s AI allowance. It resets on the first of next month (UTC). Search and manual logging are still available.' }
  } catch { /* Failure cannot grant provider access. */ }
  return { status: 503, code: 'membership_unavailable', error: 'Couldn’t verify premium access right now. Try again shortly. Search and manual logging are still available.' }
}

export type AppleTransaction = {
  appAccountToken?: string; bundleId?: string; productId?: string; originalTransactionId?: string;
  transactionId?: string; expiresDate?: number; revocationDate?: number; signedDate?: number;
  environment?: string; type?: string; inAppOwnershipType?: string;
}
// Input MUST already have Apple's signature/certificate/environment verification.
export function subscriptionRecord(tx: AppleTransaction, status: number, graceUntil: number | undefined,
  signedAt: number, checkedAt: number, expectedOwner?: string) {
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
  if (tx.bundleId !== 'com.dustin.nutripulse.app' || tx.productId !== PREMIUM_PRODUCT ||
      tx.type !== 'Auto-Renewable Subscription' || tx.inAppOwnershipType !== 'PURCHASED' ||
      !uuid.test(tx.appAccountToken ?? '') || (expectedOwner && tx.appAccountToken?.toLowerCase() !== expectedOwner.toLowerCase()) ||
      !tx.originalTransactionId || !tx.transactionId || !Number.isFinite(tx.expiresDate) ||
      !Number.isFinite(signedAt) || signedAt > checkedAt + 300000 || ![1, 2, 3, 4, 5].includes(status) ||
      !['Production', 'Sandbox'].includes(tx.environment ?? '')) throw Error('Invalid subscription')
  const expires = status === 4 && Number.isFinite(graceUntil) ? graceUntil! : tx.expiresDate!
  // No grace grant without a signed grace expiration, and no access for revoked purchases.
  const effectiveStatus = status === 4 && !Number.isFinite(graceUntil) ? 3 : status
  return { p_user_id: tx.appAccountToken!.toLowerCase(), p_original: tx.originalTransactionId,
    p_environment: tx.environment!, p_product: tx.productId!, p_transaction: tx.transactionId,
    p_status: effectiveStatus, p_expires: new Date(expires).toISOString(), p_revoked: tx.revocationDate != null || status === 5,
    p_signed: new Date(signedAt).toISOString(), p_checked: new Date(checkedAt).toISOString() }
}
