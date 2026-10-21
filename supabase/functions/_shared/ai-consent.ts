export type AIUse = 'pulse' | 'food'
type ConsentRow = { user_id?: string; pulse_enabled?: boolean; ai_consent_at?: string | null; food_ai_consent_at?: string | null }
type Lookup = () => PromiseLike<{ data: ConsentRow | null; error: unknown }>

// Fail closed on missing rows, missing migration, foreign rows, and failed reads.
// Only the database result under the caller's JWT is authoritative, never request context.
export async function requireAIConsent(read: Lookup, userId: string, use: AIUse) {
  let result: Awaited<ReturnType<Lookup>>
  try { result = await read() } catch { return unavailable() }
  if (result.error || (result.data && result.data.user_id !== userId)) return unavailable()
  if (use === 'pulse' && result.data?.pulse_enabled === false) {
    return { status: 403, code: 'pulse_off', error: 'Pulse is turned off. You can turn it back on in Profile.' }
  }
  const value = use === 'food' ? result.data?.food_ai_consent_at : result.data?.ai_consent_at
  if (typeof value !== 'string' || !Number.isFinite(Date.parse(value))) {
    return { status: 403, code: 'ai_consent_required', error: use === 'food'
      ? 'Allow AI food logging before parsing a meal. You can still search or add food manually.'
      : 'Review AI data sharing in Profile before using Pulse.' }
  }
  return null
}

function unavailable() {
  return { status: 503, code: 'consent_unavailable', error: 'Couldn’t verify AI permission. Please try again when you’re connected.' }
}
