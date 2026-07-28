# Deploying footing to tryfooting.app

**Host:** Cloudflare Workers (static assets)
**Domain:** `tryfooting.app`, apex only — registered in the same Cloudflare account, so
DNS is automatic and there are no nameservers to change.

Config lives in [`wrangler.jsonc`](./wrangler.jsonc). Everything below is the part that
can't: dashboard steps, and the one-time cutover.

---

## 1. Connect the repo (once)

Cloudflare dashboard → **Workers & Pages** → **Create** → **Import a repository** →
select `NutriPulse`.

This is a monorepo, so the paths matter:

| Setting | Value |
|---|---|
| Project name | `footing-site` (must match `name` in `wrangler.jsonc`) |
| Root directory | `marketing/site-v2` |
| Build command | `npm ci && npm run build` |
| Deploy command | `npx wrangler deploy` |
| Output directory | leave blank — `wrangler.jsonc` declares `./dist` |

The repo can stay **private**. That's the main practical win over GitHub Pages, where the
custom-domain setup only worked while `NutriPulse` was public.

To deploy from your machine instead: `npx wrangler login`, then `npm run deploy`.

## 2. Attach the apex domain (once)

`wrangler.jsonc` declares `tryfooting.app` as a custom domain, so the first deploy
creates the DNS record and provisions the certificate. Give it a few minutes.

Verify: `curl -sI https://tryfooting.app | head -3` → expect `HTTP/2 200`.

## 3. Redirect www → apex (once, dashboard only)

Not expressible in `wrangler.jsonc`. Cloudflare dashboard → `tryfooting.app` zone →
**Rules** → **Redirect Rules** → **Create rule**:

- **If** — Hostname equals `www.tryfooting.app`
- **Then** — Dynamic redirect, `301`, expression:
  `concat("https://tryfooting.app", http.request.uri.path)`

You also need a proxied DNS record for `www` for the rule to have anything to catch — an
`AAAA` record for `www` pointing at `100::` with the orange cloud on is the standard
placeholder.

**Why a redirect rule and not a second custom domain:** binding `www` to the Worker would
serve the identical site on two hostnames and split canonical URLs, which is an SEO
problem and a cookie-scope problem. The rule runs before the Worker and costs nothing.

## 4. The old GitHub Pages URL

`https://dsmithsalinas.github.io/NutriPulse/` now serves the stubs in
[`marketing/redirect/`](../redirect/), which forward to the new domain. The workflow at
`.github/workflows/deploy-marketing.yml` publishes that folder and nothing else.

**This must not be switched off.** `NutriPulse/Core/Config.swift:37` hardcodes:

```swift
static let privacyPolicyURL = URL(string: "https://dsmithsalinas.github.io/NutriPulse/privacy.html")!
```

App Review fetches that URL, and every build already in TestFlight still points at it.
GitHub Pages can't issue a real `301`, so each stub redirects three ways — `<meta refresh>`,
`rel=canonical`, and `location.replace()` — with a visible link as the last resort, so a
reviewer always lands somewhere real.

### Follow-up for the next app release

Point `Config.swift` at the new domain so future builds skip the hop entirely:

```swift
static let privacyPolicyURL = URL(string: "https://tryfooting.app/privacy.html")!
```

Keep the Pages redirect running afterwards regardless — older builds don't update.

Also worth a decision at the same time: `Config.swift:42` sets `termsOfUseURL` to Apple's
standard EULA, which is a valid Terms of Use for a free app. Now that
`https://tryfooting.app/terms.html` exists, you can point at it instead. Apple's own EULA
is the safer default while the app is free; switch when you add subscriptions, since a
custom EULA is required once money is involved.

---

## Cutover order

1. Deploy to Cloudflare and confirm `https://tryfooting.app` serves the new site.
2. Check `/terms.html`, `/privacy.html`, and a deliberate 404.
3. Add the www redirect rule; confirm `www.tryfooting.app` lands on the apex.
4. Set up `support@tryfooting.app` forwarding — it's the only contact address published
   on the site, in the terms, and in the privacy policy.
5. Merge the redirect stubs so the Pages URLs forward.
6. Verify `https://dsmithsalinas.github.io/NutriPulse/privacy.html` lands on the new
   policy, in a browser and with JavaScript disabled.

Step 6 is the one that protects an App Review submission. Don't skip it.

## Costs

Free tier. Static asset requests aren't billed as Worker invocations, and the Workers free
plan allows 100,000 requests/day — a marketing site won't approach it. The domain
registration is the only recurring cost.
