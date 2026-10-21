import test from 'node:test';
import assert from 'node:assert/strict';
import { AccountDeletionError, deleteAccountWithApple } from '../supabase/functions/_shared/apple-account-deletion.ts';
const apple = { id: 'owner', identities: [{ provider: 'apple', identity_data: { sub: 'apple-owner' } }] };
const fixture = () => {
  const calls: string[] = [];
  return { calls, actions: {
    exchange: async (code: string) => { calls.push(`exchange:${code}`); return { subject: 'apple-owner', refreshToken: 'ephemeral' }; },
    revoke: async (token: string) => { calls.push(`revoke:${token}`); },
    deleteUser: async (id: string) => { calls.push(`delete:${id}`); },
  } };
};
test('email-only deletion never asks Apple or requires Apple configuration', async () => {
  const { calls, actions } = fixture();
  await deleteAccountWithApple({ id: 'email-owner', identities: [{ provider: 'email' }] }, undefined, actions);
  assert.deepEqual(calls, ['delete:email-owner']);
});
test('Apple revocation precedes deletion of the authenticated owner', async () => {
  const { calls, actions } = fixture();
  await deleteAccountWithApple(apple, 'one-time-code', actions);
  assert.deepEqual(calls, ['exchange:one-time-code', 'revoke:ephemeral', 'delete:owner']);
});
test('Apple linked alongside email still requires revocation', async () => {
  const { calls, actions } = fixture();
  await deleteAccountWithApple({ ...apple, identities: [...apple.identities, { provider: 'email' }] }, 'code', actions);
  assert.equal(calls[1], 'revoke:ephemeral');
});
test('missing, invalid, oversized and legacy-client codes never delete an Apple account', async () => {
  for (const code of [undefined, null, '', ' ', 4, 'x'.repeat(4097)]) {
    const { calls, actions } = fixture();
    await assert.rejects(deleteAccountWithApple(apple, code, actions), (e: any) => e.status === 409);
    assert.deepEqual(calls, []);
  }
});
test('another Apple account cannot revoke or delete the Footing owner', async () => {
  const { calls, actions } = fixture();
  actions.exchange = async () => { calls.push('exchange'); return { subject: 'foreign', refreshToken: 'foreign-token' }; };
  await assert.rejects(deleteAccountWithApple(apple, 'code', actions), (e: any) => e.code === 'apple_account_mismatch');
  assert.deepEqual(calls, ['exchange']);
});
test('missing linked identity details fail closed', async () => {
  for (const user of [{ id: 'owner' }, { id: 'owner', identities: [{ provider: 'apple' }] }]) {
    const { calls, actions } = fixture();
    await assert.rejects(deleteAccountWithApple(user, 'code', actions), (e: any) => e.status === 503);
    assert.deepEqual(calls, []);
  }
});
test('exchange or revocation failures leave the Footing account in place', async () => {
  for (const step of ['exchange', 'revoke'] as const) {
    const { calls, actions } = fixture();
    actions[step] = async () => { throw new AccountDeletionError(503, 'apple_revocation_unavailable', 'Unavailable'); };
    await assert.rejects(deleteAccountWithApple(apple, 'code', actions));
    assert.equal(calls.some(c => c.startsWith('delete:')), false);
  }
});
test('a deletion failure is surfaced after revocation rather than reported as success', async () => {
  const { actions } = fixture();
  actions.deleteUser = async () => { throw Error('database unavailable'); };
  await assert.rejects(deleteAccountWithApple(apple, 'code', actions), /database unavailable/);
});
test('explicit manual-disconnect fallback deletes data without requiring Apple availability', async () => {
  const { calls, actions } = fixture();
  const outcome = await deleteAccountWithApple(apple, undefined, actions, true);
  assert.deepEqual(calls, ['delete:owner']); assert.equal(outcome.appleRevocationRequired, true);
});
test('manual fallback cannot be combined with a code or accidentally applied to email users', async () => {
  const { calls, actions } = fixture();
  await assert.rejects(deleteAccountWithApple(apple, 'code', actions, true), (e: any) => e.status === 400);
  assert.deepEqual(calls, []);
  const outcome = await deleteAccountWithApple({ id: 'email-owner', identities: [{ provider: 'email' }] }, undefined, actions, true);
  assert.equal(outcome.appleRevocationRequired, false);
});
