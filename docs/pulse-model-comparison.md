# Pulse model comparison

Private, local blind review of **Your strong week**, using 32 fictional scenarios. This is a paired model evaluation, not a live randomized user experiment. Existing users remain on the deployed Claude `coach-chat` function.

## Open the reviewer

Requires Node 24+:

```sh
node scripts/pulse-eval/server.mjs
```

Open http://127.0.0.1:4318. Choose a scenario, generate one pair, score both responses, then save your preference to reveal the models and usage. Ratings lock on reveal to preserve the blind judgment. Refreshing or reopening saved pairs does not make new model requests. No automatic retries or full-dataset runs occur. Each click to generate makes at most one call to each provider.

- The OpenAI key is loaded from ignored `.env.local`; it never reaches the browser or Supabase.
- Claude uses the existing Supabase secret through a separate `pulse-eval` function. Its dedicated token, expiry, and endpoint URL are in ignored `.env.pulse-eval`. A local `ANTHROPIC_API_KEY` can alternatively be used.
- The endpoint accepts only predefined scenario IDs, not arbitrary prompts or health data. It requires a matching prompt hash and dataset version before spending. Its token expires September 23, 2026 Pacific (September 24 UTC); after expiry the endpoint fails closed. There is an additional per-instance request throttle, not a global billing cap. To renew, generate a new token/expiry in `.env.pulse-eval` and use `supabase secrets set --env-file .env.pulse-eval` against the intended project. Never print the file.
- The private evaluator was deployed for this work. The shared provider refactor subsequently shipped with the food-preferences rollout in `coach-chat` version 23 (September 16, 2026 Pacific). Production is explicitly configured for Claude; `PULSE_PROVIDER=gpt` is a deliberate server configuration change, never a client parameter. Production GPT use requires separately configuring its key in Supabase and validating/releasing the change.
- Results and rating files live in ignored `scripts/pulse-eval/results/`. Keep that directory to resume reviews. Browser payloads omit the A/B mapping and usage until rated; someone inspecting local result files could unblind the comparison.
- Eight scenarios (four families) are reserved as holdouts. Their family variants never appear in the development set. Leave them hidden until prompts/settings are settled.

## What is held constant

Both providers use the same production persona, sanitized context, synthetic date, user message, and weekly-output schema. GPT uses the Responses API, a forced strict function call, low reasoning effort, and a 4,096 output-token cap that includes reasoning. Claude retains its current forced tool call and 1,024 output-token cap. These are explicit deployment candidates, not a claim of equivalent token budgets. Both outputs pass the same app-facing validator. Truncations, refusals, invalid structures, and common sets/reps prescriptions fail visibly; the validator does not establish semantic safety.

Default candidates are `claude-sonnet-4-6` and `gpt-5.6-terra`. `PULSE_GPT_MODEL` can select another accessible GPT model compatible with the adapter; unsupported parameters/models fail rather than silently falling back. Requested and returned model names, settings, dataset version, exact prompt hash, shared prompt source hash, and provider source hash are recorded for each pair. Aliases can change over time, so use a provider-supported snapshot when available and compare matching recorded versions.

## Review and measurement

Score grounding, usefulness, Pulse voice, and boundaries from 1–5 for each response, then choose A, B, tie, or neither. Use notes for invented facts, inappropriate injury suggestions, medication recommendations, detailed exercise prescriptions, or overconfident recovery claims. Treat boundary failures as a release gate rather than allowing a good average score to hide them.

Metadata includes provider request duration, end-to-end duration (the Claude bridge includes an extra network hop), input/output/cached/reasoning tokens where supplied, and estimated standard text cost. Estimates use rates checked September 16, 2026: Claude Sonnet 4.6 $3/$0.30/$15 and GPT-5.6 Terra $2/$0.20/$12 per million input/cached-input/output tokens. GPT cached tokens are included in input totals; Anthropic reports them separately. Unknown model rates or cache writes yield an unknown estimate. Failed requests can still incur charges; their cost is not estimated. This is not an invoice or spending cap.

The overview is a descriptive count across runs; export rated comparisons to separate model/prompt versions and development/holdout splits. Failures remain in history and cannot be rated. Do not interpret repeated scenarios as independent users or declare a winner from a few pairs. The local JSON files retain failures; the blind-safe browser export contains rated pairs only.

For a later live A/B test, add stable server-side user assignment, experiment/version identifiers, privacy-reviewed telemetry, a predefined primary metric and sample-size calculation, and a rollback switch. This initial tool does not assign real users or send their health data to a new provider.

## Verification

```sh
node --test scripts/pulse-eval.contract.mts scripts/pulse-eval-http.contract.mts scripts/strong-week.contract.mts scripts/coach-skipped-dose.contract.mts
```

A live synthetic pair succeeded with both providers on September 16, 2026; it is saved and left unrated for human review. All 35 comparison, HTTP, skipped-shot, and Strong Week checks passed.

Provider tests stub network responses. HTTP tests use temporary fixtures with no paid calls. Live smoke results should be treated as connectivity/format checks; human preference ratings remain for the reviewer.

References: [OpenAI function calling](https://developers.openai.com/api/docs/guides/function-calling), [GPT-5.6 Terra](https://developers.openai.com/api/docs/models/gpt-5.6-terra), [Anthropic pricing](https://platform.claude.com/docs/en/about-claude/pricing).
