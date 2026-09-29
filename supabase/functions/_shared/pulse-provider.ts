import { parseStrongWeekOutlook, strongWeekTool, type SystemBlock } from './pulse-context.ts'

export type Provider = 'claude' | 'gpt'
export function selectProvider(value?: string): Provider {
  if (!value || value === 'claude') return 'claude'
  if (value === 'gpt') return 'gpt'
  throw new Error('Invalid Pulse provider')
}

// Explicit settings are recorded with every evaluation. No silent model fallback.
// DEFAULT_MODELS.claude is the Strong Week outlook model: that request forces a tool call,
// which Sonnet 5.5 rejects (400), so it stays on Sonnet 4.6 until it moves to structured
// outputs. Chat, check-ins, and summaries use DEFAULT_CLAUDE_CHAT_MODEL.
export const DEFAULT_MODELS = { claude: 'claude-sonnet-4-6', gpt: 'gpt-5.6-terra' }
export const DEFAULT_CLAUDE_CHAT_MODEL = 'claude-sonnet-5-5'

// Low effort for conversational turns: the model skips thinking on most simple replies, keeping
// latency close to the old thinking-off behavior. The weekly summary runs once a week and has to
// find patterns across seven days, so it gets more room to reason.
export function effortFor(messageType: string): 'low' | 'medium' {
  return messageType === 'weekly_summary' ? 'medium' : 'low'
}

// In chat, a safety-classifier decline gets the same redirect Pulse uses for anything outside
// its lane. Check-ins and summaries fail instead: an unrequested boundary message reads as broken.
export const REFUSAL_REPLY = "That one's outside what I can help with here — your doctor or pharmacist is the right person for it. I can help with food, protein, movement, and building the habits around your plan."
export async function generatePulse(options: {
  provider: Provider; apiKey: string; systemPrompt: string | SystemBlock[];
  messages: { role: string; content: string }[]; messageType: string; model?: string;
}, transport: typeof fetch = fetch) {
  const { provider, apiKey, systemPrompt, messages, messageType } = options
  if (!apiKey) throw new Error('Missing provider key')
  const weekly = messageType === 'weekly_outlook'
  const model = options.model || (provider === 'claude' && !weekly ? DEFAULT_CLAUDE_CHAT_MODEL : DEFAULT_MODELS[provider])
  const instructions = typeof systemPrompt === 'string' ? systemPrompt : systemPrompt.map((block) => block.text).join('\n\n')
  const effort = effortFor(messageType)
  const body = provider === 'claude' ? (weekly ? {
    model, max_tokens: 1024, system: systemPrompt, messages,
    tools: [strongWeekTool], tool_choice: { type: 'tool', name: strongWeekTool.name },
  } : {
    // Headroom for adaptive thinking, which counts toward max_tokens on Sonnet 5.x. Replies
    // themselves stay short; the prompt calibrates length, not this cap.
    model, max_tokens: 4096, system: systemPrompt, messages, output_config: { effort },
  }) : {
    model, store: false, instructions, input: messages,
    max_output_tokens: 4096, reasoning: { effort: 'low' },
    ...(weekly ? { tools: [{ type: 'function', name: strongWeekTool.name,
      description: strongWeekTool.description, parameters: strongWeekTool.input_schema, strict: true }],
      tool_choice: { type: 'function', name: strongWeekTool.name }, parallel_tool_calls: false } : {}),
  }
  const started = performance.now()
  const response = await transport(provider === 'claude' ? 'https://api.anthropic.com/v1/messages' : 'https://api.openai.com/v1/responses', {
    method: 'POST', signal: AbortSignal.timeout(60000),
    headers: provider === 'claude'
      ? { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' }
      : { Authorization: `Bearer ${apiKey}`, 'content-type': 'application/json' },
    body: JSON.stringify(body),
  })
  // Provider bodies may echo sensitive input; never log or return them.
  if (!response.ok) throw new Error(`Provider HTTP ${response.status}`)
  const data = await response.json()
  let output: { outlook?: Record<string, string>; reply?: string }
  if (weekly) {
    let calls = data.content
    if (provider === 'gpt') {
      if (data.status !== 'completed') throw new Error('Incomplete model response')
      calls = (data.output ?? []).filter((item: any) => item.type === 'function_call').map((item: any) => ({
        type: 'tool_use', name: item.name, input: JSON.parse(item.arguments),
      }))
    } else if (data.stop_reason !== 'tool_use') throw new Error('Incomplete model response')
    const outlook = parseStrongWeekOutlook(calls)
    if (!outlook) throw new Error('Invalid weekly outlook')
    output = { outlook }
  } else if (provider === 'claude' && data.stop_reason === 'refusal') {
    if (messageType !== 'chat') throw new Error('Model declined')
    output = { reply: REFUSAL_REPLY }
  } else {
    if (provider === 'claude' ? data.stop_reason !== 'end_turn' : data.status !== 'completed') throw new Error('Incomplete model response')
    const content = provider === 'claude' ? data.content : (data.output ?? []).filter((x: any) => x.type === 'message').flatMap((x: any) => x.content ?? [])
    const reply = (content ?? []).filter((x: any) => ['text', 'output_text'].includes(x.type)).map((x: any) => x.text).join('\n').trim()
    if (!reply) throw new Error('Empty model response')
    output = { reply }
  }
  const u = data.usage ?? {}
  return { output, metadata: { provider, requestedModel: model, returnedModel: data.model ?? model,
    latencyMs: Math.round(performance.now() - started), inputTokens: u.input_tokens ?? null,
    outputTokens: u.output_tokens ?? null, cachedInputTokens: provider === 'gpt' ? u.input_tokens_details?.cached_tokens ?? 0 : u.cache_read_input_tokens ?? 0,
    cacheCreationTokens: u.cache_creation_input_tokens ?? 0,
    reasoningTokens: u.output_tokens_details?.reasoning_tokens ?? null,
    stopReason: data.stop_reason ?? data.status ?? null,
    settings: provider === 'gpt' ? { maxOutputTokens: 4096, reasoningEffort: 'low' }
      : weekly ? { maxOutputTokens: 1024 } : { maxOutputTokens: 4096, effort },
  } }
}
