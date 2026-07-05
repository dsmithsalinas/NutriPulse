import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { fatSecretGet, asArray } from '../_shared/fatsecret.ts'

// Talk-to-log, two-hop and Claude-tool-use-driven:
//   1. Claude decomposes the sentence into named, quantified components
//      (its own food knowledge — a "Chipotle bowl" implies chicken, rice, pico...).
//   2. Claude calls the `search_fatsecret` tool, as many times as it needs, to ground
//      each component in real FatSecret data instead of guessing macros from memory.
//   3. Claude picks the best candidate per component and calls `submit_parsed_items`
//      exactly once, with a fallback estimate in case its pick doesn't resolve.
//   4. We take Claude's picks, fetch precise per-serving macros from FatSecret
//      (food.get.v4 — the same lookup get-food uses), scale by quantity, and return
//      a plain list. The confirm card is built and edited entirely client-side —
//      this function never touches the database.

const PARSE_SYSTEM_PROMPT = `You parse a user's freeform description of a meal into its named, quantified food components, matched against FatSecret's database.

PROCESS — follow this exactly:
1. Decompose the sentence using your own knowledge of what dishes actually contain. "Chipotle chicken bowl" means chicken, cilantro-lime rice, pico de gallo, romaine, cheese — list each real component, not the dish name as one blob.
2. For every distinct component, call search_fatsecret. Try the specific version first (e.g. "Chipotle chicken" for a branded item), and a generic fallback if that returns nothing useful (e.g. "grilled chicken breast").
3. From the search results, pick the single best match given context — correct preparation, correct brand, a plausible serving size. Getting this wrong is the main way this feature fails, so weigh it carefully; don't default to the first or most-generic result if a better one is present.
4. Once every component has been searched and resolved (or you've done your best), call submit_parsed_items exactly once, as your last action. Always include a fallbackEstimate per item — your own best-guess macros for one typical serving — even when you also have a matchedFoodId, in case that id fails to resolve.

Never call submit_parsed_items before searching for every component at least once.`

const TOOLS = [
  {
    name: 'search_fatsecret',
    description:
      "Search FatSecret's food database for a named item. Returns up to 10 candidates with id, name, brand, and a one-line macro summary. Call once per distinct food component.",
    input_schema: {
      type: 'object',
      properties: {
        query: {
          type: 'string',
          description: "Food name to search for, e.g. 'grilled chicken breast' or 'Chipotle chicken'.",
        },
      },
      required: ['query'],
    },
  },
  {
    name: 'submit_parsed_items',
    description:
      'Submit the final decomposed, resolved list of food items. Call exactly once, as the last step.',
    input_schema: {
      type: 'object',
      properties: {
        items: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              query: {
                type: 'string',
                description: "The component as parsed from the sentence, e.g. 'cilantro-lime rice'.",
              },
              quantity: {
                type: 'number',
                description: "Multiplier vs. one typical serving of the matched food, e.g. 1.5.",
              },
              matchedFoodId: {
                type: 'string',
                description: 'FatSecret food_id of the best candidate. Omit if no good match was found.',
              },
              fallbackEstimate: {
                type: 'object',
                description: 'Your best estimate for ONE typical serving. Used if matchedFoodId is absent or fails to resolve.',
                properties: {
                  servingDesc: { type: 'string' },
                  calories:    { type: 'number' },
                  proteinG:    { type: 'number' },
                  carbsG:      { type: 'number' },
                  fatG:        { type: 'number' },
                  fiberG:      { type: 'number' },
                },
                required: ['servingDesc', 'calories', 'proteinG', 'carbsG', 'fatG', 'fiberG'],
              },
            },
            required: ['query', 'quantity', 'fallbackEstimate'],
          },
        },
      },
      required: ['items'],
    },
  },
]

type AnthropicContentBlock =
  | { type: 'text'; text: string }
  | { type: 'tool_use'; id: string; name: string; input: Record<string, unknown> }

interface AnthropicMessage {
  role: 'user' | 'assistant'
  content: string | AnthropicContentBlock[]
}

async function callClaude(apiKey: string, messages: AnthropicMessage[]) {
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: 'claude-haiku-4-5',
      max_tokens: 1536,
      system: PARSE_SYSTEM_PROMPT,
      tools: TOOLS,
      messages,
    }),
  })
  if (!res.ok) throw new Error(`Anthropic ${res.status}: ${await res.text()}`)
  return res.json()
}

