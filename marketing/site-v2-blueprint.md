# Footing — Site v2 Blueprint

**Status:** Design exploration. Nothing built, nothing pushed.
**Supersedes:** nothing yet — `marketing/index.html` stays live until v2 ships.
**Source material:** `docs/pulse-persona.md` (voice), `orbit-exports/export/*.svg` (mark), current `index.html` (copy that already works).

---

# Part 1 — Creative Direction

## 1.1 What the brand actually is

A footing is the concrete base poured beneath a structure so nothing above it sinks. That gives the name three simultaneous readings, and all three are usable:

| Reading | Meaning | Where it earns its keep |
|---|---|---|
| **Structural** | the base that carries the load | the 3D concept, the visual identity |
| **Personal** | "finding your footing" — regaining stability | the emotional arc of the scroll |
| **Physical** | the ground under you | the literal set the site is staged on |

The product claim collapses into one sentence, and everything on the site should be traceable to it:

> **The shot does its part. Your protein floor is what keeps the result standing.**

The existing tagline — **"Coached, not scolded."** — is the strongest asset in the brand and it survives v2 intact. See §2.4 for why replacing it would be a mistake.

## 1.2 Audience

Primary: adults on semaglutide/tirzepatide (Wegovy, Zepbound, Ozempic, Mounjaro), roughly 30–55, skewing female, 0–12 months into treatment.

What's actually true about them, in priority order:

1. **They have already quit a tracking app.** Usually MyFitnessPal. The reason was never the food database — it was the feeling of being graded, plus the friction of search-and-tap logging.
2. **Their problem has inverted and most tools haven't noticed.** Appetite is gone. The hard part is eating *enough*, not less. Every app on the market is built to help you subtract.
3. **They are carrying externally-imposed shame** about being on the medication at all ("the easy way out"). They will scan any new product for a whiff of it and bounce instantly.
4. **Their real fears are specific:** muscle loss, hair loss, and the cliff — what happens when they stop.
5. **They are not novices at self-blame.** They do not need motivation. They need someone competent paying attention.

**Conversion barrier, stated plainly:** it is not "does this track macros." Every app tracks macros. It is *"is this going to become another thing that makes me feel like a failure?"* The site's entire job is to answer that question in the first three seconds and then prove it for the rest of the scroll.

## 1.3 Competitive read

Positioning analysis from category knowledge, not a fresh audit — worth verifying with a real sweep before final commitments (see Open Questions).

| Cluster | Who | How their sites feel | The opening they leave |
|---|---|---|---|
| **Legacy trackers** | MyFitnessPal, Lose It, Cronometer | Feature-dense, food photography, blue/green, database-as-hero | Zero emotional stance. They sell capability, never relief. |
| **Behavioral** | Noom, Simple, Fastic | Bright, gamified, quiz-gated funnels, heavy pattern-interrupt | Feels like being processed. Trust deficit. |
| **GLP-1 telehealth** | Ro, Found, Calibrate, Hers | Clinical-white, editorial photography, doctor imagery, regulatory chrome | They sell the *drug*. Nobody in this cluster owns the work that surrounds it. |
| **GLP-1 companion apps** | Sequence, Embla, assorted small players | Derivative of the telehealth look, or of MFP | No distinct material world. Interchangeable. |

**Two pieces of whitespace, and Footing can hold both:**

1. **Nobody is named after the work.** The entire category names itself after the medication or the outcome. "Footing" names the thing that makes it hold. That is a genuine differentiator and the site should make the visitor *feel* it before it explains it.
2. **No site in this category has a material world.** They are all white-and-clinical or bright-and-gamified. There is no *architectural* nutrition brand. That is the lane.

**The trap to avoid:** dark + 3D + gradient is the default costume of every AI/crypto startup, and wearing it would make a warm product read cold. The antidote is material choice — concrete, poured resin, and daylight, not neon glass. See §1.5.

## 1.4 The emotional arc

The site is a descent and a sunrise. The visitor should move through four states, in order, and the *light level of the page* should do most of that work:

```
ARRIVE          RECOGNIZED        RELIEVED         STEADIED
carrying        "this one knows   "oh — this is    "there is
low-grade  ───▶ what my day   ───▶ actually   ───▶ ground
dread           is like"          easy"            under me"

#07070F ────────────────────────────────────────▶ #F6F5FC
subgrade                                            daylight
```

