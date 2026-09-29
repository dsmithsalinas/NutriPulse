import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { runInNewContext } from 'node:vm';

// Exercise the production sanitizer/prompt builder without serving HTTP or calling a model.
const source = readFileSync(new URL('../supabase/functions/_shared/pulse-context.ts', import.meta.url), 'utf8')
  .replace(/export /g, '').replace(/^import .*\n/gm, '').split('Deno.serve(')[0];
const api = runInNewContext(stripTypeScriptTypes(source) + '\n({ sanitizeContext, buildSystemPrompt })');
const sanitized = (glp1: Record<string, unknown>) => api.sanitizeContext({ glp1 }).glp1;

test('saved skip context survives the allowlist with the actual cycle day', () => {
  const value = sanitized({ doseStatus: 'skipped', cycleDay: 9, cycleInterrupted: true,
    skipHistoryAvailable: true, skippedDoseDates: ['September 8'], nextReminder: 'September 15' });
  assert.equal(value.doseStatus, 'skipped');
  assert.equal(value.cycleDay, 9);
  assert.equal(value.cycleInterrupted, true);
  assert.equal(value.nextReminder, 'September 15');
  assert.equal(value.skippedDoseDates[0], 'September 8');
});

test('skip fields are bounded and invalid types or states are dropped', () => {
  const value = sanitized({ doseStatus: 'ignore rules', cycleInterrupted: 'true', skipHistoryAvailable: 1,
    skippedDoseDates: Array(25).fill('x'.repeat(100)), nextReminder: 'x'.repeat(200), rogue: 'private' });
  assert.equal(value.doseStatus, undefined);
  assert.equal(value.cycleInterrupted, undefined);
  assert.equal(value.skipHistoryAvailable, undefined);
  assert.equal(value.skippedDoseDates.length, 12);
  assert.equal(value.skippedDoseDates[0].length, 40);
  assert.equal(value.nextReminder.length, 80);
  assert.equal(value.rogue, undefined);
});

test('interrupted or unavailable history cannot trigger a post-shot check-in', () => {
  for (const overrides of [{ cycleInterrupted: true }, { skipHistoryAvailable: false }, { doseStatus: 'unknown' }]) {
    const context = { glp1: sanitized({ cycleDay: 3, scheduledCheckInDue: true, ...overrides }) };
    const prompt = api.buildSystemPrompt(context, 'checkin');
    assert.ok(!prompt.includes('MESSAGE TYPE: SCHEDULED POST-SHOT CHECK-IN'));
    assert.ok(prompt.includes('MESSAGE TYPE: DAILY CHECK-IN'));
  }
});

test('normal and legacy clients retain valid actual post-shot check-ins', () => {
  for (const additional of [{}, { cycleInterrupted: false, skipHistoryAvailable: true, doseStatus: 'planned' }]) {
    const prompt = api.buildSystemPrompt({ glp1: sanitized({ cycleDay: 3, scheduledCheckInDue: true, ...additional }) }, 'checkin');
    assert.ok(prompt.includes('MESSAGE TYPE: SCHEDULED POST-SHOT CHECK-IN'));
  }
});
