// Pure helpers shared by deterministic Search and consented guided Talk.
export type Restaurant = { name: string; origin: 'manual' | 'detected' | 'confirmed' }
export type Ingredient = { id: string; name: string; state: 'included' | 'excluded' | 'unspecified'; quantity: number; fromDescription: boolean; uncertain: boolean }
export type Dish = { id: string; name: string; customizable: boolean; ingredients: Ingredient[] }
export const RESTAURANTS = ['Chipotle', 'Texas Roadhouse', 'Panera Bread', 'Starbucks', 'Chick-fil-A', 'Subway', "McDonald's", 'Taco Bell']
export const normalize = (value: string) => value.toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim()
export function restaurantName(value: unknown): string | null {
  if (value == null) return null
  if (typeof value !== 'string' || !value.trim() || value.trim().length > 80) throw new Error('Invalid restaurant')
  const input = normalize(value)
  return RESTAURANTS.find(name => normalize(name) === input || (name === 'Chipotle' && input === 'chipotle mexican grill') || (name === 'Panera Bread' && input === 'panera')) ?? value.trim()
}
export function brandMatches(brand: unknown, restaurant: string): boolean {
  if (typeof brand !== 'string') return false
  const expected = normalize(restaurantName(restaurant)!), actual = normalize(brand)
  if (actual === expected) return true
  return (expected === 'chipotle' && actual === 'chipotle mexican grill') || (expected === 'panera bread' && actual === 'panera')
}
export function restaurantIntent(text: string, selected: Restaurant | null, interpretation: string | null) {
  const words = normalize(text)
  const found = RESTAURANTS.filter(name => words.includes(normalize(name)) || (name === 'Panera Bread' && /\bpanera\b/.test(words)))
    .filter(name => name !== 'Chipotle' || !/\bchipotle (sauce|seasoning|peppers?|chiles?|chillies)\b/.test(words) || /\b(from|at) chipotle\b/.test(words))
  const choice = (name: string) => ({ id: name, label: name === 'Chipotle' ? 'Chipotle restaurant' : name, restaurant: name })
  if (interpretation === 'none') return { restaurant: selected, clarification: null }
  const venues = found.filter(name => name !== 'Chipotle' || (interpretation !== 'ingredient' && (/\b(from|at) chipotle\b/.test(words) || /\bchipotle (chicken )?(bowl|burrito|salad|tacos?)\b/.test(words) || /\b(chipotle and|and chipotle)\b/.test(words))))
  if (venues.length > 1) return { restaurant: selected, clarification: { message: 'Log one restaurant at a time', detail: 'Split this description into separate entries so each food keeps the right restaurant.', choices: [] } }
  const explicit = venues[0]
  if (selected && explicit && !brandMatches(explicit, selected.name) && selected.origin !== 'confirmed') {
    return { restaurant: selected, clarification: { message: 'Which restaurant should we use?', detail: `You selected ${selected.name}, but the description mentions ${explicit}.`, choices: [choice(selected.name), choice(explicit)] } }
  }
  if (selected) return { restaurant: selected, clarification: null }
  if (explicit) return { restaurant: { name: explicit, origin: 'detected' as const }, clarification: null }
  if (interpretation !== 'ingredient' && /\bchipotle\b/.test(words) && found.includes('Chipotle')) return { restaurant: null, clarification: { message: 'Chipotle the restaurant?', detail: 'Or did you mean chicken with chipotle seasoning?', choices: [choice('Chipotle'), { id: 'ingredient', label: 'Chipotle seasoning', restaurant: null }] } }
  return { restaurant: null, clarification: null }
}