**The single biggest idea in this document:** the page background is a scroll-driven interpolation from near-black to the existing `--ground` cream. You literally rise out of the dark into daylight as you scroll. It costs almost nothing to implement, works identically on a phone with no WebGL, and it renders the emotional arc as a physical property of the page.

Target feeling at the CTA: **steadied.** Not hyped. If a visitor arrives at the button feeling excited, the tone is wrong. They should arrive feeling like they've stopped sinking.

## 1.5 Visual identity

### Palette

Existing tokens survive; three are added for the dark half.

```css
/* new — the dark half */
--subgrade:  #07070F;   /* page top, deepest point */
--substrate: #12122A;   /* mid-strata, card fills on dark */
--strata:    #1C1E3D;   /* section separations on dark */

/* existing — unchanged */
--ink:       #14163A;
--ink-soft:  #2A2C52;
--indigo:    #6366F1;
--violet:    #8B5CF6;
--warm:      #FF8A5B;   /* protein / the warm layer */
--green:     #34D399;   /* goal met, only ever for success */
--ground:    #F6F5FC;   /* page bottom, daylight */
--muted:     #64678A;
--line:      #E7E4F3;
```

**The one rule that keeps it premium:** indigo→violet appears as *emitted light*, never as a flat fill. In the dark half it is the glow of the footing itself; in the light half it is a single accent on the CTA. A dark page carrying one saturated light source reads expensive. The same page with gradient blobs reads like a template.

`--warm` is the protein color throughout — warm amber against cool indigo is the site's only real color tension, and protein is the product's whole thesis, so the tension is on-message.

### Type

| Role | Face | Spec | Why |
|---|---|---|---|
| Display | **Inter Display** | 600, tracking `-0.035em`, `clamp(44px, 7vw, 104px)`, line-height 0.98 | The mark already sets "Footing" in Inter. Inter Display at large sizes with tight tracking is genuinely premium and costs nothing. |
| Body | **Inter** | 400/500, 17–19px, line-height 1.55 | Continuity with the app. |
| Editorial accent | **Instrument Serif** *italic* | 400, for pull-quotes only, 2–4 uses on the whole page | This is the highest-leverage decision in the type stack. One serif italic against a grotesk is the difference between "designed" and "templated." Reserve it for the emotional lines — *"why am I doing this to myself?"* |
| Numerals | Inter, `font-variant-numeric: tabular-nums` | all macro figures | Numbers must not jitter when they count up. |

Sentence case everywhere, including buttons and nav — per `docs/pulse-persona.md` §4. Title Case reads as system; Footing reads as someone who knows you.

### Material world

The set is **honed concrete, poured resin, and one volumetric light.**

- **Concrete:** roughness ~0.62, faint normal-map noise, matte. Carries the "structural" reading.
- **Strata:** translucent resin cores — light passes *through* them, so each layer glows from within when the light source is beneath it.
- **The footing:** emissive, indigo→violet, the only light source in the scene.
- **Grain:** a 3–4% film grain overlay across the whole page, canvas and DOM alike. This is what fuses the WebGL layer to the HTML layer so the site reads as one object instead of a video embedded in a page.
- **Depth of field:** shallow, focus on the current strata, everything else soft. Non-negotiable for the premium read.

### Icon and mark usage

The mark (ring + gap + dot, `orbit-exports/export/footing-mark.svg`) is **inlaid into the top surface of the slab** in the 3D scene — catching the rim light, not floating. Never rendered as a spinning 3D logo. The stacked lockup appears exactly twice: nav and footer.

## 1.6 The 3D scene

### The object: a cross-sectioned slab of ground

One hero object for the entire site. A rectangular slab of earth, cut open like an architectural site model or a soil core, floating in a soft dark void.

```
         ╔═══════════════════════════════════╗
  0%     ║  TOP SURFACE — honed concrete     ║   "the floor you stand on"
         ║  Footing mark inlaid, rim-lit     ║
         ╠═══════════════════════════════════╣
 25%     ║  STRATUM 01 — warm amber, resin   ║   protein
         ╠═══════════════════════════════════╣
 45%     ║  STRATUM 02 — pale blue, resin    ║   hydration
         ╠═══════════════════════════════════╣
 65%     ║  STRATUM 03 — soft green, resin   ║   movement / sleep
         ╠═══════════════════════════════════╣
 85%     ║  THE FOOTING — emissive           ║   ← the only light source
         ║  indigo → violet, poured          ║      everything above rests on this
         ╚═══════════════════════════════════╝
```

**Why this and not the alternatives:**

