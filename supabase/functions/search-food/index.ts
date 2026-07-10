import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { fatSecretGet, asArray } from '../_shared/fatsecret.ts'

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

    const { query, page = 0, maxResults = 25 } = await req.json()
    if (!query?.trim()) {
      return new Response(JSON.stringify({ results: [], total: 0 }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const json = await fatSecretGet({
      method: 'foods.search',
      search_expression: query.trim(),
      page_number: String(page),
      max_results: String(maxResults),
    })

    const foods = json.foods as Record<string, unknown> | undefined
    if (!foods || (foods as Record<string, unknown>).error) {
      return new Response(JSON.stringify({ results: [], total: 0 }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const results = asArray(foods.food as Record<string, string>[])
      .map((f) => ({
        id:          f.food_id,
        name:        f.food_name,
        brand:       f.brand_name ?? null,
        description: f.food_description ?? '',
      }))

    return new Response(
      JSON.stringify({ results, total: Number(foods.total_results ?? results.length) }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    // Log the detail server-side; return a generic message so upstream (FatSecret) error
    // bodies and internal failure detail don't leak to clients — matching coach-chat/parse-food.
    console.error(err)
    return new Response(JSON.stringify({ error: 'Internal error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
