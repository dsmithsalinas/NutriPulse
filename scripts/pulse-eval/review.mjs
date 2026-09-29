import { createHash, randomInt } from 'node:crypto';
export const sha256 = value => createHash('sha256').update(value).digest('hex');
export function costEstimate(meta) {
  // Standard text prices checked 2026-09-16; estimates exclude tax and failed requests.
  const rates = { 'claude-sonnet-4-6': [3, .30, 15], 'gpt-5.6-terra': [2, .20, 12] }[meta.requestedModel];
  if (!rates || meta.inputTokens == null || meta.outputTokens == null || meta.cacheCreationTokens) return null;
  const cached = meta.cachedInputTokens || 0;
  const input = meta.provider === 'gpt' ? Math.max(0, meta.inputTokens - cached) : meta.inputTokens;
  return (input * rates[0] + cached * rates[1] + meta.outputTokens * rates[2]) / 1e6;
}
export function assignSides(results, coin = randomInt(2)) {
  return coin ? { A: results.gpt, B: results.claude } : { A: results.claude, B: results.gpt };
}
export function publicRun(run) {
  const { sides, ...rest } = run;
  if (!sides) return rest;
  return { ...rest, sides: Object.fromEntries(Object.entries(sides).map(([side, value]) => [side,
    run.rating ? value : { output: value.output, error: value.error ? 'Generation failed; this pair cannot be rated.' : undefined }])) };
}
export function validateRating(value) {
  if (!value || !['A','B','tie','neither'].includes(value.choice)) throw new Error('Choose A, B, tie, or neither.');
  const scores = {};
  for (const side of ['A','B']) {
    scores[side] = {};
    for (const key of ['grounding','usefulness','voice','boundaries']) {
      const n = value.scores?.[side]?.[key];
      if (!Number.isInteger(n) || n < 1 || n > 5) throw new Error('Score each dimension from 1 to 5.');
      scores[side][key] = n;
    }
  }
  return { choice: value.choice, scores, note: typeof value.note === 'string' ? value.note.slice(0,2000) : '', ratedAt: new Date().toISOString() };
}
