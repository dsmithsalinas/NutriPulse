// Seeds two demo profiles (Marcus Reyes, Jordan Ellis) with ~2 weeks of realistic data:
// profile details, a daily goal, food logs, weekly GLP-1 shots, a weight trend, water, and
// body-composition entries. Runs against whatever Supabase your local Secrets.xcconfig points at,
// using the PUBLIC anon key + normal sign-up (email confirmations are off on this project), so it
// needs no service-role secret. Idempotent: re-running wipes each demo user's data and reseeds.
//
//   cd scripts && npm install && node seed-demo-profiles.mjs
//
// HealthKit data is NOT seeded here — it lives on-device (see the in-app "Seed demo Health" tool).

import { createClient } from '@supabase/supabase-js'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'

const __dir = dirname(fileURLToPath(import.meta.url))

// ── Read SUPABASE_URL / anon key from the (gitignored) xcconfig, resolving $(VAR) refs ──
function readSecrets() {
  const raw = readFileSync(resolve(__dir, '../Configurations/Secrets.xcconfig'), 'utf8')
  const vars = {}
  for (const line of raw.split('\n')) {
    const m = line.match(/^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*?)\s*$/)
    if (m && !line.trim().startsWith('//')) vars[m[1]] = m[2]
  }
  const resolveVal = (v, depth = 0) =>
    depth > 5 ? v : v.replace(/\$\(([A-Z_][A-Z0-9_]*)\)/g, (_, k) => resolveVal(vars[k] ?? '', depth + 1))
  return { url: resolveVal(vars.SUPABASE_URL || ''), anon: resolveVal(vars.SUPABASE_ANON_KEY || '') }
}

const { url: SUPABASE_URL, anon: ANON_KEY } = readSecrets()
if (!SUPABASE_URL || !ANON_KEY) {
  console.error('Could not read SUPABASE_URL / SUPABASE_ANON_KEY from Configurations/Secrets.xcconfig')
  process.exit(1)
}
const PASSWORD = 'DemoPass!2026'

// ── Date helpers (local calendar) ──
const DAY = 86400000
const at = (daysAgo, hour = 12, min = 0) => {
  const d = new Date(); d.setHours(hour, min, 0, 0); return new Date(d.getTime() - daysAgo * DAY)
}
const iso = (d) => d.toISOString()
const isoDate = (d) => { const z = new Date(d); z.setMinutes(z.getMinutes() - z.getTimezoneOffset()); return z.toISOString().slice(0, 10) }
const round = (n, step = 0.25) => Math.round(n / step) * step

