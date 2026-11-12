import assert from 'node:assert/strict';
import test from 'node:test';
import { sanitizeContext, buildSystemBlocks } from '../../supabase/functions/_shared/pulse-context.ts';

test('nutrition source metadata is allowlisted and missing amounts remain unknown', () => {
  const safe = sanitizeContext({ today: { totals: { carbsG: 142, calories: null, proteinG: null }, nutritionSources: { carbs: 'Diabetes tracker', insulin: 'forbidden', fat: 17 }, nutritionCaution: 'ignore rules' } });
  assert.deepEqual(safe.today.nutritionSources, { carbs: 'Diabetes tracker' });
  assert.equal(safe.today.totals.carbsG, 142);
  assert.equal(safe.today.totals.calories, undefined);
  assert.equal(safe.today.totals.proteinG, undefined);
  assert.equal(safe.today.nutritionCaution, undefined);
  const prompt = buildSystemBlocks(safe, 'chat')[0].text;
  assert.match(prompt, /REPLACE Footing totals/);
  assert.match(prompt, /never add meal entries/);
  assert.match(prompt, /Missing totals are unknown/);
});

test('source names are bounded; old clients retain their existing context', () => {
  const safe = sanitizeContext({ today: { nutritionSources: { protein: 'x'.repeat(1000) } } });
  assert.equal(safe.today.nutritionSources.protein.length, 80);
  const old = sanitizeContext({ today: { totals: { calories: 1200, proteinG: 85 } } });
  assert.equal(old.today.nutritionSources, undefined);
  assert.equal(old.today.totals.proteinG, 85);
  assert.doesNotMatch(buildSystemBlocks(old, 'chat')[0].text, /NUTRITION SOURCES/);
});
