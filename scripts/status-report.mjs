// Daily status report — health checks + aggregate usage stats, printed as markdown.
// Run each morning by a scheduled Claude Code routine that posts the output into
// the session conversation (see docs/status-report.md), or manually:
//
//   cd scripts && npm install && \
//   SUPABASE_URL=... SUPABASE_ANON_KEY=... SUPABASE_SERVICE_ROLE_KEY=... \
//   HEALTHCHECK_EMAIL=... HEALTHCHECK_PASSWORD=... \
//   node status-report.mjs
//
// Exit code is non-zero when any health check fails, so whatever runs this can
// tell a broken morning from a green one without parsing the output.

import { createClient } from '@supabase/supabase-js'

// ── Config ──────────────────────────────────────────────────────────────────
const env = (name, fallback) => {
  const v = process.env[name] ?? fallback
  if (v === undefined) {
    console.error(`Missing required env var: ${name}`)
    process.exit(1)
  }
  return v
}

const SUPABASE_URL     = env('SUPABASE_URL').replace(/\/$/, '')
const ANON_KEY         = env('SUPABASE_ANON_KEY')
const SERVICE_ROLE_KEY = env('SUPABASE_SERVICE_ROLE_KEY')
const HC_EMAIL         = env('HEALTHCHECK_EMAIL')
const HC_PASSWORD      = env('HEALTHCHECK_PASSWORD')
const REPORT_TZ        = env('REPORT_TZ', 'America/Los_Angeles')

// ── Health checks ───────────────────────────────────────────────────────────
const checks = []

async function check(name, fn) {
  const started = Date.now()
  try {
    const detail = await fn()
    checks.push({ name, ok: true, detail: detail ?? 'ok', ms: Date.now() - started })
  } catch (err) {
    checks.push({ name, ok: false, detail: err.message ?? String(err), ms: Date.now() - started })
  }
}

async function invokeFunction(name, token, body) {
  const res = await fetch(`${SUPABASE_URL}/functions/v1/${name}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      apikey: ANON_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  })
  const text = await res.text()
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${text.slice(0, 300)}`)
  try {
    return JSON.parse(text)
  } catch {
    throw new Error(`non-JSON response: ${text.slice(0, 300)}`)
  }
}

async function runHealthChecks() {
  // 1. Auth service up at all?
  await check('Auth service', async () => {
    const res = await fetch(`${SUPABASE_URL}/auth/v1/health`, { headers: { apikey: ANON_KEY } })
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    return 'reachable'
  })

  // 2. Database reachable through PostgREST?
  const service = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } })
  await check('Database (REST)', async () => {
    const { count, error } = await service
      .from('profiles')
      .select('id', { count: 'exact', head: true })
    if (error) throw new Error(error.message)
    return `profiles reachable (${count} rows)`
  })

  // 3. Real sign-in with the dedicated healthcheck account — catches JWT/RLS
  //    regressions that anonymous pings can't. Token feeds the function checks.
  let token = null
  await check('Sign-in (healthcheck account)', async () => {
    const anon = createClient(SUPABASE_URL, ANON_KEY, { auth: { persistSession: false } })
    const { data, error } = await anon.auth.signInWithPassword({
      email: HC_EMAIL,
      password: HC_PASSWORD,
    })
    if (error) throw new Error(error.message)
    token = data.session.access_token
    return 'authenticated'
  })

  // 4–6. Edge Functions, end to end. search-food + get-food exercise the
  // FatSecret credentials; coach-chat exercises the Anthropic key. Each is one
  // real round-trip a day — the coach-chat ping costs a few tokens, by design.
  let foodId = null
  await check('search-food (FatSecret)', async () => {
    if (!token) throw new Error('skipped: sign-in failed')
    const json = await invokeFunction('search-food', token, { query: 'apple', maxResults: 3 })
    if (!Array.isArray(json.results) || json.results.length === 0) {
      throw new Error('no results for "apple"')
    }
    foodId = json.results[0].id
    return `${json.results.length} results`
  })

  await check('get-food (FatSecret)', async () => {
    if (!foodId) throw new Error('skipped: search-food failed')
    const json = await invokeFunction('get-food', token, { foodId })
    if (!json.name) throw new Error(`unexpected response: ${JSON.stringify(json).slice(0, 200)}`)
    return `resolved "${json.name}"`
  })

  await check('coach-chat (Claude round-trip)', async () => {
    if (!token) throw new Error('skipped: sign-in failed')
    const json = await invokeFunction('coach-chat', token, {
      message: 'Automated daily health check — reply with one short sentence.',
    })
    if (typeof json.reply !== 'string' || json.reply.trim() === '') {
      throw new Error(`no reply: ${JSON.stringify(json).slice(0, 200)}`)
    }
    return 'Pulse replied'
  })

  return service
}

