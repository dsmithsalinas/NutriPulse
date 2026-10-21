import test from 'node:test';
import assert from 'node:assert/strict';
import { requireAIConsent } from '../supabase/functions/_shared/ai-consent.ts';

const owner = 'owner', stamp = '2026-10-20T21:00:00Z';
const read = (data: any, error: any = null) => async () => ({ data, error });

test('Pulse and food parsing require independent explicit grants', async () => {
  const pulse = { user_id: owner, pulse_enabled: true, ai_consent_at: stamp };
  assert.equal(await requireAIConsent(read(pulse), owner, 'pulse'), null);
  assert.equal((await requireAIConsent(read(pulse), owner, 'food'))?.code, 'ai_consent_required');
  const food = { user_id: owner, pulse_enabled: false, food_ai_consent_at: stamp };
  assert.equal(await requireAIConsent(read(food), owner, 'food'), null);
  assert.equal((await requireAIConsent(read(food), owner, 'pulse'))?.code, 'pulse_off');
});
test('missing, revoked, and malformed grants never allow provider use', async () => {
  for (const use of ['pulse', 'food'] as const) {
    for (const value of [undefined, null, '', 'invalid']) {
      const data = { user_id: owner, pulse_enabled: true, ai_consent_at: value, food_ai_consent_at: value };
      assert.equal((await requireAIConsent(read(data), owner, use))?.status, 403);
    }
    assert.equal((await requireAIConsent(read(null), owner, use))?.status, 403);
  }
});
test('database failure, absent migration, and foreign owners fail closed', async () => {
  for (const use of ['pulse', 'food'] as const) {
    assert.equal((await requireAIConsent(read(null, { code: '42703' }), owner, use))?.status, 503);
    assert.equal((await requireAIConsent(async () => { throw Error('network'); }, owner, use))?.status, 503);
    assert.equal((await requireAIConsent(read({ user_id: 'other', ai_consent_at: stamp, food_ai_consent_at: stamp }), owner, use))?.status, 503);
  }
});
