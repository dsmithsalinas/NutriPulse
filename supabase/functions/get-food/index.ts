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

    const { foodId, barcode } = await req.json()

    let resolvedFoodId: string | undefined = foodId
    if (barcode) {
      const barcodeJson = await fatSecretGet({ method: 'food.find_id_for_barcode', barcode })
      resolvedFoodId = (barcodeJson.food_id as { value?: string } | undefined)?.value
      if (!resolvedFoodId) {
        return new Response(JSON.stringify({ error: 'Barcode not found' }), {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }
    }

    if (!resolvedFoodId) {
      return new Response(JSON.stringify({ error: 'foodId or barcode required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const json = await fatSecretGet({ method: 'food.get.v4', food_id: resolvedFoodId })
    const food = json.food as Record<string, unknown> | undefined
    if (!food) {
      return new Response(JSON.stringify({ error: 'Food not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const servings = asArray((food.servings as Record<string, unknown>)?.serving as Record<string, string>[])
      .map((s) => ({
        id:          s.serving_id,
        description: s.serving_description,
        grams:       parseFloat(s.metric_serving_amount ?? '100'),
        calories:    parseFloat(s.calories  ?? '0'),
        proteinG:    parseFloat(s.protein   ?? '0'),
        carbsG:      parseFloat(s.carbohydrate ?? '0'),
        fatG:        parseFloat(s.fat       ?? '0'),
        fiberG:      parseFloat(s.fiber     ?? '0'),
      }))

    return new Response(
      JSON.stringify({ id: food.food_id, name: food.food_name, brand: food.brand_name ?? null, servings }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    // Generic client message; detail stays in the server logs (see search-food).
    console.error(err)
    return new Response(JSON.stringify({ error: 'Internal error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
