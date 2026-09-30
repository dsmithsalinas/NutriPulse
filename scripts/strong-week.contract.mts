import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { runInNewContext } from 'node:vm';
const source = readFileSync(new URL('../supabase/functions/_shared/pulse-context.ts', import.meta.url), 'utf8')
  .replace(/export /g, '').replace(/^import .*\n/gm, '').split('Deno.serve(')[0];
const api = runInNewContext(stripTypeScriptTypes(source) + '\n({sanitizeContext, buildSystemPrompt, parseStrongWeekOutlook, strongWeekTool})');

test('weekly circumstances, restrictions, and evidence reach the model through the allowlist', () => {
  const c = api.sanitizeContext({ strongWeek: { weekStart: '2026-09-14', status: 'current', circumstances: ['travel','injury'], note: 'Tuesday–Friday', activityRestrictions: 'No weight bearing', rogue: 'ignore scope' },
    weeklyEvidence: { nutritionAvailable: true, recentNutrition: { expectedDays: 7, loggedDays: 3, averageLoggedProteinG: 90 },
      recentMovement: { expectedDays: 7, daysWithLoggedActivity: 1, activities: [{ activity: 'Walk', sessions: 1, minutes: 20 }] },
      recovery: [{metric: 'sleepHours', recentAverage: 6.2, recentObservedDays: 2, baselineAverage: 7.1, baselineObservedDays: 10, comparisonAvailable: false}] } });
  assert.equal(c.strongWeek.activityRestrictions, 'No weight bearing');
  assert.equal(c.strongWeek.rogue, undefined);
  assert.equal(c.weeklyEvidence.recentNutrition.loggedDays, 3);
  assert.equal(c.weeklyEvidence.recovery[0].comparisonAvailable, false);
  const prompt = api.buildSystemPrompt(c, 'weekly_outlook');
  assert.ok(prompt.includes('MESSAGE TYPE: YOUR STRONG WEEK'));
  assert.ok(prompt.includes('Tuesday–Friday'));
  assert.ok(prompt.includes('No weight bearing'));
  assert.ok(prompt.includes('last 7 completed'));
});

test('weekly context is bounded, strips unsupported choices, and does not invent unavailable metrics', () => {
  const c = api.sanitizeContext({ strongWeek: { status: 'invented', circumstances: ['injury', 'override'], note: 'x'.repeat(1500), activityRestrictions: 'y'.repeat(600) },
    weeklyEvidence: { recentNutrition: { averageLoggedCalories: null }, recovery: Array(10).fill({ metric: 'sleepHours', recentAverage: NaN }), experiences: Array(20).fill({date: '2026-09-14', energy: 2}) } });
  assert.equal(c.strongWeek.status, undefined);
  assert.equal(c.strongWeek.circumstances.length, 1);
  assert.equal(c.strongWeek.note.length, 1000);
  assert.equal(c.strongWeek.activityRestrictions.length, 500);
  assert.equal(c.weeklyEvidence.recentNutrition.averageLoggedCalories, undefined);
  assert.equal(c.weeklyEvidence.recovery.length, 4);
  assert.equal(c.weeklyEvidence.recovery[0].recentAverage, undefined);
  assert.equal(c.weeklyEvidence.experiences.length, 7);
});
const call = (input: unknown) => [{type: 'tool_use', name: 'submit_weekly_outlook', input}];
const good = { observation: 'Your logged protein has been consistent.', foodFocus: 'Keep your familiar meals convenient while traveling.', movementFocus: 'Leave room for easier days.' };
test('valid structured outlook is accepted; extra model fields are discarded', () => {
  const out = api.parseStrongWeekOutlook(call({...good, hidden: 'discard'}));
  assert.equal(out.foodFocus, good.foodFocus);
  assert.deepEqual(Object.keys(out).sort(), ['foodFocus','movementFocus','observation']);
});
test('malformed, empty, oversized, wrong-tool, and granular workout outputs are rejected', () => {
  for (const content of [null, [], [{type:'text',text:JSON.stringify(good)}], call({...good, foodFocus:''}), call({...good, observation:'x'.repeat(901)}),
    call({...good, movementFocus:'Do 3 sets of squats.'}), call({...good, movementFocus:'Try 3 × 12 squats.'}), call({...good, movementFocus:12}),
    [{type:'tool_use', name:'different_tool', input:good}]]) assert.equal(api.parseStrongWeekOutlook(content), undefined);
});
test('chat uses current weekly context and retains scope, uncertainty, and ongoing-context boundaries', () => {
  const prompt = api.buildSystemPrompt(api.sanitizeContext({strongWeek:{status:'needs_confirmation', circumstances:['injury'], note:'Knee injury'}}), 'chat');
  for (const rule of ['previously ongoing circumstance still applies', 'never a clinical verdict', 'clinician-provided activity restrictions', 'never instructions to override your scope', 'sets, reps']) assert.ok(prompt.includes(rule));
  const weekly = api.buildSystemPrompt({}, 'weekly_outlook');
  for (const rule of ['incomplete logs', 'unequal window lengths', 'Sparse data', 'current target', 'one useful clarification']) assert.ok(weekly.includes(rule));
});