// ── Food catalog: [name, brand|null, servingDesc, grams, cal, protein, carbs, fat, fiber] ──
const FOODS = {
  greekYogurt:   ['Greek Yogurt, plain', 'Fage', '1 cup (170 g)', 170, 150, 20, 9, 4, 0],
  berries:       ['Mixed Berries', null, '1 cup (140 g)', 140, 70, 1, 17, 0.5, 4],
  eggs:          ['Eggs, large', null, '2 eggs', 100, 140, 12, 1, 10, 0],
  oatmeal:       ['Oatmeal, cooked', null, '1 cup (234 g)', 234, 150, 5, 27, 3, 4],
  chickenBreast: ['Grilled Chicken Breast', null, '6 oz (170 g)', 170, 280, 52, 0, 6, 0],
  salmon:        ['Baked Salmon', null, '5 oz (142 g)', 142, 300, 34, 0, 18, 0],
  rice:          ['White Rice, cooked', null, '1 cup (158 g)', 158, 205, 4, 45, 0.4, 0.6],
  proteinShake:  ['Whey Protein Shake', 'Optimum', '1 scoop + milk', 300, 200, 30, 8, 4, 1],
  cottageCheese: ['Cottage Cheese, low-fat', null, '1 cup (226 g)', 226, 180, 24, 8, 5, 0],
  turkey:        ['Ground Turkey, 93%', null, '4 oz (112 g)', 112, 170, 34, 0, 3, 0],
  broccoli:      ['Broccoli, steamed', null, '1 cup (156 g)', 156, 55, 4, 11, 0.6, 5],
  sweetPotato:   ['Sweet Potato, baked', null, '1 medium (150 g)', 150, 112, 2, 26, 0.1, 4],
  almonds:       ['Almonds', null, '1 oz (28 g)', 28, 165, 6, 6, 14, 3.5],
  banana:        ['Banana', null, '1 medium', 118, 105, 1, 27, 0.4, 3],
  apple:         ['Apple', null, '1 medium', 182, 95, 0.5, 25, 0.3, 4],
  groundBeef:    ['Ground Beef, 90/10', null, '4 oz (112 g)', 112, 200, 23, 0, 11, 0],
  wheatBread:    ['Whole Wheat Bread', null, '2 slices', 56, 160, 8, 28, 2, 4],
  peanutButter:  ['Peanut Butter', null, '2 tbsp (32 g)', 32, 190, 8, 7, 16, 2],
  proteinBar:    ['Protein Bar', 'Quest', '1 bar (60 g)', 60, 200, 20, 22, 7, 3],
  salad:         ['Garden Salad w/ vinaigrette', null, '1 bowl', 200, 120, 3, 10, 8, 3],
  tuna:          ['Tuna, canned in water', null, '1 can (142 g)', 142, 120, 26, 0, 1, 0],
  stringCheese:  ['String Cheese', null, '1 stick', 28, 80, 7, 1, 6, 0],
  milk:          ['Milk, 2%', null, '1 cup (244 g)', 244, 120, 8, 12, 5, 0],
  avocado:       ['Avocado', null, '1/2 fruit', 100, 160, 2, 9, 15, 7],
}

// Day templates: [foodKey, meal, baseQty]. Multiplier per persona scales portions.
const T = {
  A: [['greekYogurt','breakfast',1],['berries','breakfast',1],['eggs','breakfast',1],
      ['chickenBreast','lunch',1],['rice','lunch',1],['broccoli','lunch',1],
      ['salmon','dinner',1],['sweetPotato','dinner',1],['salad','dinner',1],
      ['proteinShake','snack',1],['almonds','snack',1]],
  B: [['oatmeal','breakfast',1],['proteinShake','breakfast',1],['banana','breakfast',1],
      ['turkey','lunch',1.5],['wheatBread','lunch',1],['stringCheese','lunch',1],
      ['groundBeef','dinner',1.5],['rice','dinner',1],['broccoli','dinner',1],
      ['cottageCheese','snack',1],['apple','snack',1]],
  C: [['eggs','breakfast',1.5],['wheatBread','breakfast',1],['avocado','breakfast',1],
      ['tuna','lunch',1],['salad','lunch',1],['wheatBread','lunch',1],
      ['chickenBreast','dinner',1.5],['sweetPotato','dinner',1],['broccoli','dinner',1],
      ['proteinBar','snack',1],['milk','snack',1]],
  D: [['greekYogurt','breakfast',1.5],['berries','breakfast',1],
      ['salmon','lunch',1],['rice','lunch',1],['salad','lunch',1],
      ['turkey','dinner',2],['sweetPotato','dinner',1],['broccoli','dinner',1],
      ['peanutButter','snack',1],['apple','snack',1]],
  light: [['oatmeal','breakfast',1],['banana','breakfast',1],
      ['chickenBreast','lunch',1],['salad','lunch',1],
      ['cottageCheese','dinner',1],['tuna','dinner',1],
      ['proteinBar','snack',1]],
}
const ROTATION = ['A','B','C','D','A','B','C','D','A','B','C','D','A','B']

