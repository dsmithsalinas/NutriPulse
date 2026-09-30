import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { runInNewContext } from 'node:vm';

// Runs coach-chat with its shared modules against a stubbed model, like strong-week.contract.mts.
const read = (path: string) => readFileSync(new URL(path, import.meta.url), 'utf8').replace(/^import .*\n/gm, '').replace(/export /g, '');
const fullSource = read('../supabase/functions/_shared/pulse-context.ts') + '\n' +
  read('../supabase/functions/_shared/pulse-provider.ts') + '\n' + read('../supabase/functions/coach-chat/index.ts');

async function send(body: Record<string, unknown>, modelResponse: unknown, env: Record<string, string> = {}) {
  let handler: any, modelRequest: any;
  runInNewContext(stripTypeScriptTypes(fullSource), {
    Deno: { env: { get: (key: string) => key in env ? env[key] : key === 'ANTHROPIC_API_KEY' ? 'test-key' : undefined }, serve: (value: any) => { handler = value; } },
    createClient: () => ({ auth: { getUser: async () => ({ data: { user: { id: 'test-user' } } }) } }),
    checkRateLimit: async () => true, corsHeaders: {}, Request, Response, AbortSignal, performance,
    fetch: async (_url: string, options: any) => { modelRequest = JSON.parse(options.body); return new Response(JSON.stringify(modelResponse), { status: 200 }); },
    console: { error: () => {} },
  });
  const result = await handler(new Request('https://example.test/coach-chat', { method: 'POST', headers: { Authorization: 'Bearer test', 'Content-Type': 'application/json' }, body: JSON.stringify(body) }));
  return { result, modelRequest };
}
// Structured outputs: the model's text block is the JSON reply.
const structured = (value: unknown) => ({ stop_reason: 'end_turn', content: [{ type: 'thinking', thinking: '' }, { type: 'text', text: JSON.stringify(value) }] });
const reply = (text: string) => structured({ reply: text, foods: [], followUps: [] });

test('chat uses the chat model with effort, and caches only the user-independent system block', async () => {
  const { result, modelRequest } = await send({ message: 'Hi', messageType: 'chat', context: { user: { name: 'Sam' } } }, reply('Hello.'));
  assert.equal(result.status, 200);
  assert.deepEqual(await result.json(), { reply: 'Hello.' });
  assert.equal(modelRequest.model, 'claude-sonnet-5-5');
  assert.equal(modelRequest.output_config.effort, 'low');
  assert.equal(modelRequest.system.length, 2);
  assert.deepEqual(modelRequest.system[0].cache_control, { type: 'ephemeral' });
  assert.ok(!modelRequest.system[0].text.includes('Sam'));
  assert.equal(modelRequest.system[1].cache_control, undefined);
  assert.ok(modelRequest.system[1].text.includes('Sam'));
});

test('PULSE_MODEL overrides chat but never the Strong Week outlook', async () => {
  const chat = await send({ message: 'Hi', messageType: 'chat' }, reply('Hello.'), { PULSE_MODEL: 'claude-sonnet-4-6' });
  assert.equal(chat.modelRequest.model, 'claude-sonnet-4-6');
  const weekly = await send({ message: 'My week', messageType: 'weekly_outlook' }, structured({}), { PULSE_MODEL: 'claude-sonnet-4-6' });
  assert.equal(weekly.modelRequest.model, 'claude-sonnet-5-5');
});

test('every Claude request asks for the structured reply for its message type', async () => {
  const chat = await send({ message: 'Hi', messageType: 'chat' }, reply('Hello.'));
  assert.equal(chat.modelRequest.output_config.format.type, 'json_schema');
  assert.deepEqual(chat.modelRequest.output_config.format.schema.required, ['reply', 'foods', 'followUps']);
  assert.equal(chat.modelRequest.tools, undefined);
  const recap = await send({ message: 'Weekly recap for last week.', messageType: 'weekly_summary' }, reply('Recap.'));
  assert.deepEqual(recap.modelRequest.output_config.format.schema.required, ['reply', 'recap', 'followUps']);
});

test('food cards and follow-ups come back clamped for the app', async () => {
  const { result } = await send({ message: 'Dinner idea?', messageType: 'chat' }, structured({
    reply: 'Turkey chili gets you there.',
    foods: [{ name: 'Turkey chili (3×)', why: '31g, reheats fast' }, { name: '  ', why: 'x' }, { name: 'Cottage cheese', why: '14g' },
      { name: 'Protein shake', why: '30g' }, { name: 'Salmon bowl', why: 'extra' }],
    followUps: ['Give me a lighter version', '', 'Make it vegetarian', 'One more', 'Too many'],
  }));
  assert.equal(result.status, 200);
  const body = await result.json();
  assert.equal(body.reply, 'Turkey chili gets you there.');
  assert.deepEqual(body.foods.map((f: any) => f.name), ['Turkey chili', 'Cottage cheese', 'Protein shake']);
  assert.deepEqual(body.followUps, ['Give me a lighter version', 'Make it vegetarian', 'One more']);
  assert.equal(body.recap, undefined);
});

