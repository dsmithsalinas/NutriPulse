// Daily status report — health checks + aggregate usage stats, emailed each morning.
// Run by .github/workflows/status-report.yml (cron) or manually:
//
//   cd scripts && npm install && \
//   SUPABASE_URL=... SUPABASE_ANON_KEY=... SUPABASE_SERVICE_ROLE_KEY=... \
//   HEALTHCHECK_EMAIL=... HEALTHCHECK_PASSWORD=... RESEND_API_KEY=... \
//   node status-report.mjs
//
// Setup, secrets, and design notes: docs/status-report.md
//
// Exit code is non-zero when any health check fails (or the email can't send),
// so the GitHub Actions run fails and GitHub's own notification becomes a
// second alert channel even if the report email never goes out.

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
const RESEND_API_KEY   = process.env.RESEND_API_KEY // optional: no key -> stdout only
const REPORT_TO        = env('REPORT_TO', 'dusteallen@me.com')
const REPORT_FROM      = env('REPORT_FROM', 'NutriPulse Status <onboarding@resend.dev>')
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

// ── Formatting ──────────────────────────────────────────────────────────────
const escapeHtml = (s) =>
  String(s).replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]))

const fmtDay = (iso) =>
  new Date(`${iso}T12:00:00Z`).toLocaleDateString('en-US', {
    weekday: 'short', month: 'short', day: 'numeric', timeZone: 'UTC',
  })