- *A rotating iPhone* — every app site. Zero brand meaning.
- *Particles / blobs / mesh gradients* — the AI-startup uniform. Actively harmful here.
- *A literal pour animation* — too literal, and construction imagery reads grim.
- **The slab** — it is the name made spatial, it maps 1:1 onto the product's actual sections (protein floor, hydration, movement, the base), and the scroll gesture is genuinely unusual: most sites scroll *along* a story, this one scrolls *down through* a structure and then rises back out of it.

### Camera choreography

| Act | Scroll | Camera | Page state |
|---|---|---|---|
| **I — Surface** | 0–10% | Low, near the top face, grazing light | Hero. Dark. Slab is a horizon line. |
| **II — Descent** | 10–70% | Descends past each stratum; DOF racks to the active layer | Each stratum's arrival triggers its DOM section |
| **III — The base** | 70–82% | Reaches the footing. It's the brightest thing on the page. | "Why Footing?" — the metaphor pays off here and nowhere earlier |
| **IV — Ascent** | 82–100% | Pulls back and rises; the whole slab resolves, a horizon appears, daylight | Offer, FAQ, closing CTA. Light. |

The reveal that the footing was the light source the whole time is the site's one real *moment*. Everything above it was visible because of it. Do not explain this in copy — let it be structural. The "Why Footing?" section lands one beat later and the visitor connects it themselves. That gap of one beat is worth more than any headline.

## 1.7 Animation system

**Motion grammar: everything moves like weight settling.** Nothing bounces. Nothing overshoots.

```css
--ease-in-out: cubic-bezier(.6, 0, .2, 1);    /* exits, camera, page transitions */
--ease-out:    cubic-bezier(.2, .7, .2, 1);   /* entrances — already in index.html, keep */
--ease-settle: cubic-bezier(.16, 1, .3, 1);   /* long scene moves */

--dur-micro:   200ms;   /* hover, focus, tap */
--dur-element: 450ms;   /* a card, a number, a line of text */
--dur-section: 800ms;   /* a section entering */
--dur-scene:  1400ms;   /* a camera act */
```

**The one exception, and it's a rule not an accident:** the streak-celebration moment in §3.3 is the *only* element on the entire site permitted a spring with overshoot. Earned celebration is the brand's single sanctioned joy. Using a spring anywhere else spends it.

**Stagger:** 60ms between siblings, max 5 in a chain, then the rest arrive together. Longer chains read as a loading screen.

**Numbers:** all macro figures count up from 0 over 900ms on entry, `--ease-out`, tabular numerals, and they never re-trigger on scroll-back. Re-triggering animation is the fastest way to make a premium site feel cheap.

**Reduced motion (`prefers-reduced-motion: reduce`):** every element resolves instantly to final state; the background lerp is replaced by a static mid-tone (`#2A2C52` top, `--ground` bottom, hard section boundaries); the canvas is replaced by a single still render of Act III. The site must be *fully comprehensible* with zero motion — the current `index.html` already respects this and v2 must not regress it.

## 1.8 Tech stack

| Layer | Choice | Why this and not the alternative |
|---|---|---|
| Framework | **Next.js 15, App Router, TypeScript** | You know React/TS. Static-exportable if you want to stay on Pages. |
| 3D | **React Three Fiber + drei** | Three.js as React components — scene graph as JSX, which is the exact mental model you already have. |
| Post-processing | **@react-three/postprocessing** | Bloom, DOF, vignette, grain. The DOF is what sells "premium." |
| Scroll | **Lenis** | Smooth scroll that ScrollTrigger can drive. The inertia is 40% of the luxury feel. |
| Timeline | **GSAP + ScrollTrigger** | Pinned multi-beat scroll timelines are what ScrollTrigger is for. Now fully free including ScrollTrigger. |
| Component motion | **Motion (Framer Motion)** | Entrances and layout. Don't use it for the scroll timeline — GSAP wins there. |
| Styling | **Tailwind v4 + CSS custom properties** | Tokens as CSS vars so the canvas and the DOM read the same palette. |
| Email capture | **Supabase table + a route handler** | You already run Supabase. One `beta_signups` table, RLS insert-only. |
| Hosting | **Vercel** | Needed for the route handler. GH Pages can't do the capture. |
| Analytics | **Vercel Analytics + one scroll-depth event per section** | Section-level drop-off is the only metric that will tell you which beat is failing. |

**Architecture note that matters more than any of the above:** one `<Canvas>` for the entire page, fixed behind the DOM, `eventSource` pointed at the document root. Sections do not each get a canvas — they are camera positions on a single persistent scene. Multiple canvases will tank the frame rate and are the most common way this kind of site fails.