// Composition prompts, not asserted menu availability or nutrition. Names checked against
// Chipotle's public ingredients/allergen list; nutrition always comes from lookup/review.
export const BOWL_OPTIONS = ['Chicken', 'Steak', 'Carnitas', 'Barbacoa', 'Sofritas', 'White rice', 'Brown rice', 'Black beans', 'Pinto beans', 'Fajita vegetables', 'Fresh tomato salsa', 'Corn salsa', 'Green salsa', 'Red salsa', 'Cheese', 'Sour cream', 'Guacamole', 'Lettuce']
export function withSuggestions(dish: Dish): Dish {
  const named = new Set(dish.ingredients.map(item => normalize(item.name)))
  const options = /bowl|burrito|salad|taco/i.test(dish.name) ? BOWL_OPTIONS : ['Bread', 'Chicken', 'Turkey', 'Beef', 'Cheese', 'Lettuce', 'Tomato', 'Onion', 'Mayonnaise', 'Mustard']
  const extras = options.filter(name => !named.has(normalize(name))).map((name, i) => ({ id: `${dish.id}-option-${i}`, name, state: 'unspecified' as const, quantity: 1, fromDescription: false, uncertain: false }))
  return { ...dish, ingredients: [...dish.ingredients, ...extras].slice(0, 40) }
}
export function validateDishes(raw: unknown, text?: string): Dish[] {
  if (!Array.isArray(raw) || raw.length < 1 || raw.length > 6) throw new Error('Describe up to six dishes at a time.')
  const ids = new Set<string>()
  return raw.map((dish, d) => {
    if (!dish || typeof dish.name !== 'string' || !dish.name.trim() || dish.name.length > 120 || !Array.isArray(dish.ingredients) || dish.ingredients.length > 40) throw new Error('Invalid dish')
    const dishID = typeof dish.id === 'string' ? dish.id : `dish-${d}`
    if (!dishID || dishID.length > 80 || ids.has(dishID)) throw new Error('Invalid dish ID')
    ids.add(dishID)
    const ingredientIDs = new Set<string>()
    const ingredients: Ingredient[] = dish.ingredients.map((item: any, i: number) => {
      if (text && item?.state === 'excluded' && item.quantity === 0) item = {...item,quantity:1}
      if (!item || typeof item.name !== 'string' || !item.name.trim() || item.name.length > 120 || !['included','excluded','unspecified'].includes(item.state) || !Number.isFinite(item.quantity) || item.quantity < 0.25 || item.quantity > 10) throw new Error('Invalid ingredient')
      if (text) {
        // Evidence must quote the actual description and name a food, not a dish-based guess.
        if (typeof item.evidence !== 'string' || !item.evidence.trim() || !normalize(text).includes(normalize(item.evidence))) throw new Error('Ingredient evidence missing')
        const foodWords = normalize(item.name).split(' ').filter((word: string) => word.length > 2)
        if (!foodWords.some((word: string) => normalize(item.evidence).includes(word))) throw new Error('Unstated ingredient')
      }
      if (text && typeof item.evidence === 'string') {
        const weight = /\b(\d+(?:\.\d+)?|one|two|three|four|five|six|seven|eight|nine|ten|half)\s*[- ]?(oz|ounces?|g|grams?|lb|lbs|pounds?)\b/i.exec(item.evidence)
        if (weight) {
          const words: Record<string,number> = {one:1,two:2,three:3,four:4,five:5,six:6,seven:7,eight:8,nine:9,ten:10,half:0.5}
          const amount = words[weight[1].toLowerCase()] ?? Number(weight[1])
          // Extraction sometimes treats "six ounce" as six servings. Preserve the weight
          // in the query and do not multiply a weight-specific database serving again.
          if (item.quantity === amount) item = {...item,quantity:1}
          if (!/\b(oz|ounces?|g|grams?|lb|lbs|pounds?)\b/i.test(item.name)) item = {...item,name:`${amount} ${weight[2]} ${item.name}`}
        }
      }
      const id = typeof item.id === 'string' ? item.id : `${dishID}-ingredient-${i}`
      if (!id || id.length > 120 || ingredientIDs.has(id)) throw new Error('Invalid ingredient ID')
      ingredientIDs.add(id)
      return { id, name: item.name.trim(), state: item.state, quantity: item.quantity, fromDescription: text != null, uncertain: item.uncertain === true || /^(rice|beans|salsa|meat)$/i.test(item.name.trim()) }
    })
    return { id: dishID, name: dish.name.trim(), customizable: dish.customizable === true, ingredients }
  })
}

type SearchFood = { id: string; name: string; brand: string | null; description: string; matchKind?: string }
type FoodAPI = (params: Record<string,string>) => Promise<Record<string, any>>
const array = <T>(value: T | T[] | undefined): T[] => value == null ? [] : Array.isArray(value) ? value : [value]
export async function scopedFoodSearch(api: FoodAPI, query: string, restaurant: string | null, page = 0, maxResults = 25) {
  const read = async (q: string) => {
    const json = await api({ method:'foods.search', search_expression:q, page_number:String(page), max_results:String(maxResults) })
    if (json.error || json.foods?.error) throw new Error('Food search is unavailable. Please try again.')
    return { rows: array<any>(json.foods?.food).map((food): SearchFood => ({ id:String(food.food_id), name:food.food_name, brand:food.brand_name ?? null, description:food.food_description ?? '' })), total:Number(json.foods?.total_results ?? 0) }
  }
  if (!restaurant) return read(query)
  const scoped = await read(`${restaurant} ${query}`)
  const exact = scoped.rows.filter(food => brandMatches(food.brand, restaurant)).map(food => ({...food, matchKind:'restaurant'}))
  // Fall back explicitly, never re-label another venue as the selected restaurant.
  const fallback = await read(query)
  const seen = new Set(exact.map(food => food.id))
  const generic = [...scoped.rows,...fallback.rows].filter(food => !seen.has(food.id) && (seen.add(food.id), true)).map(food => ({...food, matchKind:brandMatches(food.brand, restaurant) ? 'restaurant' : 'generic'}))
  return { rows:[...exact,...generic].sort((a,b) => Number(b.matchKind === 'restaurant') - Number(a.matchKind === 'restaurant')), total:Math.max(scoped.total,fallback.total) }
}
