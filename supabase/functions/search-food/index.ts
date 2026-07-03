import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { getFatSecretToken, asArray } from '../_shared/fatsecret.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Verify the caller is authenticated
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

    const token = await getFatSecretToken()

    const url = new URL('https://platform.fatsecret.com/rest/server.api')
    url.searchParams.set('method', 'foods.search')
    url.searchParams.set('search_expression', query.trim())
    url.searchParams.set('page_number', String(page))
    url.searchParams.set('max_results', String(maxResults))
    url.searchParams.set('format', 'json')

    const res = await fetch(url.toString(), {
      headers: { Authorization: `Bearer ${token}` },
    })

    const json = await res.json()
    const foods = json.foods

    if (!foods || foods.error) {
      return new Response(JSON.stringify({ results: [], total: 0 }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Normalise to a consistent shape the Swift app can decode
    const results = asArray(foods.food).map((f: Record<string, string>) => ({
      id: f.food_id,
      name: f.food_name,
      brand: f.brand_name ?? null,
      description: f.food_description ?? '',
    }))

    return new Response(
      JSON.stringify({ results, total: Number(foods.total_results ?? results.length) }),
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
