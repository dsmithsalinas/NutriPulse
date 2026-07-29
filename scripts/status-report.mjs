// Daily status report — health checks + aggregate usage stats, printed as markdown.
// Run each morning by a scheduled Codex task that posts the output into its task
// (see docs/status-report.md), or manually:
//
//   set -a && source .env.status-report && set +a
//   node scripts/status-report.mjs
//
// Exit codes:
//   0 = healthy
//   1 = Footing is reachable, but one or more production checks failed
//   2 = the report runner itself was not configured or could not reach Footing

// Unattended job: every network call gets a hard timeout so a hung connection
// fails the check cleanly instead of stalling the whole run.
const FETCH_TIMEOUT_MS = 30_000
const tfetch = (url, opts = {}) =>
  fetch(url, { ...opts, signal: opts.signal ?? AbortSignal.timeout(FETCH_TIMEOUT_MS) })

// ── Config ──────────────────────────────────────────────────────────────────
const REQUIRED_ENV = [
  'SUPABASE_URL',
  'SUPABASE_ANON_KEY',
  'SUPABASE_SERVICE_ROLE_KEY',
  'HEALTHCHECK_EMAIL',
  'HEALTHCHECK_PASSWORD',
]

const missingEnv = REQUIRED_ENV.filter((name) => !process.env[name]?.trim())
if (missingEnv.length > 0) {
  console.log([
    '# ⚪ Footing daily status — couldn’t run',
    '',
    'The report runner is missing required private settings. This does not mean Footing is down.',
    '',
    `Missing: ${missingEnv.map((name) => `\`${name}\``).join(', ')}`,
    '',
    'Add them to the runner’s private environment, then run the report again.',
  ].join('\n'))
  process.exit(2)
}

const SUPABASE_URL     = process.env.SUPABASE_URL.replace(/\/$/, '')
const ANON_KEY         = process.env.SUPABASE_ANON_KEY
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY
const HC_EMAIL         = process.env.HEALTHCHECK_EMAIL
const HC_PASSWORD      = process.env.HEALTHCHECK_PASSWORD
const REPORT_TZ        = process.env.REPORT_TZ || 'America/Los_Angeles'

try {
  new URL(SUPABASE_URL)
} catch {
  console.log([
    '# ⚪ Footing daily status — couldn’t run',
    '',
    '`SUPABASE_URL` is not a valid URL. This is a runner setup problem, not a Footing outage.',
  ].join('\n'))
  process.exit(2)
}

// ── Egress preflight ────────────────────────────────────────────────────────
// Sandboxed runners route traffic through a proxy that 403s hosts missing from
// the environment's network allowlist. That
// failure mode means "the checks could not run" — NOT "production is down" —
// so detect it up front and report it as its own thing instead of six red ❌s.
async function detectEgressBlock() {
  try {
    const res = await tfetch(`${SUPABASE_URL}/auth/v1/health`, { headers: { apikey: ANON_KEY } })
    if (res.status === 403) {
      const text = await res.text()
      if (/not in allowlist|network egress/i.test(text)) return text.trim().slice(0, 300)
    }
  } catch {
    // Unreachable for other reasons — let the real checks report it.
  }
  return null
}

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
  const res = await tfetch(`${SUPABASE_URL}/functions/v1/${name}`, {
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

async function parseJsonResponse(res) {
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
    const res = await tfetch(`${SUPABASE_URL}/auth/v1/health`, { headers: { apikey: ANON_KEY } })
    if (!res.ok) throw new Error(`HTTP ${res.status}: ${(await res.text()).slice(0, 200)}`)
    return 'reachable'
  })

  // 2. Database reachable through PostgREST?
  await check('Database (REST)', async () => {
    const res = await tfetch(`${SUPABASE_URL}/rest/v1/profiles?select=id`, {
      method: 'HEAD',
      headers: {
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
        Prefer: 'count=exact',
      },
    })
    if (!res.ok) throw new Error(`HTTP ${res.status}: ${(await res.text()).slice(0, 300)}`)
    const count = res.headers.get('content-range')?.split('/').at(-1)
    return count && count !== '*' ? `profiles reachable (${count} rows)` : 'profiles reachable'
  })

  // 3. Real sign-in with the dedicated healthcheck account — catches JWT/RLS
  //    regressions that anonymous pings can't. Token feeds the function checks.
  let token = null
  await check('Sign-in (healthcheck account)', async () => {
    const res = await tfetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
      method: 'POST',
      headers: {
        apikey: ANON_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ email: HC_EMAIL, password: HC_PASSWORD }),
    })
    const data = await parseJsonResponse(res)
    token = data.access_token
    if (!token) throw new Error('sign-in returned no access token')
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

}

// ── Stats ───────────────────────────────────────────────────────────────────
async function fetchStats() {
  const res = await tfetch(`${SUPABASE_URL}/rest/v1/rpc/get_daily_status`, {
    method: 'POST',
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ p_tz: REPORT_TZ }),
  })
  return parseJsonResponse(res)
}

// ── Formatting (markdown) ───────────────────────────────────────────────────
const fmtDay = (iso) =>
  new Date(`${iso}T12:00:00Z`).toLocaleDateString('en-US', {
    weekday: 'short', month: 'short', day: 'numeric', timeZone: 'UTC',
  })

function buildReport(stats, statsError, runnerUnable) {
  const failures = checks.filter((c) => !c.ok)
  const allGreen = failures.length === 0 && !statsError && !runnerUnable
  const dayLabel = stats ? fmtDay(stats.report_date) : new Date().toLocaleDateString('en-US', {
    weekday: 'short', month: 'short', day: 'numeric', timeZone: REPORT_TZ,
  })

  const lines = []
  lines.push(runnerUnable
    ? `# ⚪ Footing daily status — couldn’t run (${dayLabel})`
    : allGreen
      ? `# ✅ Footing daily status — Healthy (${dayLabel})`
      : `# ⚠️ Footing daily status — Action needed (${dayLabel})`)
  if (runnerUnable) {
    lines.push('', 'The runner could not reach Footing reliably, so this is not evidence that production is down.')
  }
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
      lines.push(`- **${f.category}**: ${f.count ?? 1}`)
    }
  }

  return { allGreen, text: lines.join('\n') }
}

