import { sanitizeContext, buildSystemBlocks } from '../_shared/pulse-context.ts'
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

// The Messages API requires the first message to come from the user, but Pulse's check-ins and
// recaps are assistant-authored and usually open the conversation. Those leading assistant turns
// used to be dropped outright — and for anyone who mostly reads check-ins rather than chatting,
// that was the ENTIRE history, so every check-in was written blind to the last one. That is
// the main reason Pulse kept repeating itself. Keep them, but move them into the system prompt.
const MAX_RECENT_PULSE_MESSAGES = 6
const MAX_RECENT_PULSE_MESSAGE_CHARS = 600

function splitHistory(history: { role: string; content: string }[]) {
  const firstUserIdx = history.findIndex((m) => m.role === 'user')
  const leading = firstUserIdx === -1 ? history : history.slice(0, firstUserIdx)
  return {
    conversation: firstUserIdx === -1 ? [] : history.slice(firstUserIdx),
    recentPulseMessages: leading
      .filter((m) => m.role === 'assistant')
      .slice(-MAX_RECENT_PULSE_MESSAGES)
      .map((m) => m.content.slice(0, MAX_RECENT_PULSE_MESSAGE_CHARS)),
  }
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

    // Defensively reject rows that aren't well-formed user/assistant messages.
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
    // The API 400s on an assistant-first conversation, and ours routinely open with a
    // check-in. See splitHistory: those turns move into the system prompt instead.
    const { conversation, recentPulseMessages } = splitHistory(cleanHistory)

    // Rebuild the context from a strict allowlist before it ever reaches the prompt.
    const systemPrompt = buildSystemBlocks(sanitizeContext(context), messageType, recentPulseMessages)

    const apiMessages = [
      ...conversation.map((m) => ({ role: m.role, content: m.content })),
      { role: 'user', content: message },
    ]

    // PULSE_MODEL overrides the chat model (a secret update, not a redeploy). The Strong Week
    // outlook ignores it and keeps its tested model; see DEFAULT_MODELS in pulse-provider.ts.
    const model = provider === 'gpt'
      ? Deno.env.get('PULSE_GPT_MODEL')
      : messageType === 'weekly_outlook' ? undefined : Deno.env.get('PULSE_MODEL')
    const result = await generatePulse({ provider, apiKey, systemPrompt, messages: apiMessages, messageType, model })
    // Usage only, never content. console.log is absent in the contract-test sandbox.
    console.log?.('coach-chat usage', JSON.stringify({ messageType, ...result.metadata }))
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
