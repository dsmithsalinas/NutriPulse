import { parseStrongWeekOutlook, strongWeekTool } from './pulse-context.ts'

export type Provider = 'claude' | 'gpt'
export function selectProvider(value?: string): Provider {
  if (!value || value === 'claude') return 'claude'
  if (value === 'gpt') return 'gpt'
  throw new Error('Invalid Pulse provider')
}

// Explicit settings are recorded with every evaluation. No silent model fallback.
export const DEFAULT_MODELS = { claude: 'claude-sonnet-4-6', gpt: 'gpt-5.6-terra' }
export async function generatePulse(options: {
  provider: Provider; apiKey: string; systemPrompt: string;
  messages: { role: string; content: string }[]; messageType: string; model?: string;
}, transport: typeof fetch = fetch) {
  const { provider, apiKey, systemPrompt, messages, messageType } = options
  if (!apiKey) throw new Error('Missing provider key')
  const model = options.model || DEFAULT_MODELS[provider]
  const weekly = messageType === 'weekly_outlook'
  const body = provider === 'claude' ? {
    model, max_tokens: 1024, system: systemPrompt, messages,
    ...(weekly ? { tools: [strongWeekTool], tool_choice: { type: 'tool', name: strongWeekTool.name } } : {}),
  } : {
    model, store: false, instructions: systemPrompt, input: messages,
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
    settings: provider === 'gpt' ? { maxOutputTokens: 4096, reasoningEffort: 'low' } : { maxOutputTokens: 1024 },
  } }
}
