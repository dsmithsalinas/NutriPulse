import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { fatSecretGet, asArray } from '../_shared/fatsecret.ts'
import { restaurantName, scopedFoodSearch } from '../_shared/restaurant-context.ts'

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

    const { query, page = 0, maxResults = 25, restaurant = null } = await req.json()
    if ((restaurant != null && (typeof restaurant !== 'string' || !restaurant.trim() || restaurant.length > 80)) || typeof query !== 'string' || query.length > 300 || !Number.isInteger(page) || page < 0 || page > 100 || !Number.isInteger(maxResults) || maxResults < 1 || maxResults > 50) {
      return new Response(JSON.stringify({error:'Invalid search'}),{status:400,headers:{...corsHeaders,'Content-Type':'application/json'}})
    }
    if (!query?.trim()) {
      return new Response(JSON.stringify({ results: [], total: 0 }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    if (restaurant != null) {
      const name = restaurantName(restaurant)
      const scoped = await scopedFoodSearch(fatSecretGet,query.trim(),name,page,maxResults)
      return new Response(JSON.stringify({results:scoped.rows,total:scoped.total,hasMore:(page+1)*maxResults < scoped.total}),{headers:{...corsHeaders,'Content-Type':'application/json'}})
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
      JSON.stringify({ results, total: Number(foods.total_results ?? results.length), hasMore:(page+1)*maxResults < Number(foods.total_results ?? results.length) }),
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