test('the weekly recap returns its card, and a chat never carries one', async () => {
  const card = { story: 'Protein held until the weekend.', wentWell: 'Yogurt breakfasts, five days.', pattern: 'Shot days ran light.', focus: 'Stage a shake for Tuesday.' };
  const recap = await send({ message: 'Weekly recap for last week.', messageType: 'weekly_summary' }, structured({ reply: 'A steady week.', recap: card, followUps: [] }));
  assert.deepEqual((await recap.result.json()).recap, card);
  const chat = await send({ message: 'Hi', messageType: 'chat' }, structured({ reply: 'Hi.', recap: card, foods: [], followUps: [] }));
  assert.equal((await chat.result.json()).recap, undefined);
  // A partial card is dropped rather than rendered with holes; the reply still stands.
  const partial = await send({ message: 'Weekly recap for last week.', messageType: 'weekly_summary' }, structured({ reply: 'A steady week.', recap: { ...card, focus: '' }, followUps: [] }));
  assert.deepEqual(await partial.result.json(), { reply: 'A steady week.' });
});

test('plain text from a model without structured outputs still reads as a reply', async () => {
  const { result } = await send({ message: 'Hi', messageType: 'chat' }, { stop_reason: 'end_turn', content: [{ type: 'text', text: 'Hello there.' }] });
  assert.deepEqual(await result.json(), { reply: 'Hello there.' });
});

test('truncated structured output fails visibly', async () => {
  const { result } = await send({ message: 'Hi', messageType: 'chat' }, { stop_reason: 'max_tokens', content: [{ type: 'text', text: '{"reply":"Hel' }] });
  assert.equal(result.status, 502);
});

test('the weekly summary reasons more than chat', async () => {
  const { modelRequest } = await send({ message: 'Weekly recap for last week.', messageType: 'weekly_summary' }, reply('Recap.'));
  assert.equal(modelRequest.output_config.effort, 'medium');
  assert.ok(modelRequest.system[0].text.includes('WEEKLY RECAP'));
});

test('leading check-ins become recent Pulse messages instead of being dropped', async () => {
  const history = [
    { role: 'assistant', content: 'Yogurt carried breakfast again.' },
    { role: 'assistant', content: 'Salmon bowl did the heavy lifting.' },
  ];
  const { modelRequest } = await send({ message: 'Morning check-in.', messageType: 'checkin', history }, reply('New angle.'));
  assert.deepEqual(modelRequest.messages, [{ role: 'user', content: 'Morning check-in.' }]);
  const dynamic = modelRequest.system[1].text;
  assert.ok(dynamic.includes('RECENT PULSE MESSAGES'));
  assert.ok(dynamic.includes('Yogurt carried breakfast again.'));
  assert.ok(dynamic.includes('Salmon bowl did the heavy lifting.'));
});

test('conversation history after the first user turn is kept as messages', async () => {
  const history = [
    { role: 'assistant', content: 'Check-in text.' },
    { role: 'user', content: 'What should I eat?' },
    { role: 'assistant', content: 'A wrap.' },
  ];
  const { modelRequest } = await send({ message: 'Thanks', messageType: 'chat', history }, reply('Anytime.'));
  assert.deepEqual(modelRequest.messages.map((m: any) => m.role), ['user', 'assistant', 'user']);
  assert.ok(modelRequest.system[1].text.includes('Check-in text.'));
});

test('a declined chat gets the scope redirect; a declined check-in fails instead', async () => {
  const chat = await send({ message: 'Question', messageType: 'chat' }, { stop_reason: 'refusal', content: [] });
  assert.equal(chat.result.status, 200);
  assert.match((await chat.result.json()).reply, /doctor or pharmacist/);
  const checkin = await send({ message: 'Morning check-in.', messageType: 'checkin' }, { stop_reason: 'refusal', content: [] });
  assert.equal(checkin.result.status, 502);
});

test('weekly summary context reaches the prompt through the allowlist', async () => {
  const context = { sevenDayHistory: { frequentFoods: ['Greek yogurt (4×)'] }, lastWeek: { range: 'Sep 21 – 27', daysLogged: 5, rogue: 'drop me', days: [{ day: 'Mon Sep 21', logged: true, proteinG: 140, proteinFloorHit: true, injected: 'x' }], priorWeek: { daysLogged: 3 } } };
  const { modelRequest } = await send({ message: 'Weekly recap for last week.', messageType: 'weekly_summary', context }, reply('Recap.'));
  const dynamic = modelRequest.system[1].text;
  assert.ok(dynamic.includes('Greek yogurt (4×)'));
  assert.ok(dynamic.includes('Sep 21 – 27'));
  assert.ok(!dynamic.includes('drop me'));
  assert.ok(!dynamic.includes('injected'));
});
