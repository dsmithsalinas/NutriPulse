import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { getFatSecretToken, asArray } from '../_shared/fatsecret.ts'

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

    const { foodId } = await req.json()
    if (!foodId) {
      return new Response(JSON.stringify({ error: 'foodId required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const token = await getFatSecretToken()

    const url = new URL('https://platform.fatsecret.com/rest/server.api')
    url.searchParams.set('method', 'food.get.v4')
    url.searchParams.set('food_id', foodId)
    url.searchParams.set('format', 'json')

    const res = await fetch(url.toString(), {
      headers: { Authorization: `Bearer ${token}` },
    })

    const json = await res.json()
    const food = json.food
    if (!food) {
      return new Response(JSON.stringify({ error: 'Food not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Normalise servings — FatSecret returns a single object when there's only one
    const servings = asArray(food.servings?.serving).map((s: Record<string, string>) => ({
      id: s.serving_id,
      description: s.serving_description,
      grams: parseFloat(s.metric_serving_amount ?? '100'),
      calories: parseFloat(s.calories ?? '0'),
      proteinG: parseFloat(s.protein ?? '0'),
      carbsG: parseFloat(s.carbohydrate ?? '0'),
      fatG: parseFloat(s.fat ?? '0'),
      fiberG: parseFloat(s.fiber ?? '0'),
    }))

    return new Response(
      JSON.stringify({
        id: food.food_id,
        name: food.food_name,
        brand: food.brand_name ?? null,
        servings,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    console.error(err)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