**Geometry: procedural, not modeled.** The slab is a beveled box with a noise-displaced top face plus four instanced strata. Build it in R3F directly. No `.glb`, no Draco, no Blender round-trip, no model download. Payload stays near zero and you can tune the strata thicknesses in code.

### Performance budget

| Metric | Target | Enforcement |
|---|---|---|
| LCP | < 2.0s | **Hero H1 and CTA are DOM text, not canvas.** They paint before WebGL initializes. |
| Critical JS | < 200 KB | The 3D chunk is `next/dynamic` with `ssr: false`, loaded after first paint. |
| Frame rate | 60fps M1 / 45fps mid Android | `PerformanceMonitor` from drei auto-drops DPR and disables bloom below threshold. |
| Canvas entry | fade in over 600ms | Never a pop-in. The static gradient is the poster. |

**Degradation ladder** — each rung is fully shippable on its own:

1. No WebGL, or `prefers-reduced-motion`, or `navigator.hardwareConcurrency < 4`, or Save-Data → CSS gradient + SVG strata. **No canvas at all.**
2. Mobile (< 768px) → same. Full 3D on a phone is a battery and thermal trap, and the background lerp already carries the emotional payload for free.
3. Tablet → canvas, no post-processing.
4. Desktop → everything.

Mobile getting rung 1 is a deliberate call, not a compromise: 70%+ of this traffic will be phones, and a 45fps thermal-throttling canvas is worse than a beautiful gradient. The 3D is a desktop reward.

## 1.9 Build order

Each phase is independently shippable. **Phase 1 must convert on its own before any 3D exists** — if the copy doesn't work flat, the 3D won't save it, it'll just make the failure more expensive.

| Phase | Scope | Done when |
|---|---|---|
| **0 — Foundations** | Next.js + TS, tokens as CSS vars, Inter Display + Instrument Serif, Lenis, layout shell, nav, footer | Empty page scrolls smoothly, type scale is set |
| **1 — The flat site** ⭐ | Every section from Part 3 with final copy, mobile-first, background lerp in pure CSS, all entrance animations | **Shippable. Put it live. Start collecting emails.** |
| **2 — Canvas** | Single `<Canvas>`, procedural slab, lighting, Act I only, static camera | Hero has the slab; nothing scroll-linked yet |
| **3 — Choreography** | GSAP ScrollTrigger drives camera through Acts I–IV; strata reveals sync to sections | Full scroll works end to end |
| **4 — Polish** | DOF, bloom, grain, the celebration spring, number count-ups, micro-interactions | It looks expensive |
| **5 — Hardening** | Degradation ladder, `PerformanceMonitor`, a11y pass, keyboard nav, focus states, analytics | Passes on a mid-tier Android and with a screen reader |
| **6 — Capture** | Supabase `beta_signups`, route handler, success state, confirmation email | Emails land in a table |

Rough sequencing: phases 0–1 are the bulk of the *value*; 2–4 are the bulk of the *time*.

---

# Part 2 — The Hero

Three directions, ranked. All three share the same layout skeleton and the same CTA; they differ in what claim leads.

## 2.1 Direction 1 — "The Objection" ⭐ WINNER

**Eyebrow** — `Now on TestFlight · iPhone`

**Headline**
> # Coached, not scolded.

**Subheadline**
> On a GLP-1 the goal flips: it's not about eating less, it's about eating *enough*. Footing tracks the protein floor that protects your results — and puts a coach in your corner who's actually read your whole day.

**CTA** — `Join the beta →`
**Micro-trust, directly beneath** — `Free during beta · No card · iPhone`
**Secondary, text-only** — `See how it works ↓`

### Background animation
Act I. Camera low and near the slab's top face, so it reads as a **horizon** rather than an object — you are standing on it, not looking at it. A slow grazing light travels left-to-right across the concrete over 18s, looping, revealing surface texture. The Footing mark is inlaid in the surface, catching the light as it passes. Page background `--subgrade`. The footing's glow is present but far below and out of frame — visible only as a faint violet bloom at the bottom edge of the viewport, unexplained. Depth of field is shallow; the far edge of the slab dissolves into black.

### Entrance sequence

