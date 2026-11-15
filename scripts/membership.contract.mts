import test from 'node:test';
import assert from 'node:assert/strict';
import { requireMembership, subscriptionRecord, PREMIUM_PRODUCT, sandboxAccountAllowed, founderAccountConfirmed } from '../supabase/functions/_shared/membership.ts';
const now = Date.now(); const owner = '00000000-0000-0000-0000-000000000001';
const tx = { appAccountToken: owner, bundleId:'com.dustin.nutripulse.app', productId:PREMIUM_PRODUCT,
  originalTransactionId:'original',transactionId:'tx',expiresDate:now+10000,environment:'Production',type:'Auto-Renewable Subscription',inAppOwnershipType:'PURCHASED' };
test('sandbox access requires an explicit account allowlist; empty values never match', () => {
  assert.equal(sandboxAccountAllowed(owner, undefined), false);
  assert.equal(sandboxAccountAllowed('', undefined), false);
  assert.equal(sandboxAccountAllowed(owner, 'another-account'), false);
  assert.equal(sandboxAccountAllowed(owner, ` ${owner.toUpperCase()} `), true);
});
test('unconfirmed auth accounts cannot claim founding access', () => {
  assert.equal(founderAccountConfirmed({}), false);
  assert.equal(founderAccountConfirmed({email_confirmed_at:''}), false);
  assert.equal(founderAccountConfirmed({email_confirmed_at:'2026-11-14T00:00:00Z'}), true);
});
test('only an explicit server allow result grants provider access', async () => {
  for (const data of [null, false, true, {}, 'wrong', 'membership_required','membership_limit_reached']) {
    const result = await requireMembership({rpc:async()=>({data,error:null})},owner,'pulse',true);
    assert.ok(result);
  }
  assert.equal(await requireMembership({rpc:async()=>({data:'allowed',error:null})},owner,'food',true), null);
  assert.ok(await requireMembership({rpc:async()=>({data:'allowed',error:Error()})},owner,'food',true));
  assert.ok(await requireMembership({rpc:async()=>{throw Error()}},owner,'food',true));
});
test('rollout disabled does not spend membership quota', async () => {
  assert.equal(await requireMembership({rpc:async()=>{throw Error('must not call')}},owner,'pulse',false),null);
});
test('signed transaction still needs correct app, product, ownership, type and environment', () => {
  for (const bad of [{appAccountToken:undefined},{appAccountToken:'foreign'},{bundleId:'other'}, {productId:'other'},
    {type:'Non-Consumable'},{environment:'Xcode'},{inAppOwnershipType:'FAMILY_SHARED'},{expiresDate:undefined}]) {
    assert.throws(()=>subscriptionRecord({...tx,...bad},1,undefined,now,now,owner));
  }
  assert.throws(()=>subscriptionRecord(tx,1,undefined,now,now,'00000000-0000-0000-0000-000000000002'));
});
test('billing retry and grace never silently become unlimited premium', () => {
  assert.equal(subscriptionRecord(tx,3,undefined,now,now,owner).p_status,3);
  assert.equal(subscriptionRecord(tx,4,undefined,now,now,owner).p_status,3);
  const grace=subscriptionRecord(tx,4,now+50000,now,now,owner);
  assert.equal(grace.p_expires,new Date(now+50000).toISOString());
  assert.equal(subscriptionRecord({...tx,revocationDate:now},1,undefined,now,now,owner).p_revoked,true);
  assert.equal(subscriptionRecord(tx,5,undefined,now,now,owner).p_revoked,true);
});
