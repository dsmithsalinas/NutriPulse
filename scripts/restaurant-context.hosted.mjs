// Opt-in hosted integration check. Requires a mode-0600 keys.json in the private fixture directory.
// Creates only a synthetic account and removes it in finally; never prints credentials.
import fs from 'node:fs'; import crypto from 'node:crypto'; import assert from 'node:assert/strict';
const root=process.env.FOOTING_RESTAURANT_FIXTURE_DIR ?? '/private/tmp/footing-restaurant-e2e'; const keys=JSON.parse(fs.readFileSync(root+'/keys.json')); const anon=keys.find(x=>x.name==='anon').api_key; const admin=keys.find(x=>x.name==='service_role').api_key; const base='https://dcabdzuhuixlcgwavtsc.supabase.co';
async function call(path,key,token,body,method='POST'){ const r=await fetch(base+path,{method,headers:{apikey:key,Authorization:'Bearer '+token,'Content-Type':'application/json',Prefer:'resolution=merge-duplicates'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(110000)}); const text=await r.text(); let data;try{data=JSON.parse(text)}catch{data=text};return {status:r.status,data}; }
let id; const results={};
try {
 const email='footing-restaurant-e2e-'+Date.now()+'@example.invalid',password=crypto.randomBytes(24).toString('base64url');
 const created=await call('/auth/v1/admin/users',admin,admin,{email,password,email_confirm:true}); assert.equal(created.status,200); id=created.data.id;
 const auth=await call('/auth/v1/token?grant_type=password',anon,anon,{email,password});assert.equal(auth.status,200); const token=auth.data.access_token;
 const request={schemaVersion:2,draftId:'hosted-restaurant-qa',draftRevision:1,text:'chipotle chicken',compositionConfirmed:false};
 results.denied=await call('/functions/v1/parse-food',anon,token,request); assert.equal(results.denied.status,403);
 const consent=await call('/rest/v1/pulse_profiles',admin,admin,{user_id:id,food_ai_consent_at:new Date().toISOString()});assert.ok(consent.status<300);
 results.ambiguous=await call('/functions/v1/parse-food',anon,token,request);assert.equal(results.ambiguous.status,200);assert.equal(results.ambiguous.data.status,'needs_restaurant');
 results.search=await call('/functions/v1/search-food',anon,token,{query:'chicken',restaurant:'Chipotle'});assert.equal(results.search.status,200);assert.ok(results.search.data.results.length);assert.ok(results.search.data.results.every(x=>['restaurant','generic'].includes(x.matchKind)));
 results.checklist=await call('/functions/v1/parse-food',anon,token,{...request,text:'A chicken bowl from Chipotle with brown rice, black beans and no cheese'});assert.equal(results.checklist.status,200);assert.equal(results.checklist.data.status,'needs_ingredients');
 const ingredients=results.checklist.data.dishes.flatMap(x=>x.ingredients);assert.ok(ingredients.some(x=>/cheese/i.test(x.name)&&x.state==='excluded'));assert.equal(ingredients.filter(x=>x.state==='included').length,3);
 results.resolved=await call('/functions/v1/parse-food',anon,token,{...request,text:'A chicken bowl from Chipotle with brown rice, black beans and no cheese',restaurant:results.checklist.data.restaurant,compositionConfirmed:true,dishes:results.checklist.data.dishes});assert.equal(results.resolved.status,200);assert.equal(results.resolved.data.status,'ready');assert.equal(results.resolved.data.items.length,3);assert.ok(results.resolved.data.items.every(x=>x.servingDesc&&['restaurant','generic','estimated'].includes(x.matchKind)));
 results.legacy=await call('/functions/v1/parse-food',anon,token,{text:'One boiled egg'});assert.equal(results.legacy.status,200);assert.ok(Array.isArray(results.legacy.data.items));
 results.roadhouse=await call('/functions/v1/parse-food',anon,token,{...request,text:'A six ounce sirloin steak from Texas Roadhouse'});assert.equal(results.roadhouse.status,200);assert.equal(results.roadhouse.data.restaurant.name,'Texas Roadhouse');assert.equal(results.roadhouse.data.status,'ready');assert.equal(results.roadhouse.data.items[0].quantity,1);
 console.log('Hosted checks passed: consent, ambiguity, scoped search, explicit inclusions/exclusion, ingredient resolution, legacy client, Texas Roadhouse.');
} finally {
 fs.writeFileSync(root+'/results.json',JSON.stringify(results,null,2));
 if(id){const deleted=await call('/auth/v1/admin/users/'+id,admin,admin,undefined,'DELETE');assert.equal(deleted.status,200);console.log('Disposable account removed.');}
}
