import { scenarios, DATASET_VERSION } from '../_shared/pulse-scenarios.ts'
import { sanitizeContext, buildSystemPrompt } from '../_shared/pulse-context.ts'
import { generatePulse } from '../_shared/pulse-provider.ts'

const hits: number[] = []
export async function handleEvaluation(req: Request, env: (key: string) => string | undefined, generate = generatePulse) {
  const json = (value: unknown, status = 200) => new Response(JSON.stringify(value), { status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } })
  const secret = env('PULSE_EVAL_TOKEN')
  const expiry = Date.parse(env('PULSE_EVAL_EXPIRES_AT') ?? '')
  if (!secret || secret.length < 32 || !Number.isFinite(expiry) || Date.now() > expiry) return json({ error: 'Evaluation disabled' }, 503)
  const supplied = req.headers.get('Authorization') ?? ''
  // Compare fixed-size digests; never log credentials.
  const hash = async (s: string) => new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s)))
  const left = await hash(supplied), right = await hash(`Bearer ${secret}`)
  let mismatch = 0; for (let i = 0; i < left.length; i++) mismatch |= left[i] ^ right[i]
  if (mismatch) return json({ error: 'Unauthorized' }, 401)
  if (req.method !== 'POST') return json({ error: 'POST required' }, 405)
  const text = await req.text()
  if (text.length > 1024) return json({ error: 'Request too large' }, 413)
  let body: any; try { body = JSON.parse(text) } catch { return json({ error: 'Invalid JSON' }, 400) }
  if (!body || typeof body !== 'object' || Object.keys(body).some(k => !['scenarioId','promptHash','datasetVersion'].includes(k))) return json({ error: 'Only synthetic scenario IDs accepted' }, 400)
  const scenario = scenarios.find(s => s.id === body.scenarioId)
  if (!scenario || body.datasetVersion !== DATASET_VERSION) return json({ error: 'Unknown scenario or dataset version' }, 400)
  const systemPrompt = buildSystemPrompt(sanitizeContext(scenario.context), scenario.messageType)
  const digest = Array.from(await hash(systemPrompt)).map(b => b.toString(16).padStart(2, '0')).join('')
  if (body.promptHash !== digest) return json({ error: 'Prompt mismatch; redeploy evaluation function' }, 409)
  // A secondary per-instance throttle; token expiry is the deployment-wide cutoff.
  const now = Date.now(); while (hits.length && hits[0] < now - 60000) hits.shift()
  if (hits.length >= 6) return json({ error: 'Evaluation rate limit' }, 429)
  hits.push(now)
  try {
    const result = await generate({ provider: 'claude', apiKey: env('ANTHROPIC_API_KEY') ?? '', systemPrompt,
      messages: [{ role: 'user', content: scenario.message }], messageType: scenario.messageType })
    return json({ ...result, promptHash: digest, datasetVersion: DATASET_VERSION })
  } catch {
    return json({ error: 'Claude evaluation failed' }, 502)
  }
}
Deno.serve((req: Request) => handleEvaluation(req, key => Deno.env.get(key)))