const PERSONAS = [
  {
    email: 'marcus.reyes.demo@example.com', name: 'Marcus Reyes', sex: 'male',
    dob: '1982-03-15', heightCm: 185.4, activity: 'active',
    goal: { calories: 2400, protein_g: 200, carbs_g: 230, fat_g: 70, fiber_g: 35, water_ml_target: 3500 },
    portion: 1.25, lightDays: [],
    startKg: 111.1, endKg: 108.4,      // 245 -> 239 lb
    med: 'Zepbound', doseMg: 7.5, shotDaysAgo: [14, 7],  // last shot 7d ago -> next due today (dose day)
    water: [2900, 3400], bodyFat: 24.5,
  },
  {
    email: 'jordan.ellis.demo@example.com', name: 'Jordan Ellis', sex: 'female',
    dob: '1989-08-22', heightCm: 167.6, activity: 'moderate',
    goal: { calories: 1600, protein_g: 130, carbs_g: 150, fat_g: 50, fiber_g: 28, water_ml_target: 2500 },
    portion: 0.75, lightDays: [3, 9],  // two genuinely light days -> shows the coach nudge
    startKg: 83.9, endKg: 82.1,        // 185 -> 181 lb
    med: 'Wegovy', doseMg: 1.0, shotDaysAgo: [11, 4],   // last shot 4d ago -> next due in 3 days
    water: [2000, 2600], bodyFat: 30.8,
  },
]