async function searchFatSecret(query: string) {
  const json = await fatSecretGet({ method: 'foods.search', search_expression: query, max_results: '8' })
  const foods = json.foods as Record<string, unknown> | undefined
  if (!foods || (foods as Record<string, unknown>).error) return []
  return asArray(foods.food as Record<string, string>[]).map((f) => ({
    id: f.food_id,
    name: f.food_name,
    brand: f.brand_name ?? null,
    description: f.food_description ?? '',
  }))
}

interface ResolvedItem {
  query: string
  name: string
  brand: string | null
  servingDesc: string
  grams: number
  quantity: number
  calories: number
  proteinG: number
  carbsG: number
  fatG: number
  fiberG: number
  source: 'fatsecret' | 'estimated'
  externalId: string | null
}

async function resolveItem(item: {
  query: string
  quantity: number
  matchedFoodId?: string
  fallbackEstimate: {
    servingDesc: string; calories: number; proteinG: number; carbsG: number; fatG: number; fiberG: number
  }
}): Promise<ResolvedItem> {
  const quantity = item.quantity > 0 ? item.quantity : 1

  if (item.matchedFoodId) {
    try {
      const json = await fatSecretGet({ method: 'food.get.v4', food_id: item.matchedFoodId })
      const food = json.food as Record<string, unknown> | undefined
      const serving = asArray(
        (food?.servings as Record<string, unknown>)?.serving as Record<string, string>[]
      )[0]
      if (food && serving) {
        // Per-serving values, unscaled — quantity travels alongside as its own field,
        // matching how food_logs stores a snapshot + quantity rather than a pre-multiplied total.
        return {
          query: item.query,
          name: food.food_name as string,
          brand: (food.brand_name as string | undefined) ?? null,
          servingDesc: serving.serving_description,
          grams: parseFloat(serving.metric_serving_amount ?? '100'),
          quantity,
          calories: parseFloat(serving.calories ?? '0'),
          proteinG: parseFloat(serving.protein ?? '0'),
          carbsG: parseFloat(serving.carbohydrate ?? '0'),
          fatG: parseFloat(serving.fat ?? '0'),
          fiberG: parseFloat(serving.fiber ?? '0'),
          source: 'fatsecret',
          externalId: item.matchedFoodId,
        }
      }
    } catch (err) {
      console.error(`food.get.v4 failed for ${item.matchedFoodId}:`, err)
      // falls through to the estimate below
    }
  }

  const est = item.fallbackEstimate
  return {
    query: item.query,
    name: item.query,
    brand: null,
    servingDesc: est.servingDesc,
    grams: 100,
    quantity,
    calories: est.calories,
    proteinG: est.proteinG,
    carbsG: est.carbsG,
    fatG: est.fatG,
    fiberG: est.fiberG,
    source: 'estimated',
    externalId: null,
  }
}

const MAX_TURNS = 8

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

    const { text } = await req.json()
    if (!text?.trim()) {
      return new Response(JSON.stringify({ error: 'text required' }), {
        status: 400,
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

    const messages: AnthropicMessage[] = [{ role: 'user', content: text.trim() }]

    for (let turn = 0; turn < MAX_TURNS; turn++) {
      const data = await callClaude(apiKey, messages)
      const content = data.content as AnthropicContentBlock[]
      const toolUses = content.filter((b): b is Extract<AnthropicContentBlock, { type: 'tool_use' }> => b.type === 'tool_use')

      const submit = toolUses.find((t) => t.name === 'submit_parsed_items')
      if (submit) {
        const rawItems = (submit.input.items ?? []) as Parameters<typeof resolveItem>[0][]
        const items = await Promise.all(rawItems.map(resolveItem))
        return new Response(JSON.stringify({ items }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      if (toolUses.length === 0) {
        // Claude replied without using a tool — nothing to resolve.
        break
      }

      // Run every search_fatsecret call from this turn, then hand results back so
      // Claude can pick candidates and either search again or submit.
      messages.push({ role: 'assistant', content })
      const toolResults = await Promise.all(
        toolUses.map(async (t) => {
          const results = t.name === 'search_fatsecret'
            ? await searchFatSecret((t.input.query as string) ?? '')
            : []
          return {
            type: 'tool_result' as const,
            tool_use_id: t.id,
            content: JSON.stringify(results),
          }
        })
      )
      messages.push({ role: 'user', content: toolResults as unknown as AnthropicContentBlock[] })
    }

    return new Response(
      JSON.stringify({ error: "Couldn't parse that meal — try rephrasing or add it manually." }),
      { status: 422, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    console.error('parse-food error:', err)
    return new Response(JSON.stringify({ error: 'Internal error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