| t | Event |
|---|---|
| 0ms | `--subgrade` fill. Nothing else. |
| 200ms | Nav fades down, 8px travel, 600ms |
| 350ms | H1 — a two-line mask reveal, lines rising from behind their own baseline, 60ms stagger, 900ms, `--ease-out`. **DOM text, not canvas.** |
| 700ms | Subheadline fades up 20px, 700ms |
| 950ms | CTA scales `0.96 → 1` with a 12px rise, 500ms |
| 1100ms | Micro-trust line fades in |
| 1200ms | Canvas fades in over 600ms *behind* everything already painted |
| 1400ms | Grazing light loop begins |

The canvas arriving **last** is the whole trick. The words land first — LCP is DOM text — and then the world materializes behind them. Reversed, you get a loading screen.

**On the logo animation:** the current site opens with a full-screen splash of `Footing Logo Animation.mp4` that gates the page. Kill it. It costs ~1.2s before anyone reads a word, and a splash screen is a toll booth. Repurpose the animation as an inline 40px play-on-first-view in the nav, or drop it from the site entirely and keep it for the App Store and social. This is the single highest-impact conversion change in the whole redesign.

### Scroll trigger
The hero pins for 40vh of scroll. During the pin: H1 and subhead drift up 60px and fade to 0 while the camera begins its descent and the background lerps `--subgrade → --substrate`. The CTA does **not** fade — it detaches and docks into the nav as a persistent pill, and stays there for the rest of the page. Unpin at 40vh, normal flow resumes.

### Mobile fallback
No canvas. Background is a CSS radial gradient — `--subgrade` with a soft violet bloom at 120% bottom-center, which is exactly what the desktop scene shows in-frame anyway. Two SVG hairlines at the bottom edge suggest the strata. H1 drops to `clamp(38px, 11vw, 56px)`. Entrance sequence runs identically, minus the canvas step. The CTA is full-width and sticky-docks on scroll. The background lerp runs on mobile too — it's a CSS custom property animated by an `IntersectionObserver`, ~15 lines, and it's the emotional payload.

### 2.2 Direction 2 — "Solid Ground"

**Eyebrow** — `Built for GLP-1 · Great for anyone tracking`

**Headline**
> # Your results need something to stand on.

**Subheadline**
> The shot does its part. Footing is the rest — protein-first tracking, and a coach who notices when you're winning.

**CTA** — `Get your footing →`

**Background** — Act III inverted: the camera starts *at* the footing, looking up through the translucent strata toward a surface far above. Scroll rises toward daylight. Gorgeous, and the most "splashy" of the three.

**Why it ranks second:** it's the most beautiful and the least clear. "Something to stand on" is a metaphor that requires you to already know what the product does to decode it. A visitor who's never heard of Footing reads it as vague inspiration. The metaphor is a *reward*, and this direction spends it on the first screen.

### 2.3 Direction 3 — "The Number"

**Eyebrow** — `AI nutrition coaching · iPhone`

**Headline**
> # Hit your protein floor. Every single day.

**Subheadline**
> Say what you ate in one sentence. Footing does the math, and Pulse tells you exactly how to close the gap — with food you actually eat.

**CTA** — `Start the beta →`

**Background** — a single macro ring rendered in 3D as a physical band of light with a visible gap, floating. Scroll closes the gap. Kinetic, product-literal, very legible.

**Why it ranks third despite being clear:** "protein floor" is house jargon. It only means something *after* the visitor has been told the goal flipped — which is Section 02, not the hero. Leading with it asks the reader to accept a premise they haven't been given. It also competes visually with Apple's Activity rings, which is a fight not worth having. Strong as a *mid-page* headline; wrong as the opener.

## 2.4 Why Direction 1 converts

**1. It answers the actual objection instead of describing the mechanism.**
Every visitor arrives with one live question: *is this going to make me feel like a failure again?* Directions 2 and 3 answer questions nobody asked ("what is it built on," "what does it track"). Direction 1 answers the real one in three words, before the fold, before any feature.

**2. "Scolded" is a word no competitor will ever print.**
MyFitnessPal cannot say it — it would be an admission. The telehealth brands can't say it — wrong register. Naming the pain names the enemy, and a category with no named enemy is a category anyone can walk into and claim.

**3. The subhead delivers a genuinely new idea in its first clause.**
*"the goal flips: it's not about eating less, it's about eating enough."* Most visitors on a GLP-1 have felt this and never had it articulated. Being handed language for your own unnamed experience creates immediate authority — "this person knows something I don't" — which is far stronger than any feature list.

**4. Emotional-then-specific beats specific-then-emotional.**
The headline earns the four seconds; the subhead spends them on protein floors and coaching. Direction 3 inverts it and asks for technical patience it hasn't earned yet.