// ── Stats ───────────────────────────────────────────────────────────────────
async function fetchStats(service) {
  const { data, error } = await service.rpc('get_daily_status', { p_tz: REPORT_TZ })
  if (error) throw new Error(error.message)
  return data
}

// ── Formatting (markdown) ───────────────────────────────────────────────────
const fmtDay = (iso) =>
  new Date(`${iso}T12:00:00Z`).toLocaleDateString('en-US', {
    weekday: 'short', month: 'short', day: 'numeric', timeZone: 'UTC',
  })

function buildReport(stats, statsError) {
  const failures = checks.filter((c) => !c.ok)
  const allGreen = failures.length === 0 && !statsError
  const dayLabel = stats ? fmtDay(stats.report_date) : new Date().toLocaleDateString('en-US', {
    weekday: 'short', month: 'short', day: 'numeric', timeZone: REPORT_TZ,
  })

  const lines = []
  lines.push(allGreen
    ? `# ✅ NutriPulse daily status — all systems go (${dayLabel})`
    : `# ⚠️ NutriPulse daily status — ${failures.length || 'stats'} check${failures.length === 1 ? '' : 's'} failing (${dayLabel})`)
  lines.push('')
  lines.push('## Health checks')
  for (const c of checks) {
    lines.push(`- ${c.ok ? '✅' : '❌'} **${c.name}** — ${c.detail} (${c.ms}ms)`)
  }

  if (statsError) {
    lines.push('', `## Stats`, `Unavailable: ${statsError}`)
    return { allGreen, text: lines.join('\n') }
  }

  const { users, activity, coach } = stats
  lines.push('', `## Users`)
  lines.push(`- Total: **${users.total}** (+${users.new_yesterday} yesterday, +${users.new_last_7d} last 7 days)`)

  lines.push('', `## Activity — ${fmtDay(stats.report_date)}`)
  lines.push(`- Active users (logged food): **${activity.active_users_yesterday}**`)
  lines.push(`- Food logs: ${activity.food_logs_yesterday} · Water: ${activity.water_logs_yesterday} · Weight: ${activity.weight_logs_yesterday} · Workouts: ${activity.workout_logs_yesterday}`)
  lines.push(`- GLP-1 shots: ${activity.glp1_shots_yesterday} · Body measurements: ${activity.body_measurements_yesterday}`)
  lines.push(`- Pulse: ${coach.messages_yesterday} messages from ${coach.users_chatting_yesterday} user${coach.users_chatting_yesterday === 1 ? '' : 's'}`)

  const hot = stats.rate_limit_hot ?? []
  if (hot.length > 0) {
    lines.push('', `⚠️ **Rate limits running hot since yesterday:** ${hot.map((r) => `${r.bucket} (${r.count} calls)`).join(', ')}`)
  }

  lines.push('', '## 7-day trend (active users / food logs)')
  lines.push('| day | active | food logs |', '|---|---|---|')
  for (const d of stats.trend_7d ?? []) {
    lines.push(`| ${fmtDay(d.date)} | ${d.active_users} | ${d.food_logs} |`)
  }

  const feedback = stats.feedback_new ?? []
  lines.push('', '## Feedback since yesterday')
  if (feedback.length === 0) {
    lines.push('None.')
  } else {
    for (const f of feedback) {
      const when = new Date(f.created_at).toLocaleString('en-US', { timeZone: REPORT_TZ })
      lines.push(`- **[${f.category}]**${f.app_version ? ` v${f.app_version}` : ''} (${when}): ${f.message}`)
    }
  }

  return { allGreen, text: lines.join('\n') }
}

// ── Main ────────────────────────────────────────────────────────────────────
const service = await runHealthChecks()

let stats = null
let statsError = null
try {
  stats = await fetchStats(service)
} catch (err) {
  statsError = err.message ?? String(err)
}

const report = buildReport(stats, statsError)
console.log(report.text)

const failed = checks.some((c) => !c.ok) || statsError !== null
process.exit(failed ? 1 : 0)