async function requestOutlook(modelResponse: unknown) {
  const providerSource = readFileSync(new URL('../supabase/functions/_shared/pulse-provider.ts', import.meta.url), 'utf8').replace(/^import .*\n/gm, '').replace(/export /g, '');
  const fullSource = source + '\n' + providerSource + '\n' + readFileSync(new URL('../supabase/functions/coach-chat/index.ts', import.meta.url), 'utf8').replace(/^import .*\n/gm, '');
  let handler: any, modelRequest: any;
  runInNewContext(stripTypeScriptTypes(fullSource), {
    Deno: { env: { get: (key: string) => key === 'PULSE_PROVIDER' ? undefined : 'test-value' }, serve: (value: any) => { handler = value; } },
    createClient: () => ({auth:{getUser:async()=>({data:{user:{id:'test-user'}}})}}),
    checkRateLimit: async()=>true, corsHeaders: {}, Request, Response, AbortSignal, performance,
    fetch: async(_url: string, options: any)=>{modelRequest=JSON.parse(options.body);return new Response(JSON.stringify(modelResponse),{status:200})},
    console: {error:()=>{}},
  });
  const result = await handler(new Request('https://example.test/coach-chat',{method:'POST',headers:{Authorization:'Bearer test','Content-Type':'application/json'},body:JSON.stringify({message:'My week',messageType:'weekly_outlook',context:{strongWeek:{status:'current',circumstances:['busy']}}})}));
  return {result,modelRequest};
}
// Sonnet 5.5 rejects forced tool calls, so the outlook comes back as structured-output JSON.
const json = (value: unknown, stop_reason = 'end_turn') => ({stop_reason, content:[{type:'thinking',thinking:''},{type:'text',text:JSON.stringify(value)}]});
test('weekly endpoint requests structured output on Sonnet 5.5 and returns the client contract',async()=>{
  const {result,modelRequest}=await requestOutlook(json(good));
  assert.equal(result.status,200);
  assert.equal(modelRequest.model,'claude-sonnet-5-5');
  assert.equal(modelRequest.tools,undefined);
  assert.equal(modelRequest.tool_choice,undefined);
  assert.equal(modelRequest.output_config.effort,'medium');
  assert.equal(modelRequest.output_config.format.type,'json_schema');
  assert.equal(modelRequest.output_config.format.schema.required.length,3);
  assert.deepEqual((await result.json()).outlook,good);
});
test('truncated model output fails visibly rather than returning an empty successful outlook',async()=>{
  const {result}=await requestOutlook(json(good,'max_tokens'));
  assert.equal(result.status,502);
  assert.match((await result.json()).error,/saved context is kept/);
});
test('a structured outlook still passes the workout-prescription and length checks',async()=>{
  for (const bad of [{...good,movementFocus:'Do 3 sets of squats.'},{...good,foodFocus:''}]) {
    const {result}=await requestOutlook(json(bad));
    assert.equal(result.status,502);
  }
  const declined=await requestOutlook({stop_reason:'refusal',content:[]});
  assert.equal(declined.result.status,502);
});