**5. It's already proven, and continuity compounds.**
This line is on the current site and is queued as an App Store keyword swap. Replacing a working, ownable, three-word line for novelty's sake would be trading an asset for a redesign. **The line stays. The staging changes completely.** That is what makes v2 a new site rather than a new slogan.

**One thing to test:** whether the eyebrow should be `Now on TestFlight · iPhone` (scarcity + platform) or `For anyone on a GLP-1` (audience qualification). Scarcity is the default recommendation because "beta" also lowers the bar on expectations, which is worth real money pre-1.0.

---

# Part 3 — Page Architecture

Ten sections. Each has one goal and drives exactly one action.

> **Design constraint:** most sections drive *"keep scrolling."* Only three drive *"click."* A page where every section shouts CTA converts worse than one that earns the click once, properly. Emails come from sections 00, 06, and 08.

---

### 00 — Hero
**Goal** Answer the survival question — *will this make me feel bad?* — in under four seconds.
**Content** Eyebrow, H1, subhead, primary CTA, micro-trust, scroll cue.
**Action** `Join the beta` (or scroll)
**Light** `--subgrade`, darkest point on the page.

**Why here:** first-screen attention is spent on threat assessment, not evaluation. Spend it removing the threat.

---

### 01 — Recognition
**Goal** Prove we know their last failure better than they can describe it.
**Content** *"Tracking shouldn't feel like getting graded."* The existing copy in `index.html` is very good — the pull-quote *"why am I doing this to myself?"* set in Instrument Serif italic is the emotional low point of the page and should be the largest non-headline type on the site. Beside it: the anti-card — red numbers, `+320 over`, `−38 under`, `Streak: Broken` — captioned *"Every other app, every single day."*
**Action** Keep scrolling.
**Light** `--subgrade → --substrate`. Camera enters the first stratum.

**Why here:** problem-agitation must precede solution or the solution has nothing to relieve. Critically, the failure is attributed to *the tools*, not the user — which is the non-shaming law applied to marketing, not just to Pulse. A visitor who reads Section 01 and thinks "that wasn't my fault" is now listening.

---

### 02 — The Flip
**Goal** Deliver one genuinely new idea and convert it into authority.
**Content** *"When your appetite disappears, the goal flips."* Not about eating less — about eating enough. Muscle is what's at risk. Protein is what protects it. Introduce "protein floor" **here**, where it's earned. One visual: a conventional deficit chart inverting into a floor-with-a-minimum.
**Action** Keep scrolling.
**Light** `--substrate`. The warm amber protein stratum passes the camera.

**Why here — this is the most important placement decision on the page.** It is the only section delivering information the visitor doesn't already have. Information gaps are the strongest engine of continued attention there is, and closing one buys credibility that every subsequent claim borrows against. It must come *before* features, because after it, "Footing tracks protein floors" reads as an obvious solution to a problem they now understand rather than as a feature they have to evaluate.

---

### 03 — How It Works
**Goal** Destroy the effort objection. Perceived effort is the #1 cause of tracking churn.
**Content** Three beats, each killing a specific past failure:
- **01 Effortless in** — voice logging. Kills *"searching for every food is exhausting."*
- **02 Honest, but useful** — Pulse reads the whole day and gives a specific move. Kills *"it just told me I was over."*
- **03 Earned celebration** — the streak moment. Kills *"nothing good ever happened when I opened it."* **The only spring animation on the site lives here.**
**Action** Keep scrolling.
**Light** `--substrate → --strata`. Hydration and movement strata pass.

**Why here:** mechanism only lands after the problem is felt and the premise is accepted. Ordering the three beats by *effort → honesty → reward* mirrors the actual daily loop of using the app, which makes the product feel understood rather than listed.

---

### 04 — Built for the Cycle
**Goal** Prove GLP-1 fluency at a depth a generic tracker cannot fake.
**Content** The injection cycle. Protein density on low-appetite days. Hydration keeping pace. Dose reminders that never advise dosing. The existing GLP-1 card in `index.html` — *"Day 2 after your shot — appetite's usually lowest now"* — is the single most persuasive artifact in the current site. Give it a full section.
**Action** Keep scrolling.
**Light** `--strata`, approaching the glow.

**Why here:** this is the "they get *me*" beat, and it must come after generic capability. Reversed, GLP-1 specifics read as a niche limitation. In this order they read as depth.

---

