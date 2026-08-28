import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.0'

const EXPECTED_TOKEN_HASH = 'ff2600531d917bd094c2e96acb7e6886735be6a9a2dbe3937351a6b4e10ef44b'
const DAY = 86_400_000

Deno.serve(async (request) => {
  if (request.method !== 'GET') return Response.json({ error: 'method_not_allowed' }, { status: 405 })
  if (!(await tokenMatches(request.headers.get('x-labs-token') ?? ''))) return Response.json({ error: 'unauthorized' }, { status: 401 })

  const started = Date.now()
  try {
    const admin = createAdminClient()
    const now = new Date()
    const since7d = new Date(now.getTime() - 7 * DAY).toISOString()
    const since28d = new Date(now.getTime() - 28 * DAY).toISOString()
    const [users, foodLogs, coachMessages, feedback] = await Promise.all([
      loadUsers(admin),
      loadRows(admin, 'food_logs', 'user_id,log_date,created_at', since28d),
      loadRows(admin, 'coach_messages', 'user_id,role,created_at', since7d),
      loadRows(admin, 'feedback', 'user_id,created_at', since7d),
    ])
    const currentLogs = foodLogs.filter((row) => row.created_at >= since7d)
    const activeLoggers = unique(currentLogs.map((row) => row.user_id))
    const daysByUser = new Map<string, Set<string>>()
    for (const row of currentLogs) {
      const days = daysByUser.get(row.user_id) ?? new Set<string>()
      days.add(row.log_date)
      daysByUser.set(row.user_id, days)
    }
    const consistentLoggers = [...daysByUser.values()].filter((days) => days.size >= 3).length
    const newUsers7d = users.filter((user) => user.created_at >= since7d)
    const eligible28d = users.filter((user) => user.created_at >= since28d)
    const activated7d = newUsers7d.filter((user) => activeLoggers.has(user.id)).length
    const loggedUsers28d = unique(foodLogs.map((row) => row.user_id))
    const activated28d = eligible28d.filter((user) => loggedUsers28d.has(user.id)).length
    const userCoachMessages = coachMessages.filter((row) => row.role === 'user')
    const assistantCoachMessages = coachMessages.filter((row) => row.role === 'assistant')

    return Response.json({
      schemaVersion: 1,
      product: 'footing',
      capturedAt: now.toISOString(),
      health: { status: 'healthy', latencyMs: Date.now() - started },
      users: { total: users.length, new7d: newUsers7d.length, active7d: activeLoggers.size },
      activation: { activated7d, eligible28d: eligible28d.length, activated28d },
      productMetrics: {
        weeklyActiveLoggers: activeLoggers.size,
        weeklyConsistentLoggers: consistentLoggers,
        newUsers7d: newUsers7d.length,
        activatedUsers7d: activated7d,
        userActivationRate28d: ratio(activated28d, eligible28d.length),
        loggingDays7d: [...daysByUser.values()].reduce((sum, days) => sum + days.size, 0),
        coachEngagedUsers7d: unique(userCoachMessages.map((row) => row.user_id)).size,
        feedbackSubmissions7d: feedback.length,
      },
      ai: { requests7d: assistantCoachMessages.length, errors7d: Math.max(0, userCoachMessages.length - assistantCoachMessages.length) },
    }, { headers: { 'Cache-Control': 'no-store' } })
  } catch (error) {
    console.error(JSON.stringify({ service: 'labs-metrics', event: 'collection_failed', error: error instanceof Error ? error.message : 'unknown' }))
    return Response.json({ error: 'collection_failed' }, { status: 500 })
  }
})

function createAdminClient() {
  const secretKeys = Deno.env.get('SUPABASE_SECRET_KEYS')
  const secretKey = secretKeys ? JSON.parse(secretKeys).default : Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  return createClient(Deno.env.get('SUPABASE_URL')!, secretKey!, { auth: { persistSession: false, autoRefreshToken: false } })
}
async function loadUsers(admin: ReturnType<typeof createAdminClient>) {
  const users: Array<{ id: string; created_at: string }> = []
  for (let page = 1; page <= 20; page += 1) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 1000 })
    if (error) throw error
    users.push(...data.users.map((user) => ({ id: user.id, created_at: user.created_at })))
    if (data.users.length < 1000) break
  }
  return users
}
async function loadRows(admin: ReturnType<typeof createAdminClient>, table: string, columns: string, since: string): Promise<any[]> {
  const rows: any[] = []
  for (let start = 0; start < 20_000; start += 1000) {
    const { data, error } = await admin.from(table).select(columns).gte('created_at', since).range(start, start + 999)
    if (error) throw error
    rows.push(...(data ?? []))
    if (!data || data.length < 1000) break
  }
  return rows
}
function unique(values: string[]) { return new Set(values.filter(Boolean)) }
function ratio(numerator: number, denominator: number) { return denominator ? numerator / denominator : 0 }
async function tokenMatches(token: string): Promise<boolean> {
  if (!token) return false
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(token))
  const actual = [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('')
  let difference = actual.length ^ EXPECTED_TOKEN_HASH.length
  for (let index = 0; index < actual.length; index += 1) difference |= actual.charCodeAt(index) ^ EXPECTED_TOKEN_HASH.charCodeAt(index)
  return difference === 0
}
