// Server-only adapter. Schema-constrained tool output, no nutrition from plain prose.
export async function guidedFoodModel(apiKey: string, system: string, schema: Record<string,unknown>, input: unknown) {
  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method:'POST', headers:{'x-api-key':apiKey,'anthropic-version':'2023-06-01','content-type':'application/json'},
    body:JSON.stringify({model:'claude-haiku-4-5',max_tokens:4096,system,
      tools:[{name:'respond',description:'Return the structured result.',input_schema:schema}],
      tool_choice:{type:'tool',name:'respond'},messages:[{role:'user',content:JSON.stringify(input)}]}),
    signal:AbortSignal.timeout(25000),
  })
  if (!response.ok) throw new Error(`Meal interpretation unavailable (${response.status})`)
  const result = await response.json()
  const tool = result.content?.find((part: any) => part.type === 'tool_use' && part.name === 'respond')
  if (!tool?.input || result.stop_reason === 'max_tokens') throw new Error('Meal interpretation incomplete')
  return tool.input
}
