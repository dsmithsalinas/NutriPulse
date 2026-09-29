import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { request } from 'node:http';

test('local reviewer protects blind mapping, validates browser origin, locks and persists ratings',async()=>{
 const directory=await mkdtemp(join(tmpdir(),'pulse-review-test-'));
 const port=48319,origin=`http://127.0.0.1:${port}`,id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
 const outlook={observation:'Fixture',foodFocus:'Fixture',movementFocus:'Fixture'};
 await writeFile(join(directory,id+'.json'),JSON.stringify({id,status:'ready',scenarioId:'steady-full',scenarioTitle:'Test-only fixture',sides:{A:{output:{outlook},metadata:{provider:'claude'}},B:{output:{outlook},metadata:{provider:'gpt'}}}}));
 const start=async()=>{
  const child=spawn(process.execPath,['scripts/pulse-eval/server.mjs'],{cwd:new URL('../',import.meta.url),env:{...process.env,PULSE_EVAL_PORT:String(port),PULSE_EVAL_RESULTS_DIR:directory},stdio:['ignore','pipe','pipe']});
  await new Promise<void>((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Server startup timeout')),5000);child.stdout.once('data',()=>{clearTimeout(timer);resolve();});child.once('error',reject);child.once('exit',code=>{clearTimeout(timer);if(code)reject(Error('Server failed'));});});return child;
 };
 let child=await start();
 try {
  const state=await (await fetch(origin+'/api/state')).json();assert.equal(state.runs[0].sides.A.metadata,undefined);assert.ok(!JSON.stringify(state).includes('OPENAI_API_KEY'));
  assert.equal((await fetch(origin+'/api/rate',{method:'POST',headers:{Origin:'https://evil.example','Content-Type':'application/json'},body:'{}'})).status,403);
  const badHostStatus=await new Promise(resolve=>{const req=request(origin+'/api/state',{headers:{Host:'evil.example'}},res=>{res.resume();resolve(res.statusCode);});req.end();});
  assert.equal(badHostStatus,403);
  const post=(body:any)=>fetch(origin+'/api/rate',{method:'POST',headers:{Origin:origin,'Content-Type':'application/json'},body:JSON.stringify(body)});
  assert.equal((await post({runId:id,choice:'A'})).status,400);
  const scores=Object.fromEntries(['A','B'].map(side=>[side,Object.fromEntries(['grounding','usefulness','voice','boundaries'].map(key=>[key,4]))]));
  const rating={runId:id,choice:'tie',scores,note:'Automated test fixture, never a human rating'};
  const rated=await (await post(rating)).json();assert.equal(rated.sides.A.metadata.provider,'claude');assert.equal((await post(rating)).status,409);
  assert.equal(JSON.parse(await readFile(join(directory,id+'.json'),'utf8')).rating.choice,'tie');
  child.kill();await once(child,'exit');child=await start();
  const restored=await (await fetch(origin+'/api/state')).json();assert.equal(restored.runs[0].rating.choice,'tie');
  const exported=await (await fetch(origin+'/api/export')).json();assert.equal(exported.runs.length,1);
 } finally {child.kill();await once(child,'exit');await rm(directory,{recursive:true,force:true});}
});
