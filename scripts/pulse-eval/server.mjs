import { createServer } from 'node:http';
import { readFile, writeFile, mkdir, readdir, rename } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';
import { scenarios, DATASET_VERSION } from '../../supabase/functions/_shared/pulse-scenarios.ts';
import { sanitizeContext, buildSystemPrompt } from '../../supabase/functions/_shared/pulse-context.ts';
import { generatePulse, DEFAULT_MODELS } from '../../supabase/functions/_shared/pulse-provider.ts';
import { sha256, assignSides, publicRun, validateRating, costEstimate } from './review.mjs';

const root = fileURLToPath(new URL('../../', import.meta.url));
for (const name of ['.env.local','.env.pulse-eval']) if (existsSync(join(root,name))) process.loadEnvFile(join(root,name));
const directory = process.env.PULSE_EVAL_RESULTS_DIR || join(root,'scripts/pulse-eval/results');
await mkdir(directory,{recursive:true,mode:0o700});
const runs = new Map();
for (const file of await readdir(directory)) if (/^[a-f\d-]+\.json$/.test(file)) {
  const run = JSON.parse(await readFile(join(directory,file),'utf8'));
  if (run.status === 'running') { run.status = 'interrupted'; run.error = 'Server stopped; create a new pair to retry.'; }
  runs.set(run.id,run);
}
let busy = false;
const promptVersion = sha256(await readFile(new URL('../../supabase/functions/_shared/pulse-context.ts',import.meta.url)));
const providerVersion = sha256(await readFile(new URL('../../supabase/functions/_shared/pulse-provider.ts',import.meta.url)));
async function save(run) {
  const path = join(directory,`${run.id}.json`);
  await writeFile(path+'.tmp',JSON.stringify(run,null,2),{mode:0o600});
  await rename(path+'.tmp',path);
}
async function generate(run, scenario) {
  try {
    const systemPrompt = buildSystemPrompt(sanitizeContext(scenario.context), scenario.messageType);
    const results = {};
    // Randomize call order to reduce a systematic first-call timing bias.
    const order = Math.random() < .5 ? ['claude','gpt'] : ['gpt','claude'];
    for (const provider of order) {
      const started = Date.now();
      try {
        let result;
        if (provider === 'claude' && !process.env.ANTHROPIC_API_KEY) {
          const url = new URL(process.env.PULSE_EVAL_URL);
          if (url.protocol !== 'https:' || !url.hostname.endsWith('.supabase.co') || url.pathname !== '/functions/v1/pulse-eval') throw new Error('Invalid evaluation endpoint');
          const response = await fetch(url,{method:'POST',signal:AbortSignal.timeout(75000),headers:{Authorization:`Bearer ${process.env.PULSE_EVAL_TOKEN}`,'Content-Type':'application/json'},
            body:JSON.stringify({scenarioId:scenario.id,promptHash:run.promptHash,datasetVersion:DATASET_VERSION})});
          if (!response.ok) throw new Error(`Claude bridge HTTP ${response.status}`);
          result = await response.json();
          if (result.promptHash !== run.promptHash || result.datasetVersion !== DATASET_VERSION) throw new Error('Evaluation version mismatch');
        } else result = await generatePulse({provider,apiKey:process.env[provider === 'gpt' ? 'OPENAI_API_KEY' : 'ANTHROPIC_API_KEY'],
          model: provider === 'gpt' ? process.env.PULSE_GPT_MODEL : undefined, systemPrompt,
          messages:[{role:'user',content:scenario.message}],messageType:scenario.messageType});
        result.metadata.endToEndMs = Date.now()-started;
        result.metadata.estimatedUsd = costEstimate(result.metadata);
        results[provider] = result;
      } catch (error) {
        // Only our own fixed error messages; never provider response bodies or secrets.
        results[provider] = {error: /^(Provider HTTP \d+|Claude bridge HTTP \d+|Missing provider key|Incomplete model response|Invalid weekly outlook|Evaluation version mismatch)$/.test(error.message) ? error.message : 'Request failed; check server configuration or connectivity.',
          metadata:{provider,requestedModel:provider === 'gpt' ? process.env.PULSE_GPT_MODEL || DEFAULT_MODELS.gpt : DEFAULT_MODELS.claude,endToEndMs:Date.now()-started}};
      }
    }
    run.sides = assignSides(results);
    run.status = Object.values(results).some(r=>r.error) ? 'failed' : 'ready';
  } catch { run.status='failed'; run.error='Evaluation failed.'; }
  finally { await save(run); busy=false; }
}
const port = Number(process.env.PULSE_EVAL_PORT || 4318);
const origin = `http://127.0.0.1:${port}`;
async function body(req) {
  let text=''; for await (const chunk of req) { text+=chunk; if(text.length>12000) throw new Error('Request too large'); }
  return JSON.parse(text);
}
const server = createServer(async(req,res)=>{
  const send=(status,value,type='application/json')=>{res.writeHead(status,{'Content-Type':type,'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Content-Security-Policy':"default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'"});res.end(type==='application/json'?JSON.stringify(value):value);};
  try {
    // Loopback binding + Host/Origin validation prevent remote access and browser CSRF/DNS rebinding.
    if(req.headers.host!==`127.0.0.1:${port}` || (req.headers.origin && req.headers.origin!==origin)) return send(403,{error:'Local access only'});
    if(req.method==='POST' && (req.headers.origin!==origin || !req.headers['content-type']?.startsWith('application/json'))) return send(403,{error:'Same-origin JSON required'});
    const url=new URL(req.url,origin);
    if(req.method==='GET' && ['/','/app.js','/style.css'].includes(url.pathname)) {
      const name={'/':'index.html','/app.js':'app.js','/style.css':'style.css'}[url.pathname];
      return send(200,await readFile(new URL(name,import.meta.url),'utf8'),name.endsWith('html')?'text/html':name.endsWith('js')?'text/javascript':'text/css');
    }
    if(req.method==='GET' && url.pathname==='/api/state') return send(200,{busy,datasetVersion:DATASET_VERSION,models:DEFAULT_MODELS,
      scenarios,runs:[...runs.values()].map(publicRun).reverse(),configured:!!process.env.OPENAI_API_KEY && (!!process.env.ANTHROPIC_API_KEY || !!process.env.PULSE_EVAL_TOKEN)});
    if(req.method==='POST' && url.pathname==='/api/run') {
      if(busy) return send(409,{error:'A comparison is already running.'});
      const input=await body(req), scenario=scenarios.find(s=>s.id===input.scenarioId);
      if(!scenario) return send(400,{error:'Choose a known synthetic scenario.'});
      if(!process.env.OPENAI_API_KEY || (!process.env.ANTHROPIC_API_KEY && (!process.env.PULSE_EVAL_TOKEN || !process.env.PULSE_EVAL_URL))) return send(503,{error:'Provider configuration is incomplete.'});
      const run={id:randomUUID(),createdAt:new Date().toISOString(),scenarioId:scenario.id,scenarioTitle:scenario.title,split:scenario.split,
        datasetVersion:DATASET_VERSION,promptVersion,providerVersion,promptHash:sha256(buildSystemPrompt(sanitizeContext(scenario.context),scenario.messageType)),status:'running'};
      busy=true; runs.set(run.id,run); await save(run); void generate(run,scenario); return send(202,publicRun(run));
    }
    if(req.method==='POST' && url.pathname==='/api/rate') {
      const input=await body(req),run=runs.get(input.runId);
      if(!run || run.status!=='ready') return send(400,{error:'Only completed pairs can be rated.'});
      if(run.rating) return send(409,{error:'Rating is locked after model identities are revealed.'});
      run.rating=validateRating(input); await save(run); return send(200,publicRun(run));
    }
    if(req.method==='GET' && url.pathname==='/api/export') return send(200,{datasetVersion:DATASET_VERSION,runs:[...runs.values()].filter(r=>r.rating)});
    return send(404,{error:'Not found'});
  } catch { return send(400,{error:'Request could not be processed. Check the submitted fields.'}); }
});
server.listen(port,'127.0.0.1',()=>console.log(`Pulse comparison: ${origin}`));
