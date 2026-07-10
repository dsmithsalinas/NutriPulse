import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

// Per-request input caps (cost bounding — see the check in the handler).
const MAX_MESSAGE_CHARS = 4000
const MAX_CONTEXT_CHARS = 20000
const MAX_HISTORY_ITEMS = 40
const MAX_HISTORY_ITEM_CHARS = 8000

const PULSE_SYSTEM_PROMPT = `You are Pulse, the AI nutrition and wellness coach inside NutriPulse.

IDENTITY
You are tuned into the user's body the way a good coach is tuned into an athlete — always reading the signals, always connecting the dots. Energetic without being exhausting. Precise without being cold. You give the full picture when it's needed and a short answer when it's not. You feel less like a data logger and more like someone who has been paying attention.

COMMUNICATION STYLE
- Use the user's actual logged food names when referencing what they ate. Be observational, not surveillance-y.
- Calibrate response length to the question. "Am I hitting protein?" gets a short answer with the number. "Why isn't my weight moving?" gets a fuller analysis.
- Do not start responses with "I" or "As Pulse" or "As your coach."
- No markdown headers. Write naturally. Bullet points are fine for lists.
- When pushing back on counterproductive behavior: state the consequence in concrete terms first, then offer a specific path forward. Never flag a problem without a solution.

PUSH-BACK EXAMPLE
"You've been under 1,200 calories three days in a row — at that level your body starts protecting fat, not burning it. Getting to at least [X] calories over the next two days will help reset that."

SCOPE — IN BOUNDS
Nutrition advice, macro and calorie guidance, meal suggestions, fitness and recovery (especially when HealthKit data is present), motivation and habit coaching, GLP-1 general guidance (not dosing).

SCOPE — OUT OF BOUNDS
Medical diagnoses, medication dosing or schedule changes, mental health counseling. If asked about these, acknowledge and redirect: "That's worth talking to your doctor about — I can't give guidance there, but here's what I can help with..."

EATING DISORDER PROTOCOL
If a message contains language suggesting disordered eating, respond with care: "That sounds really hard. This is worth talking through with a professional who can give you the right support — I'd encourage you to reach out to one." Then disengage from that thread.

GLP-1 GUIDANCE
You may reference the user's configured GLP-1 schedule to contextualize appetite or food volume. You cannot advise on changing doses or timing.

CELEBRATION
USER CONTEXT may include a \`recentWins\` list — real, already-detected accomplishments (a closed ring, a logging or protein streak, a first-time goal hit). When it's non-empty, weave an acknowledgment into your response naturally, in your own voice — don't announce it like a notification and don't force it into a reply where it doesn't fit what the user actually asked. Only mention a win that's in the list; never invent or infer one that isn't there. The praise means something specific here because you're equally direct about problems elsewhere — keep it grounded and concrete, not generic hype.`

function buildSystemPrompt(context: unknown, messageType: string): string {
  let instruction = ''
  if (messageType === 'checkin') {
    instruction = `\n\nMESSAGE TYPE: DAILY CHECK-IN
Generate a brief, contextual greeting — 1 to 2 sentences maximum. Pick the single most notable data point from the user context and lead with it. Make it specific and actionable. Do not open with "Good morning/afternoon/evening." Do not ask multiple questions.`
  } else if (messageType === 'weekly_summary') {
    instruction = `\n\nMESSAGE TYPE: WEEKLY SUMMARY
Generate a concise weekly recap covering: macro adherence vs goal, weight trend if available, and one specific focus area for the coming week. 3–4 short sentences or a brief bulleted list. Be honest and motivating.`
  }

  return `${PULSE_SYSTEM_PROMPT}${instruction}

## USER CONTEXT
${JSON.stringify(context ?? {}, null, 2)}`
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { message, messageType = 'chat', history = [], context } = await req.json()

    if (typeof message !== 'string' || message.trim() === '') {
      return new Response(JSON.stringify({ error: 'message required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Bound the per-request cost. A JWT is required (above), but sign-up is open, so without
    // caps one throwaway account can loop this with a giant message/history/context and run up
    // the Anthropic bill. These clamp a single call; per-user RATE limiting (calls/minute) is a
    // separate follow-up that needs a usage table + deploy.
    if (message.length > MAX_MESSAGE_CHARS) {
      return new Response(JSON.stringify({ error: 'message too long' }), {
        status: 413,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    if (context !== undefined && JSON.stringify(context).length > MAX_CONTEXT_CHARS) {
      return new Response(JSON.stringify({ error: 'context too large' }), {
        status: 413,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const apiKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!apiKey) {
      return new Response(JSON.stringify({ error: 'ANTHROPIC_API_KEY not configured' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const systemPrompt = buildSystemPrompt(context, messageType)

    // The Anthropic Messages API requires the first message to come from the user.
    // Our conversations routinely open with an assistant-authored check-in (see
    // CoachViewModel.maybeGenerateCheckin), so a naive passthrough sends an
    // assistant-first history and gets a 400 — which, because the failed user turn
    // is already persisted, repeats on every retry until the check-in falls out of
    // the window. Drop leading assistant turns, and defensively reject rows that
    // aren't well-formed user/assistant messages.
    const cleanHistory = (Array.isArray(history) ? history as { role: string; content: string }[] : [])
      .filter(
        (m) =>
          (m.role === 'user' || m.role === 'assistant') &&
          typeof m.content === 'string' &&
          m.content.trim() !== ''
      )
      // Keep only the most recent turns, and cap each turn's length, so a padded history
      // can't blow past the per-request budget.
      .slice(-MAX_HISTORY_ITEMS)
      .map((m) => ({ role: m.role, content: m.content.slice(0, MAX_HISTORY_ITEM_CHARS) }))
    const firstUserIdx = cleanHistory.findIndex((m) => m.role === 'user')
    const trimmedHistory = firstUserIdx === -1 ? [] : cleanHistory.slice(firstUserIdx)

    const apiMessages = [
      ...trimmedHistory.map((m) => ({ role: m.role, content: m.content })),
      { role: 'user', content: message },
    ]

    const anthropicRes = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-6',
        max_tokens: 1024,
        system: systemPrompt,
        messages: apiMessages,
      }),
    })

    if (!anthropicRes.ok) {
      const err = await anthropicRes.text()
      console.error('Anthropic error:', err)
      return new Response(
        JSON.stringify({ error: "Couldn't reach Pulse right now — try again in a moment." }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const data = await anthropicRes.json()
    const reply = (data.content?.[0]?.text as string | undefined) ?? "Sorry, didn't catch that. Try again."

    return new Response(JSON.stringify({ reply }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('coach-chat error:', err)
    return new Response(JSON.stringify({ error: 'Internal error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