### 05 — Why Footing?
**Goal** Convert the name into a memory hook and pay off the entire visual metaphor.
**Content** The existing copy is already right and needs almost no editing: a footing is the base poured beneath a floor so nothing above it sinks. Most apps here are named after the medication. This one is named after **the work.**
**Action** Keep scrolling.
**Light** **Act III.** The camera reaches the footing. It is the brightest object on the page, and the visitor realizes it has been the light source the whole way down.

**Why here — placement is load-bearing.** A brand-story section near the top is a riddle the visitor has no reason to solve. Placed here, after the value is proven, the metaphor arrives as a *reward*: the name suddenly means something, and named things are remembered. Note the deliberate one-beat gap — the light-source reveal happens visually in Section 05's scroll, and the copy explains the metaphor immediately after. Let them connect it themselves. That gap is worth more than any headline.

---

### 06 — The Offer
**Goal** Remove commercial anxiety at the exact moment intent peaks.
**Content** What you get. **Free during the beta** — say exactly that and nothing more; post-beta pricing is undecided (confirmed 2026-07-27), and inventing a number now is worse than silence. If FAQ #8 asks what it'll cost later, the honest answer is "not decided yet, and beta users will hear it from us before anything changes." iPhone-only, stated plainly. TestFlight install order spelled out — the existing site's two-step warning about opening TestFlight first is genuinely good UX writing, keep it verbatim. One CTA.
**Action** `Join the beta` — **second highest-converting block on the page.**
**Light** **Act IV begins.** Camera rises. `--strata → --ground`. Daylight.

**Why here:** intent peaks immediately after meaning. Ambiguity about price or platform at this exact moment is the most expensive ambiguity on the page. State it, don't bury it in the FAQ.

---

### 07 — Proof
**Goal** Substitute credibility for social proof you don't have yet.
**Content** Pre-launch. **No testimonials and no placeholder slot** — decided 2026-07-27. An empty "what people are saying" frame advertises that nobody is saying anything. Three things that are true and are enough:
1. **Real screens, unretouched.** The product is the proof. This is the honest version of a screenshot gallery.
2. **A real Pulse exchange** — verbatim, showing consequence-then-path. Nothing sells the coach like the coach.
3. **The founder note — confirmed true and the strongest asset here.** Built by one person, who is on a GLP-1, because the existing tools didn't work for them. Lead the section with it, don't bury it at the bottom. Small and personal is a *trust asset* against Noom-style billing horror stories, not a weakness — and it's the only claim on the page no competitor can copy.
4. **The safety stance stated proactively** — not a medical device, no dosing advice. Pre-empting the scary question is more persuasive than answering it in an FAQ.

Revisit once TestFlight produces real quotes; add App Store rating at launch. Until then the section stands on the founder note.
**Action** Keep scrolling.
**Light** `--ground`, full daylight.

**Why here:** proof is a *doubt-resolver*, not a *desire-builder*. It only works once desire exists. Before Section 06 it's noise; here it catches the visitor who wants to believe and needs one more reason.

---

### 08 — Objections
**Goal** Answer the exact reasons the finger hovers over the button.
**Content** Accordion, honest, short. In this order:
1. *I've quit every tracking app I've tried. Why is this different?* — the real objection, first.
2. *Is this just MyFitnessPal with a chatbot bolted on?*
3. *Do I have to log everything?*
4. *What happens when I stop the medication?* — the deepest fear in the audience. Answering it is a differentiator, not a risk.
5. *Is my health data private? Does an AI see it?*
6. *Is any of this medical advice?*
7. *Android?* — say the truth, offer a waitlist, capture the email anyway.
8. *What will it cost after beta?*
**Action** Keep scrolling → Section 09.
**Light** `--ground`.

**Why here:** objections surface *after* desire. Placed early they plant doubts the visitor didn't have. Ordering by emotional weight rather than by frequency matters — #1 and #4 are the two that actually decide it.

---

### 09 — Closing CTA
**Goal** One action, no alternatives, no navigation.
**Content** Restate the promise in the brand's own words: *"Stop getting graded. Start getting coached."* One button. The two-step TestFlight instruction repeated. Nothing else — no nav, no links, no footer above it.
**Action** `Join the beta on TestFlight →`
**Light** `--ground`, brightest point. Act IV completes: the full slab resolves, a horizon appears, the visitor is standing on it.

**Why here:** the arc closes where it began — same promise, opposite light level. The visitor arrived in the dark and leaves on solid ground, and the page has spent 100vh × 9 physically demonstrating it.

---