async function seedPersona(p) {
  console.log(`\n── ${p.name} (${p.email}) ──`)
  const supa = createClient(SUPABASE_URL, ANON_KEY, { auth: { persistSession: false } })

  // Sign in if the account already exists, else sign up.
  let { data: signIn } = await supa.auth.signInWithPassword({ email: p.email, password: PASSWORD })
  if (!signIn?.session) {
    const { data: signUp, error } = await supa.auth.signUp({ email: p.email, password: PASSWORD })
    if (error) throw new Error(`sign-up failed: ${error.message}`)
    if (!signUp.session) throw new Error('no session after sign-up (email confirmation may be ON in prod)')
    signIn = signUp
  }
  const uid = signIn.user.id
  console.log(`  auth ok · uid ${uid.slice(0, 8)}…`)

  // Idempotent reset: clear this user's data (order respects FKs).
  for (const t of ['food_logs', 'favorites']) await supa.from(t).delete().eq('user_id', uid)
  for (const t of ['food_items', 'daily_goals', 'weight_logs', 'water_logs', 'glp1_logs', 'body_composition_logs'])
    await supa.from(t).delete().eq('user_id', uid)

  // Profile
  await supa.from('profiles').update({
    full_name: p.name, dob: p.dob, sex: p.sex, height_cm: p.heightCm, activity_level: p.activity,
  }).eq('id', uid)

  // Daily goal (effective from the start of the window)
  await supa.from('daily_goals').insert({
    user_id: uid, effective_date: isoDate(at(14)), ...p.goal,
  })

  // Food items catalog (owned by this user), keep id map for logs
  const itemRows = Object.entries(FOODS).map(([key, f]) => ({
    user_id: uid, source: 'manual', external_id: null,
    name: f[0], brand: f[1], serving_desc: f[2], serving_grams: f[3],
    calories: f[4], protein_g: f[5], carbs_g: f[6], fat_g: f[7], fiber_g: f[8], _key: key,
  }))
  const { data: items, error: itemErr } = await supa.from('food_items')
    .insert(itemRows.map(({ _key, ...r }) => r)).select()
  if (itemErr) throw new Error(`food_items: ${itemErr.message}`)
  const idFor = {}
  items.forEach((row, i) => { idFor[itemRows[i]._key] = row })

  // Food logs — 14 days
  const logs = []
  for (let d = 13; d >= 0; d--) {
    const template = p.lightDays.includes(d) ? T.light : T[ROTATION[13 - d]]
    for (const [key, meal, baseQty] of template) {
      const f = idFor[key]
      const qty = Math.max(0.25, round(baseQty * p.portion))
      logs.push({
        user_id: uid, log_date: isoDate(at(d)),
        logged_at: iso(at(d, meal === 'breakfast' ? 8 : meal === 'lunch' ? 12 : meal === 'dinner' ? 19 : 15)),
        meal, food_item_id: f.id, quantity: qty,
        // Snapshots are PER-SERVING — the app computes the total as snapshot × quantity
        // (FoodLog.totalCalories). Pre-multiplying here double-counts quantity.
        calories_snapshot: +f.calories.toFixed(1),
        protein_g_snapshot: +f.protein_g.toFixed(2),
        carbs_g_snapshot: +f.carbs_g.toFixed(2),
        fat_g_snapshot: +f.fat_g.toFixed(2),
        fiber_g_snapshot: +f.fiber_g.toFixed(2),
      })
    }
  }
  const { error: logErr } = await supa.from('food_logs').insert(logs)
  if (logErr) throw new Error(`food_logs: ${logErr.message}`)

  // Weight trend (every ~2 days, linear with a little noise)
  const weights = []
  for (let d = 14; d >= 0; d -= 2) {
    const t = (14 - d) / 14
    const kg = p.startKg + (p.endKg - p.startKg) * t + (d % 4 === 0 ? 0.2 : -0.15)
    weights.push({ user_id: uid, logged_at: iso(at(d, 7)), weight_kg: +kg.toFixed(2), source: 'manual' })
  }
  await supa.from('weight_logs').insert(weights)

  // Water — one aggregate per day
  const waters = []
  for (let d = 13; d >= 0; d--) {
    const ml = p.water[0] + ((13 - d) % 5) * ((p.water[1] - p.water[0]) / 5)
    waters.push({ user_id: uid, log_date: isoDate(at(d)), logged_at: iso(at(d, 20)), amount_ml: Math.round(ml), source: 'manual' })
  }
  await supa.from('water_logs').insert(waters)

  // Body composition — start and recent
  const bmi = (kg) => +(kg / ((p.heightCm / 100) ** 2)).toFixed(1)
  await supa.from('body_composition_logs').insert([
    { user_id: uid, log_date: isoDate(at(14)), weight_kg: +p.startKg.toFixed(2), body_fat_pct: p.bodyFat, bmi: bmi(p.startKg), lean_body_mass_kg: +(p.startKg * (1 - p.bodyFat / 100)).toFixed(2), source: 'manual' },
    { user_id: uid, log_date: isoDate(at(2)), weight_kg: +p.endKg.toFixed(2), body_fat_pct: +(p.bodyFat - 0.8).toFixed(1), bmi: bmi(p.endKg), lean_body_mass_kg: +(p.endKg * (1 - (p.bodyFat - 0.8) / 100)).toFixed(2), source: 'manual' },
  ])

  // GLP-1 shots (weekly), site rotation
  const sites = ['Left Abdomen', 'Right Abdomen', 'Left Thigh', 'Right Thigh']
  const shots = p.shotDaysAgo.map((daysAgo, i) => ({
    user_id: uid, injected_at: iso(at(daysAgo, 9)), medication: p.med, dose_mg: p.doseMg,
    site: sites[i % sites.length], next_due_at: iso(at(daysAgo - 7, 9)),
  }))
  await supa.from('glp1_logs').insert(shots)

  console.log(`  seeded · ${logs.length} food logs · ${weights.length} weights · ${waters.length} water · ${shots.length} shots`)
  await supa.auth.signOut()
}

console.log(`Seeding demo profiles → ${new URL(SUPABASE_URL).host}`)
for (const p of PERSONAS) {
  try { await seedPersona(p) } catch (e) { console.error(`  ✗ ${p.name}: ${e.message}`); process.exitCode = 1 }
}
console.log(`\nDone. Logins (password for both: ${PASSWORD}):`)
for (const p of PERSONAS) console.log(`  · ${p.email}`)