function buildEmail(stats, statsError) {
  const failures = checks.filter((c) => !c.ok)
  const allGreen = failures.length === 0 && !statsError
  const dayLabel = stats ? fmtDay(stats.report_date) : new Date().toLocaleDateString('en-US', {
    weekday: 'short', month: 'short', day: 'numeric', timeZone: REPORT_TZ,
  })

  const subject = allGreen
    ? `NutriPulse ✅ all systems go — ${dayLabel}`
    : `NutriPulse ⚠️ ${failures.length || 'stats'} check${failures.length === 1 ? '' : 's'} failing — ${dayLabel}`

  const row = (label, value) =>
    `<tr><td style="padding:4px 12px 4px 0;color:#555">${label}</td>` +
    `<td style="padding:4px 0;font-weight:600">${value}</td></tr>`

  const checkRows = checks.map((c) =>
    `<tr><td style="padding:4px 8px 4px 0">${c.ok ? '✅' : '❌'}</td>` +
    `<td style="padding:4px 12px 4px 0">${escapeHtml(c.name)}</td>` +
    `<td style="padding:4px 12px 4px 0;color:#555">${escapeHtml(c.detail)}</td>` +
    `<td style="padding:4px 0;color:#999;text-align:right">${c.ms}ms</td></tr>`
  ).join('')

  let statsHtml
  if (statsError) {
    statsHtml = `<p style="color:#b91c1c"><strong>Stats unavailable:</strong> ${escapeHtml(statsError)}</p>`
  } else {
    const { users, activity, coach } = stats
    const trend = (stats.trend_7d ?? []).map((d) =>
      `<tr><td style="padding:2px 12px 2px 0;color:#555">${fmtDay(d.date)}</td>` +
      `<td style="padding:2px 12px 2px 0;text-align:right">${d.active_users}</td>` +
      `<td style="padding:2px 0;text-align:right">${d.food_logs}</td></tr>`
    ).join('')

    const rateLimitHot = (stats.rate_limit_hot ?? [])
    const rateLimitHtml = rateLimitHot.length === 0 ? '' :
      `<p style="color:#b45309">⚠️ Running hot since yesterday: ${
        rateLimitHot.map((r) => `<strong>${escapeHtml(r.bucket)}</strong> (${r.count} calls in window)`).join(', ')
      }</p>`

    const feedback = (stats.feedback_new ?? [])
    const feedbackHtml = feedback.length === 0
      ? '<p style="color:#555">No new feedback.</p>'
      : feedback.map((f) =>
          `<div style="border-left:3px solid #8B5CF6;padding:6px 12px;margin:8px 0;background:#faf8ff">` +
          `<div style="font-size:12px;color:#777;margin-bottom:2px">` +
          `${escapeHtml(f.category)}${f.app_version ? ` · v${escapeHtml(f.app_version)}` : ''} · ${escapeHtml(new Date(f.created_at).toLocaleString('en-US', { timeZone: REPORT_TZ }))}` +
          `</div><div>${escapeHtml(f.message)}</div></div>`
        ).join('')

    statsHtml = `
      <h3 style="margin:20px 0 6px">Users</h3>
      <table style="border-collapse:collapse">
        ${row('Total users', users.total)}
        ${row('New yesterday', users.new_yesterday)}
        ${row('New last 7 days', users.new_last_7d)}
      </table>

      <h3 style="margin:20px 0 6px">Activity — ${fmtDay(stats.report_date)}</h3>
      <table style="border-collapse:collapse">
        ${row('Active users (logged food)', activity.active_users_yesterday)}
        ${row('Food logs', activity.food_logs_yesterday)}
        ${row('Water logs', activity.water_logs_yesterday)}
        ${row('Weight logs', activity.weight_logs_yesterday)}
        ${row('Workouts', activity.workout_logs_yesterday)}
        ${row('GLP-1 shots', activity.glp1_shots_yesterday)}
        ${row('Body measurements', activity.body_measurements_yesterday)}
        ${row('Pulse messages (user turns)', coach.messages_yesterday)}
        ${row('Users chatting with Pulse', coach.users_chatting_yesterday)}
      </table>
      ${rateLimitHtml}

      <h3 style="margin:20px 0 6px">7-day trend</h3>
      <table style="border-collapse:collapse">
        <tr><td style="padding:2px 12px 2px 0;color:#999">day</td>
            <td style="padding:2px 12px 2px 0;color:#999;text-align:right">active</td>
            <td style="padding:2px 0;color:#999;text-align:right">food logs</td></tr>
        ${trend}
      </table>

      <h3 style="margin:20px 0 6px">Feedback since yesterday</h3>
      ${feedbackHtml}`
  }

  const html = `
    <div style="font-family:-apple-system,Segoe UI,sans-serif;max-width:640px;color:#1a1a1a">
      <h2 style="margin:0 0 4px">${allGreen ? '✅' : '⚠️'} NutriPulse daily status</h2>
      <p style="margin:0 0 16px;color:#777">${dayLabel} · ${escapeHtml(REPORT_TZ)}</p>
      <h3 style="margin:20px 0 6px">Health checks</h3>
      <table style="border-collapse:collapse">${checkRows}</table>
      ${statsHtml}
    </div>`

  const text = [
    `NutriPulse daily status — ${dayLabel}`,
    '',
    'Health checks:',
    ...checks.map((c) => `  ${c.ok ? 'OK  ' : 'FAIL'} ${c.name} — ${c.detail} (${c.ms}ms)`),
    '',
    statsError ? `Stats unavailable: ${statsError}` : JSON.stringify(stats, null, 2),
  ].join('\n')

  return { subject, html, text }
}

// ── Send ────────────────────────────────────────────────────────────────────
async function sendEmail({ subject, html, text }) {
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ from: REPORT_FROM, to: [REPORT_TO], subject, html, text }),
  })
  if (!res.ok) throw new Error(`Resend HTTP ${res.status}: ${(await res.text()).slice(0, 300)}`)
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

const email = buildEmail(stats, statsError)
console.log(email.text)

let sendFailed = false
if (RESEND_API_KEY) {
  try {
    await sendEmail(email)
    console.log(`\nReport emailed to ${REPORT_TO}`)
  } catch (err) {
    sendFailed = true
    console.error(`\nFailed to send report email: ${err.message}`)
  }
} else {
  console.log('\nRESEND_API_KEY not set — printed report only, no email sent.')
}

const failed = checks.some((c) => !c.ok) || statsError !== null || sendFailed
process.exit(failed ? 1 : 0)