// ── Main ────────────────────────────────────────────────────────────────────
const egressBlock = await detectEgressBlock()
if (egressBlock) {
  const host = new URL(SUPABASE_URL).host
  console.log([
    '# 🚧 Footing daily status — checks could not run',
    '',
    `The runner's network policy blocked access to \`${host}\`, so nothing was`,
    'actually tested. **Production status is unknown** — this is a runner',
    'configuration problem, not a Footing outage.',
    '',
    `> ${egressBlock}`,
    '',
    `Fix: add \`${host}\` to the environment's allowed domains`,
    '(see docs/status-report.md), then re-run.',
  ].join('\n'))
  process.exit(2)
}

await runHealthChecks()

let stats = null
let statsError = null
try {
  stats = await fetchStats()
} catch (err) {
  statsError = err.message ?? String(err)
}

const runnerErrorPattern = /blocked host|not allowlisted|fetch failed|ENOTFOUND|EAI_AGAIN|ECONNREFUSED|network/i
const foundationChecks = checks.slice(0, 3)
const runnerUnable =
  foundationChecks.length === 3 &&
  foundationChecks.every((c) => !c.ok) &&
  foundationChecks.some((c) => runnerErrorPattern.test(c.detail))

const report = buildReport(stats, statsError, runnerUnable)
console.log(report.text)

const failed = checks.some((c) => !c.ok) || statsError !== null
process.exit(runnerUnable ? 2 : failed ? 1 : 0)
