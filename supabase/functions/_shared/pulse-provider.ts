import { type PulseGuard, type PulseReply, parsePulseReply, parseStrongWeekFields, parseStrongWeekOutlook, pulseSchemaFor, strongWeekTool, type SystemBlock } from './pulse-context.ts'

export type Provider = 'claude' | 'gpt'
export function selectProvider(value?: string): Provider {
  if (!value || value === 'claude') return 'claude'
  if (value === 'gpt') return 'gpt'
  throw new Error('Invalid Pulse provider')
}

// Explicit settings are recorded with every evaluation. No silent model fallback.
// Every Claude request, the Strong Week outlook included, runs on Sonnet 5.5 with structured
// outputs. The outlook used to force a tool call, which Sonnet 5.5 rejects (400), and so it sat on
// Sonnet 4.6; a JSON schema in output_config gives it the same guarantee without the tool.
export const DEFAULT_MODELS = { claude: 'claude-sonnet-5-5', gpt: 'gpt-5.6-terra' }
export const DEFAULT_CLAUDE_CHAT_MODEL = DEFAULT_MODELS.claude

// Low effort for conversational turns: the model skips thinking on most simple replies, keeping
// latency close to the old thinking-off behavior. The weekly summary and the Strong Week outlook
// run once a week and have to find patterns across days, so they get more room to reason.
export function effortFor(messageType: string): 'low' | 'medium' {
  return messageType === 'weekly_summary' || messageType === 'weekly_outlook' ? 'medium' : 'low'
}

// In chat, a safety-classifier decline gets the same redirect Pulse uses for anything outside
// its lane. Check-ins and summaries fail instead: an unrequested boundary message reads as broken.
export const REFUSAL_REPLY = "That one's outside what I can help with here — your doctor or pharmacist is the right person for it. I can help with food, protein, movement, and building the habits around your plan."
export async function generatePulse(options: {
  provider: Provider; apiKey: string; systemPrompt: string | SystemBlock[];
  messages: { role: string; content: string }[]; messageType: string; model?: string;
  guard?: PulseGuard;
}, transport: typeof fetch = fetch) {
  const { provider, apiKey, systemPrompt, messages, messageType } = options
  if (!apiKey) throw new Error('Missing provider key')
  const weekly = messageType === 'weekly_outlook'
  const model = options.model || DEFAULT_MODELS[provider]
  const instructions = typeof systemPrompt === 'string' ? systemPrompt : systemPrompt.map((block) => block.text).join('\n\n')
  const effort = effortFor(messageType)
  // The shape the reply must take: the outlook's three fields, or Pulse's reply with its cards.
  const schema = weekly ? strongWeekTool.input_schema : pulseSchemaFor(messageType)
  const body = provider === 'claude' ? {
    // Headroom for adaptive thinking, which counts toward max_tokens on Sonnet 5.x. Replies
    // themselves stay short; the prompt calibrates length, not this cap.
    model, max_tokens: 4096, system: systemPrompt, messages,
    output_config: { effort, format: { type: 'json_schema', schema } },
  } : {
    model, store: false, instructions, input: messages,
    max_output_tokens: 4096, reasoning: { effort: 'low' },
    ...(weekly ? { tools: [{ type: 'function', name: strongWeekTool.name,
      description: strongWeekTool.description, parameters: strongWeekTool.input_schema, strict: true }],
      tool_choice: { type: 'function', name: strongWeekTool.name }, parallel_tool_calls: false }
      : { text: { format: { type: 'json_schema', name: 'pulse_reply', schema, strict: true } } }),
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
  let output: { outlook?: Record<string, string> } & Partial<PulseReply>
  const textOf = (): string => {
    const content = provider === 'claude' ? data.content : (data.output ?? []).filter((x: any) => x.type === 'message').flatMap((x: any) => x.content ?? [])
    return (content ?? []).filter((x: any) => ['text', 'output_text'].includes(x.type)).map((x: any) => x.text).join('').trim()
  }
  if (provider === 'claude' && data.stop_reason === 'refusal') {
    // In chat, a decline gets the scope redirect; anywhere else it's a failure, not a message.
    if (messageType !== 'chat') throw new Error('Model declined')
    output = { reply: REFUSAL_REPLY }
  } else if (weekly) {
    let outlook: Record<string, string> | undefined
    if (provider === 'gpt') {
      if (data.status !== 'completed') throw new Error('Incomplete model response')
      outlook = parseStrongWeekOutlook((data.output ?? []).filter((item: any) => item.type === 'function_call').map((item: any) => ({
        type: 'tool_use', name: item.name, input: JSON.parse(item.arguments),
      })))
    } else {
      if (data.stop_reason !== 'end_turn') throw new Error('Incomplete model response')
      try { outlook = parseStrongWeekFields(JSON.parse(textOf())) } catch { outlook = undefined }
    }
    if (!outlook) throw new Error('Invalid weekly outlook')
    output = { outlook }
  } else {
    if (provider === 'claude' ? data.stop_reason !== 'end_turn' : data.status !== 'completed') throw new Error('Incomplete model response')
    const parsed = parsePulseReply(textOf(), messageType, options.guard)
    if (!parsed) throw new Error('Empty model response')
    output = parsed
  }
  const u = data.usage ?? {}
  return { output, metadata: { provider, requestedModel: model, returnedModel: data.model ?? model,
    latencyMs: Math.round(performance.now() - started), inputTokens: u.input_tokens ?? null,
    outputTokens: u.output_tokens ?? null, cachedInputTokens: provider === 'gpt' ? u.input_tokens_details?.cached_tokens ?? 0 : u.cache_read_input_tokens ?? 0,
    cacheCreationTokens: u.cache_creation_input_tokens ?? 0,
    reasoningTokens: u.output_tokens_details?.reasoning_tokens ?? null,
    stopReason: data.stop_reason ?? data.status ?? null,
    settings: provider === 'gpt' ? { maxOutputTokens: 4096, reasoningEffort: 'low' }
      : { maxOutputTokens: 4096, effort, structuredOutput: true },
  } }
}
