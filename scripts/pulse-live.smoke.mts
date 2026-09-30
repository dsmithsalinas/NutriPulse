// Live check of Pulse against the real Anthropic API, through the same code coach-chat runs
// (prompts, structured-output schemas, parser, guard). Spends real tokens (about 10 short calls
// on Sonnet 5.5), so it is NOT part of the contract suite. Run before deploying coach-chat:
//   node scripts/pulse-live.smoke.mts
// Reads ANTHROPIC_API_KEY from .env.pulse-eval (gitignored). Never prints the key or full prompts.
import { existsSync } from 'node:fs';
import { buildSystemBlocks, guardFrom, sanitizeContext } from '../supabase/functions/_shared/pulse-context.ts';
import { generatePulse } from '../supabase/functions/_shared/pulse-provider.ts';
import { scenarios } from '../supabase/functions/_shared/pulse-scenarios.ts';

for (const name of ['.env.local', '.env.pulse-eval']) if (existsSync(name)) process.loadEnvFile(name);
const apiKey = process.env.ANTHROPIC_API_KEY ?? '';
if (!apiKey) { console.error('No ANTHROPIC_API_KEY in .env.pulse-eval'); process.exit(1); }

const base = {
  currentDateTime: '2026-09-29T18:30:00-07:00',
  user: { name: 'Sam', weightGoal: 'lose', activityLevel: 'moderately_active' },
  dailyGoals: { calories: 1850, proteinG: 140, carbsG: 180, fatG: 60, fiberG: 28 },
  today: {
    foodLog: [
      { meal: 'breakfast', items: ['Greek yogurt with berries'], calories: 320, proteinG: 30 },
      { meal: 'lunch', items: ['Chicken wrap'], calories: 520, proteinG: 38 },
    ],
    totals: { calories: 840, proteinG: 68, carbsG: 80, fatG: 25, fiberG: 9 },
  },
  sevenDayHistory: {
    daysLogged: 6, avgCalories: 1700, avgProteinG: 118,
    frequentFoods: ['Greek yogurt (5×)', 'Turkey chili (4×)', 'Peanut butter toast (3×)', 'Cottage cheese (3×)', 'Salmon bowl (2×)', 'Protein shake (2×)'],
  },
  glp1: { medication: 'Tirzepatide', doseMg: 5, lastInjected: 'September 26', cycleDay: 3, doseStatus: 'planned',
    skipHistoryAvailable: true, cycleInterrupted: false, scheduledCheckInDue: false },
  aboutYou: { allergies: ['Peanuts'], eatingPatterns: [], loves: ['Greek yogurt'], avoids: ['Salmon'] },
};
const frequentNames = base.sevenDayHistory.frequentFoods.map((f) => f.replace(/\s*\(\d+×\)$/, '').toLowerCase());

type Result = { name: string; ok: boolean; notes: string[]; ms?: number; tokens?: string };
const results: Result[] = [];

async function run(name: string, messageType: string, message: string, context: any, check: (out: any) => string[], model?: string) {
  const safe = sanitizeContext(context);
  try {
    const { output, metadata } = await generatePulse({
      provider: 'claude', apiKey, systemPrompt: buildSystemBlocks(safe, messageType, []),
      messages: [{ role: 'user', content: message }], messageType, model, guard: guardFrom(safe),
    });
    const problems = check(output);
    results.push({ name, ok: problems.every((p) => p.startsWith('warn:')), notes: problems, ms: metadata.latencyMs,
      tokens: `${metadata.inputTokens} in / ${metadata.outputTokens} out, ${metadata.returnedModel}` });
    console.log(`\n── ${name}`);
    console.log(JSON.stringify(output, null, 2).slice(0, 1800));
  } catch (error) {
    results.push({ name, ok: false, notes: [`request failed: ${error instanceof Error ? error.message : String(error)}`] });
  }
}

const mentions = (text: string, word: string) => new RegExp(`\\b${word}`, 'i').test(text);
const chatShape = (out: any) => {
  const p: string[] = [];
  if (typeof out.reply !== 'string' || !out.reply.trim()) p.push('no reply text');
  if (out.recap) p.push('chat carried a recap');
  for (const f of out.followUps ?? []) if (f.trim().endsWith('?')) p.push(`warn: follow-up is a question: "${f}"`);
  return p;
};

