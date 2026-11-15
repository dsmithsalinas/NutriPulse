import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { runInNewContext } from 'node:vm';
const read = (path: string) => readFileSync(new URL(path, import.meta.url),'utf8').replace(/^import .*\n/gm,'').replace(/export /g,'');
const shared = read('../supabase/functions/_shared/membership.ts');
const owner = '00000000-0000-0000-0000-000000000001';
async function request(body: unknown, options: { confirmed?: boolean; authenticated?: boolean; enabled?: boolean; sandbox?: boolean; parseFood?: boolean } = {}) {
  let handler: any; const calls: any[] = []; let appleCalls = 0; let providerCalls = 0;
  const source = shared + '\n' + (options.parseFood ? read('../supabase/functions/_shared/ai-consent.ts')+'\n'+read('../supabase/functions/parse-food/index.ts') : read('../supabase/functions/membership/index.ts'));
  runInNewContext(stripTypeScriptTypes(source), {
    Request, Response, Date, AbortSignal, console: {error:()=>{}},
    Deno: {serve:(fn:any)=>handler=fn, env:{get:(key:string)=> key==='MEMBERSHIP_ENFORCED' ? String(options.enabled !== false) : key==='APP_STORE_SANDBOX_USER_IDS'&&options.sandbox ? owner : 'test'}},
    createClient:()=>({
      auth:{getUser:async()=>({data:{user:options.authenticated===false?null:{id:owner,email_confirmed_at:options.confirmed===false?undefined:'2026-11-14T00:00:00Z'}}})},
      rpc:async(name:string,args:any)=>{calls.push({name,args});return {data:name==='reserve_membership_ai'?'membership_required':{user_id:owner},error:null}},
      from:()=>({select:()=>({eq:()=>({data:[],error:null,maybeSingle:async()=>({data:{user_id:owner,food_ai_consent_at:'2026-11-14T00:00:00Z'},error:null})})})}),
    }),
    checkRateLimit:async()=>true,corsHeaders:{},
    refreshAppleSubscription:async(...args:any[])=>{appleCalls++;assert.equal(args[2],owner)},
    fetch:async()=>{providerCalls++;throw Error('Provider must not be called')},
  });
  const response = await handler(new Request('https://example.test/membership',{method:'POST',headers:{Authorization:'Bearer synthetic'},body:JSON.stringify(body)}));
  return {response,calls,appleCalls,providerCalls};
}
test('unauthenticated, unconfirmed and prelaunch claims cannot reach privileged RPCs',async()=>{
  for (const [options,status] of [[{authenticated:false},401],[{confirmed:false},403],[{enabled:false},409]] as const) {
    const result=await request({action:'claim'},options);
    assert.equal(result.response.status,status);assert.equal(result.calls.length,0);
  }
});
test('claim uses the authenticated owner, ignoring a caller-supplied account ID',async()=>{
  const result=await request({action:'claim',userId:'attacker-selected'});
  assert.equal(result.response.status,200);
  assert.equal(result.calls[0].name,'claim_founding_membership');
  assert.equal(result.calls[0].args.p_user_id,owner);
  assert.equal((await result.response.json()).user_id,owner);
});
test('sandbox and local-Xcode transactions cannot grant arbitrary production users access',async()=>{
  for (const environment of ['Sandbox','Xcode',null]) {
    const result=await request({action:'sync',transactionId:'123',environment});
    assert.equal(result.response.status,403);assert.equal(result.appleCalls,0);
  }
  const approved=await request({action:'sync',transactionId:'123',environment:'Sandbox'},{sandbox:true});
  assert.equal(approved.response.status,200);assert.equal(approved.appleCalls,1);
});
test('food parsing rejects unpaid requests before AI or nutrition-provider calls',async()=>{
  const result=await request({text:'fictional meal'},{parseFood:true});
  assert.equal(result.response.status,402);
  assert.equal(result.providerCalls,0);
  assert.equal(result.calls[0].args.p_bucket,'food');
});

test('prelaunch enforcement applies only to allowlisted sandbox accounts without opening claims',async()=>{
  const beta=await request({action:'status'},{enabled:false});
  assert.equal((await beta.response.json()).enforced,false);
  const tester=await request({action:'status'},{enabled:false,sandbox:true});
  assert.equal((await tester.response.json()).enforced,true);
  const claim=await request({action:'claim'},{enabled:false,sandbox:true});
  assert.equal(claim.response.status,409); assert.equal(claim.calls.length,0);
  const food=await request({text:'fictional meal'},{enabled:false,sandbox:true,parseFood:true});
  assert.equal(food.response.status,402); assert.equal(food.providerCalls,0);
});
