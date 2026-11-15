import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { runInNewContext } from 'node:vm';
const read=(path:string)=>readFileSync(new URL(path,import.meta.url),'utf8').replace(/^import .*\n/gm,'').replace(/export /g,'');
const source=read('../supabase/functions/_shared/membership.ts')+'\n'+read('../supabase/functions/app-store-notifications/index.ts');
const owner='00000000-0000-0000-0000-000000000001';
async function notify(options:{valid?:boolean;test?:boolean;known?:boolean;sandbox?:boolean;approved?:boolean}={}) {
  let handler:any;let reads=0;let refreshes=0;
  runInNewContext(stripTypeScriptTypes(source),{
    Deno:{serve:(fn:any)=>handler=fn,env:{get:()=>options.approved?owner:undefined}},Request,Response,
    appleStore:(environment:string)=>({verifier:{
      verifyAndDecodeNotification:async()=>{
        if(options.valid===false || environment!==(options.sandbox?'Sandbox':'Production'))throw Error('Invalid signature');
        return {notificationType:options.test?'TEST':'DID_RENEW',data:{signedTransactionInfo:'verified-by-test-fixture'}};
      },
      verifyAndDecodeTransaction:async()=>({appAccountToken:owner,originalTransactionId:'original'})
    }}),
    createClient:()=>({from:()=>{reads++;const builder={eq:()=>builder,maybeSingle:async()=>({data:options.known===false?null:{user_id:owner},error:null})};return {select:()=>builder}}}),
    refreshAppleSubscription:async(_admin:any,id:string,user:string,env:string)=>{refreshes++;assert.equal(id,'original');assert.equal(user,owner);assert.equal(env,options.sandbox?'Sandbox':'Production')}
  });
  const response=await handler(new Request('https://example.test/webhook',{method:'POST',body:JSON.stringify({signedPayload:'synthetic'})}));
  return {response,reads,refreshes};
}
test('invalid signatures and Apple test notices never reach membership state',async()=>{
  const invalid=await notify({valid:false});assert.notEqual(invalid.response.status,200);assert.equal(invalid.reads,0);assert.equal(invalid.refreshes,0);
  const ping=await notify({test:true});assert.equal(ping.response.status,200);assert.equal(ping.reads,0);
});
test('known subscription events refresh current Apple status; deleted accounts stay deleted',async()=>{
  const active=await notify();assert.equal(active.response.status,200);assert.equal(active.refreshes,1);
  const deleted=await notify({known:false});assert.equal(deleted.response.status,200);assert.equal(deleted.refreshes,0);
});
test('sandbox webhook requires the same explicit account allowlist as purchase sync',async()=>{
  const denied=await notify({sandbox:true});assert.equal(denied.response.status,400);assert.equal(denied.reads,0);
  const allowed=await notify({sandbox:true,approved:true});assert.equal(allowed.response.status,200);assert.equal(allowed.refreshes,1);
});
