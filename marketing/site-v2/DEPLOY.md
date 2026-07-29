# Deploying footing to tryfooting.app

**Host:** Cloudflare Workers (static assets)
**Domain:** `tryfooting.app`, apex only — registered in the same Cloudflare account, so
DNS is automatic and there are no nameservers to change.

Config lives in [`wrangler.jsonc`](./wrangler.jsonc). Everything below is the part that
can't: dashboard steps, and the one-time cutover.

---

## 1. First deploy — from the CLI

Do this before wiring up git. It creates the Worker, uploads `dist/`, and attaches the
apex domain in one step, using the config in this repo rather than dashboard fields you
have to keep in sync by hand.

```bash
cd marketing/site-v2
npx wrangler login     # opens a browser, asks you to authorise Wrangler
npm run deploy         # builds, then deploys
```

`wrangler login` is an interactive OAuth flow — it has to be run by you, in your own
terminal, on a machine with a browser.

First deploy with a `custom_domain` route also provisions the TLS certificate for
`tryfooting.app`, which can take a few minutes. Until it finishes you may see a
certificate warning; that resolves on its own.

## 1b. Connect git for automatic deploys (optional, after the first deploy)

Cloudflare dashboard → **Workers & Pages** → select **footing-site** → **Settings** →
**Builds** → **Connect**, then pick the `NutriPulse` repo.

| Setting | Value |
|---|---|
| Root directory | `marketing/site-v2` |
| Build command | `npm ci && npm run build` |
| Deploy command | `npx wrangler deploy` (the default — leave it) |
| Non-production branch deploy command | `npx wrangler versions upload` (the default) |

Two things that break builds if you get them wrong:

- **The Worker name in the dashboard must match `name` in `wrangler.jsonc`** — both
  `footing-site`. Cloudflare fails the build rather than creating a second Worker.
- **Do not set the deploy command to `npm run deploy`.** That script runs the build
  itself, so you would build twice.

Root directory is what makes this work in a monorepo — it's the directory the build
command runs in.

### Build watch paths — do not skip this

Same screen, **Build watch paths**:

| Field | Value |
|---|---|
| Include | `marketing/site-v2/*` |
| Exclude | *(empty)* |

`NutriPulse` is an iOS app that happens to contain a marketing site. Without watch paths,
**every Swift commit triggers a full site build and redeploy** — minutes of build time and
a new deployment for a change that can't possibly affect the site.

Paths are evaluated excludes-first, then includes; a build runs only if something still
matches. Cloudflare bypasses the filter entirely for pushes with 0 changes, 3,000+ changed
files, or 20+ commits, so a large merge will still build.

The repo can stay **private**. That's the main practical win over GitHub Pages, where the
custom-domain setup only worked while `NutriPulse` was public.

### After connecting: one source of truth

Once git builds are on, `npm run deploy` from a laptop still works — and that's the trap.
Deploying locally from a dirty tree puts something live that isn't in the repo, and the
next git build silently reverts it. Pick one: push to deploy, and keep `npm run deploy` for
emergencies only.

## 2. Attach the apex domain (once)

Handled by the first deploy — `wrangler.jsonc` declares `tryfooting.app` as a custom
domain, so wrangler creates the DNS record and requests the certificate. Nothing to do in
the dashboard.

Verify once it's up:

```bash
curl -sI https://tryfooting.app | head -3                 # expect HTTP/2 200
curl -sI https://tryfooting.app/terms | head -1           # expect 200, NOT 404
curl -sI https://tryfooting.app/privacy | head -1         # expect 200
curl -sI https://tryfooting.app/nope | head -1            # expect 404
```

That third-to-last check matters: if the root directory is wrong, `/` may still serve
something while the legal pages 404.

**URLs are extensionless.** Workers static assets strips `.html` and treats the bare path
as canonical, so `/terms.html` answers `307 → /terms`. Every link on the site, in the
redirect stubs, and in `Config.swift` therefore points at `/terms` and `/privacy` — the
`.html` forms still resolve, but only via that extra hop, and the App-Review-fetched
privacy URL should not need one.

## 3. Redirect www → apex (once, dashboard only)

Not expressible in `wrangler.jsonc`. Two parts, and the DNS half is the one people miss —
a redirect rule can only fire on traffic that reaches Cloudflare's edge, and `www` has no
record at all by default.

### 3a. Give www a DNS record

Dashboard → `tryfooting.app` → **DNS** → **Add record**:

| Field | Value |
|---|---|
| Type | `AAAA` |
| Name | `www` |
| IPv6 address | `100::` |
| Proxy status | **Proxied** (orange cloud) — this is the part that matters |

`100::` is the IPv6 discard prefix: a black hole. Nothing is meant to reach it. The record
exists purely so `www` resolves and Cloudflare's edge receives the request, at which point
the rule below answers it and no origin is ever consulted. Grey-cloud this and the redirect
silently never runs.

### 3b. The redirect rule

Dashboard → **Rules** → **Redirect Rules** → **Create rule**:

| Field | Value |
|---|---|
| Name | `www to apex` |
| When incoming requests match | **Wildcard pattern** |
| Request URL | `https://www.*` |
| Then | **URL redirect** |
| Type | Wildcard pattern |
| Target URL | `https://${1}` |
| Status code | `301` |
| Preserve query string | **on** |

`${1}` is the wildcard capture, so `https://www.tryfooting.app/terms` becomes
`https://tryfooting.app/terms` — the path survives with no expression syntax needed.

Verify:

```bash
curl -sI https://www.tryfooting.app/terms | head -3   # expect 301 → https://tryfooting.app/terms
```

**Why a redirect rule and not a second custom domain:** binding `www` to the Worker would
serve the identical site on two hostnames and split canonical URLs — an SEO problem and a
cookie-scope problem. The rule runs before the Worker and costs nothing.

## 4. Email — support@tryfooting.app

That address is published in three places (site footer, Terms, Privacy Policy) and is the
only contact route users have. It has to work before the site is announced.

### Receiving (Cloudflare Email Routing)

Dashboard → `tryfooting.app` zone → **Email** → **Email Routing**. It adds these itself;
the domain had no MX or TXT records beforehand, so nothing conflicts:

| Type | Name | Value |
|---|---|---|
| MX | `tryfooting.app` | `route1.mx.cloudflare.net` |
| MX | `tryfooting.app` | `route2.mx.cloudflare.net` |
| MX | `tryfooting.app` | `route3.mx.cloudflare.net` |
| TXT | `cf2024-1._domainkey` | DKIM key — signs forwarded mail so it isn't treated as spoofed |
| TXT | `tryfooting.app` | `v=spf1 include:_spf.mx.cloudflare.net ~all` |

Two MX records sharing a priority is normal — equal priority means round-robin, not a
misconfiguration.

Then create the rule (`support@tryfooting.app` → your real inbox) and **click the
verification link Cloudflare emails to the destination**. Routing stays inactive until you
do, and the failure is silent: mail to support@ simply bounces.

### Sending — not included, and it matters

**Email Routing is receive-only.** It forwards inbound mail; it will not let you send
*from* `support@tryfooting.app`. Replies would go out as your personal address, which on a
health app — to someone who wrote in about a privacy request — reads as a wrong number.

Two ways to fix it:

- **Cloudflare Email Service** — a separate product from Routing, same dashboard, built for
  exactly this. New accounts start on conservative daily quotas that scale with sending
  reputation; support volume won't approach them.
- **Gmail "Send mail as"** — if the destination inbox is Gmail, add the address there with
  an SMTP relay. Free, and replies come from the right address.

### The SPF constraint

**A domain may have exactly one `v=spf1` TXT record.** A second one doesn't add to the
first — it makes SPF evaluation fail, and mail starts landing in spam.

So when sending is added, the existing record is *edited*, never duplicated:

```
# wrong — two records, SPF breaks entirely
"v=spf1 include:_spf.mx.cloudflare.net ~all"
"v=spf1 include:_spf.newsender.com ~all"

# right — one record, both includes
"v=spf1 include:_spf.mx.cloudflare.net include:_spf.newsender.com ~all"
```

### DMARC

Not added by Email Routing. Worth having in place before anything ever sends from the
domain:

```
_dmarc.tryfooting.app   TXT   "v=DMARC1; p=none; rua=mailto:support@tryfooting.app"
```

`p=none` is monitor-only — it reports without rejecting anything. Tighten to `quarantine`
or `reject` only after reports show legitimate mail is passing.

## 5. The old GitHub Pages URL

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
static let privacyPolicyURL = URL(string: "https://tryfooting.app/privacy")!
```

Keep the Pages redirect running afterwards regardless — older builds don't update.

Also worth a decision at the same time: `Config.swift:42` sets `termsOfUseURL` to Apple's
standard EULA, which is a valid Terms of Use for a free app. Now that
`https://tryfooting.app/terms` exists, you can point at it instead. Apple's own EULA
is the safer default while the app is free; switch when you add subscriptions, since a
custom EULA is required once money is involved.

---

## Cutover order

1. Deploy to Cloudflare and confirm `https://tryfooting.app` serves the new site. ✅
2. Check `/terms`, `/privacy`, and a deliberate 404. ✅
3. Add the www redirect rule (§3); confirm `www.tryfooting.app` lands on the apex.
4. Set up Email Routing for `support@tryfooting.app` (§4) and click the destination
   verification link. Send yourself a test to confirm it lands.
5. Commit `marketing/redirect/` + the workflow change so the Pages URLs forward.
   Not before step 1 — the workflow fires on its own path, and pushing it early would
   point the old URLs at a domain that wasn't serving yet.
6. Verify `https://dsmithsalinas.github.io/NutriPulse/privacy.html` lands on the new
   policy, in a browser and with JavaScript disabled.

Step 6 is the one that protects an App Review submission. Don't skip it.

## Costs

Free tier. Static asset requests aren't billed as Worker invocations, and the Workers free
plan allows 100,000 requests/day — a marketing site won't approach it. The domain
registration is the only recurring cost.
