import { sanitizeContext, buildSystemPrompt } from '../_shared/pulse-context.ts'
import { generatePulse, selectProvider } from '../_shared/pulse-provider.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { checkRateLimit } from '../_shared/ratelimit.ts'

// Per-user cap. Covers manual chats plus the automatic check-in / weekly-summary calls, so it's
// generous — real use is a handful an hour; this only bites a script looping the endpoint.
const RATE_LIMIT_MAX = 60
const RATE_LIMIT_WINDOW_SECONDS = 3600

// Per-request input caps (cost bounding — see the check in the handler).
const MAX_MESSAGE_CHARS = 4000
const MAX_CONTEXT_CHARS = 20000
const MAX_HISTORY_ITEMS = 40
const MAX_HISTORY_ITEM_CHARS = 8000

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

    // Rate-limit before parsing/spending. Counts every authenticated call, malformed included.
    if (!await checkRateLimit(user.id, 'coach-chat', RATE_LIMIT_MAX, RATE_LIMIT_WINDOW_SECONDS)) {
      return new Response(
        JSON.stringify({ error: "You're moving fast — give me a minute to catch up and try again." }),
        { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
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

    const provider = selectProvider(Deno.env.get('PULSE_PROVIDER'))
    const apiKey = Deno.env.get(provider === 'claude' ? 'ANTHROPIC_API_KEY' : 'OPENAI_API_KEY')
    if (!apiKey) {
      return new Response(JSON.stringify({ error: 'Pulse provider not configured' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Rebuild the context from a strict allowlist before it ever reaches the prompt.
    const systemPrompt = buildSystemPrompt(sanitizeContext(context), messageType)

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

    const result = await generatePulse({ provider, apiKey, systemPrompt, messages: apiMessages,
      messageType, model: provider === 'gpt' ? Deno.env.get('PULSE_GPT_MODEL') : undefined })
    return new Response(JSON.stringify(result.output), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('coach-chat error:', err instanceof Error ? err.name : 'UnknownError')
    return new Response(JSON.stringify({ error: "Pulse couldn't finish this response. Your saved context is kept; try again." }), {
      status: 502,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