### 10 — Footer
**Goal** Legal and trust, nothing more.
**Content** Stacked lockup, tagline, privacy, contact, the not-a-medical-device disclaimer (already correct in `index.html`).
**Action** None.

---

## 3.1 Structural rationale

The page runs **three nested arcs simultaneously**, which is why the order holds together:

| Arc | Runs | Mechanism |
|---|---|---|
| **Emotional** | dread → recognition → relief → steadiness | copy |
| **Physical** | subgrade → daylight | background lerp |
| **Spatial** | descent → the base → ascent | camera |

All three resolve at Section 09. When a visitor cannot articulate why a site felt good, this alignment is usually the reason.

**The gating decision:** the current site gates sections behind clicks ("See how it works" reveals the next block). Drop it. Gating suppresses scroll depth, breaks the light arc, and confuses the analytics you'll need to find the failing section. Let it be a continuous scroll.

**Section length target:** 90–110vh each on desktop. Below 80vh the camera moves faster than the reading; above 130vh the scroll feels like work.

---

# Decisions & Open Questions

**Settled 2026-07-27**
- **No testimonials, no placeholder slot.** Section 07 stands on real screens, a real Pulse exchange, and the founder note.
- **Pricing:** free during the beta. Post-beta is undecided and the site says nothing about it.
- **Founder note is true** — one person, on a GLP-1. Promoted to the lead of Section 07.

**Still open**
1. **Data/privacy specifics.** Section 07 point 4 and FAQ #5 make claims about where health data goes and whether it touches a model provider. Verify against the actual `coach-chat` Edge Function and Supabase RLS before writing a word of it. **Blocks that copy.**
2. **Fresh competitive audit?** §1.3 is category knowledge, not a current sweep. Worth a real pass before locking positioning.
3. **Host move.** Email capture needs a route handler, which GH Pages can't serve. Vercel + Supabase, or stay static and use a hosted form?
4. **Hero eyebrow** — `Now on TestFlight` vs `For anyone on a GLP-1`. Recommendation is the former; worth a real test.

---

# Addendum — Direction change (2026-07-27)

**§1.6's slab is superseded. The set is now the protein ring.**

Two abstract sets were built and rejected in prototype: the concrete slab (§1.6)
and a contour terrain. Both failed the same way, and it's worth writing down
because it will apply to any future candidate.

**They illustrated the name instead of showing the product.** "Footing" → poured
concrete is a one-to-one translation of a word, not an expression of what the app
does. The visitor has to decode the metaphor, and what it says once decoded is
only "solid ground" — true of any wellness brand. Neither set contained a single
fact about nutrition, protein, or coaching. Concrete also fought the voice: the
material read cold and industrial under a warm, non-shaming product.

**The replacement is built from Footing's own vocabulary:**

| Element | What it is | What it says |
|---|---|---|
| **The dial** | One thick emissive arc, indigo→violet, filling clockwise | "This is a nutrition tracker" — instantly, before any copy |
| **The floor tick** | A marked minimum at 76% of the circle | The one idea no competitor has |
| **Supporting arcs** | Two thinner, dimmer rings behind | Reads as macros, not as one abstract dial |
| **The readout** | Live `63 / of 185g protein`, DOM text | Makes the number concrete |
| **Pulse's line** | A message card in the hero, written to the persona bible | The coach demonstrating itself |

**Scroll behaviour.** The fill is the page's spine: it walks from 34% toward the
floor as the argument builds, and clears it at the reward beat. The colour going
warm at that moment *is* the celebration — no badge, no confetti. Progress
through the page equals progress through a day.

**The Apple Activity rings risk** is real and is handled by the floor. Apple's
rings are a score with no threshold; a single ring carrying a marked minimum you
rise *to* is a different idea wearing a similar shape. That is also why there is
one prominent ring rather than four concentric ones.

**Sections must yield to the dial.** In section 01 the ring slides to centre,
grows, and dims to ~28%, becoming the room the copy sits in rather than an object
competing with it. This is practical — the dial and the scorecard both want the
right-hand column — but it is also the argument staged: section 01 belongs to the
*old* way, so Footing's object steps back while the red scorecard takes over, and
returns brighter when the copy turns.

**Also learned, and it applies to any set:** copy needs a directional scrim
(`.hero::before`, `.s01::before`). A full-bleed background will otherwise put body
text over whatever the scene happens to be doing there.

The slab and terrain remain in-tree behind `?scene=slab` / `?scene=terrain` for
comparison. Once the direction is confirmed, delete both along with
`src/hero/variants.ts` and `src/SceneSwitch.tsx`.