await run('chat: dinner idea with an allergy and an avoided food', 'chat', "What's an easy dinner to close my protein tonight?", base, (out) => {
  const p = chatShape(out);
  for (const f of out.foods ?? []) {
    if (!frequentNames.includes(f.name.toLowerCase())) p.push(`food card not from their log: "${f.name}"`);
    if (mentions(f.name, 'peanut') || mentions(f.name, 'salmon')) p.push(`food card names an allergy/avoid: "${f.name}"`);
  }
  if (!(out.foods ?? []).length) p.push('warn: no food cards');
  if (mentions(out.reply ?? '', 'peanut')) p.push('warn: reply mentions peanut; read it');
  if (mentions(out.reply ?? '', 'salmon')) p.push('warn: reply mentions salmon; read it');
  return p;
});

await run('chat: "I can\'t stand cilantro" offers to remember it', 'chat', "Good to know. Honestly I can't stand cilantro, it tastes like soap to me.", base, (out) => {
  const p = chatShape(out);
  if (!(out.remember ?? []).some((r: any) => r.kind === 'avoid' && /cilantro/i.test(r.value))) p.push('no remember avoid: cilantro');
  return p;
});

await run('chat: stated allergy is offered as an allergy', 'chat', "I should mention I'm allergic to shellfish.", base, (out) => {
  const p = chatShape(out);
  if (!(out.remember ?? []).some((r: any) => r.kind === 'allergy' && /shellfish/i.test(r.value))) p.push('no remember allergy: shellfish');
  return p;
});

await run('chat: ordinary message remembers nothing', 'chat', 'Thanks, that helps a lot.', base, (out) => {
  const p = chatShape(out);
  if ((out.remember ?? []).length) p.push(`remembered something unprompted: ${JSON.stringify(out.remember)}`);
  return p;
});

await run('chat: already-saved allergy is not re-offered', 'chat', "Remember, I can't have peanuts.", base, (out) => {
  const p = chatShape(out);
  if ((out.remember ?? []).some((r: any) => /peanut/i.test(r.value))) p.push('re-offered a saved allergy');
  return p;
});

const recapContext = { ...base, lastWeek: {
  range: 'Sep 21 – 27', daysLogged: 6, proteinFloorDays: 3, avgCalories: 1720, avgProteinG: 121, workoutSessions: 3, workoutMinutes: 95,
  frequentFoods: ['Greek yogurt (5×)', 'Turkey chili (4×)'],
  days: [
    { day: 'Mon Sep 21', logged: true, proteinG: 142, proteinFloorHit: true, cycleDay: 2, appetite: 2 },
    { day: 'Tue Sep 22', logged: true, proteinG: 118, proteinFloorHit: false, cycleDay: 3, appetite: 1 },
    { day: 'Wed Sep 23', logged: true, proteinG: 145, proteinFloorHit: true, cycleDay: 4 },
    { day: 'Thu Sep 24', logged: true, proteinG: 141, proteinFloorHit: true, cycleDay: 5, workoutMinutes: 35 },
    { day: 'Fri Sep 25', logged: true, proteinG: 104, proteinFloorHit: false, cycleDay: 6 },
    { day: 'Sat Sep 26', logged: false, cycleDay: 0 },
    { day: 'Sun Sep 27', logged: true, proteinG: 96, proteinFloorHit: false, cycleDay: 1 },
  ],
  priorWeek: { daysLogged: 5, proteinFloorDays: 2, avgProteinG: 112 },
} };
await run('weekly recap returns the four-part card', 'weekly_summary', 'Weekly recap for last week.', recapContext, (out) => {
  const p: string[] = [];
  if (!out.reply?.trim()) p.push('no reply text');
  for (const k of ['story', 'wentWell', 'pattern', 'focus']) if (!out.recap?.[k]?.trim()) p.push(`recap.${k} missing`);
  if (out.foods) p.push('recap carried food cards');
  return p;
});

for (const id of ['steady-full', 'injury-limits-full', 'prompt-injection-full']) {
  const scenario = scenarios.find((s: any) => s.id === id)!;
  await run(`Strong Week outlook on Sonnet 5.5: ${scenario.title}`, 'weekly_outlook', scenario.message, scenario.context, (out) => {
    const p: string[] = [];
    for (const k of ['observation', 'foodFocus', 'movementFocus']) if (!out.outlook?.[k]?.trim()) p.push(`outlook.${k} missing`);
    return p;
  });
}

await run('chat with PULSE_MODEL=claude-sonnet-4-6 still parses', 'chat', 'Quick snack idea?', base, chatShape, 'claude-sonnet-4-6');

console.log('\n════ Results');
for (const r of results) {
  console.log(`${r.ok ? 'PASS' : 'FAIL'}  ${r.name}${r.ms ? `  (${r.ms} ms; ${r.tokens})` : ''}`);
  for (const n of r.notes) console.log(`      ${n}`);
}
const failed = results.filter((r) => !r.ok).length;
console.log(`\n${results.length - failed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
