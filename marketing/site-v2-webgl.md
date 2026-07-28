# Footing — 3D / WebGL Spec

**Implemented in:** `marketing/site-v2/src/hero/`
**Companion docs:** `site-v2-blueprint.md` (page architecture), `site-v2-voice.md` (copy).

---

## 1. The scene

One object for the entire page: **Footing's protein ring**, rendered as emitted light.

There is no model. The geometry is a single `THREE.RingGeometry(2.35, 2.72, 220, 1)` — a flat
annulus — and everything else is one fragment shader. No `.glb`, no Draco, no KTX2, no
texture fetches, nothing to download beyond the JS itself.

That is a deliberate architectural choice, not a shortcut. The subject is a progress dial;
a dial is defined by *angle*, and angle is free in a fragment shader. Modelling it would add
a network round-trip and a decode step to draw something the GPU can derive from
`atan(x, y)`.

### What the shader draws

| Feature | Implementation | Why |
|---|---|---|
| Track | Base colour at `uA * 0.22`, alpha `0.28` | The unfilled day |
| Fill | `1 - smoothstep(uProgress ± aa, t)` where `t` is normalised angle | Progress, clockwise from twelve o'clock |
| Gradient | `mix(indigo, violet, t / uProgress)` | Brand gradient as light along the arc |
| **Floor tick** | Hard white mark at `uFloor = 0.76` | **The one element that makes this Footing's dial and not Apple's** |
| Reward | `mix(fillCol, warm, uPast)` once `uProgress > uFloor` | The colour going warm *is* the celebration |
| Edge feather | Radial `smoothstep` across the band | Reads as light, not as a cut-out annulus |
| Leading head | Bloom-able bright spot at the fill's tip | Gives direction of travel even when static |

### Two gotchas worth keeping

**The seam at twelve o'clock.** Normalised angle wraps 1 → 0 there, so `fwidth(t)` returns a
garbage value across that one pixel row and paints a bright wedge over the start of the arc.
Clamp it: `float aa = min(fwidth(t) * 1.5, 0.008);`

**The canvas must be transparent.** `gl={{ alpha: true }}` and *no* `scene.background`. The
page's dark→daylight arc lives in CSS layers behind the canvas; an opaque scene background
paints straight over them and silently kills the entire light arc.

---

## 2. Camera

**The camera barely moves.** Three keyframes, ~1.4 world units of dolly across the whole
page:

```ts
const RINGS_CAM_KEYS = [
  { y: 0.4, z: 17.2, look: 0.3 },
  { y: 0.2, z: 16.4, look: 0.15 },
  { y: 0.0, z: 15.8, look: 0.0 },
]
```

This is the opposite of the usual scrollytelling instinct and it's the right call here. What
changes across the page is *the fill*, not the framing. A dolly reads as a camera move;
holding still reads as attention — which is the product. The dial does its travelling in
world space instead (`position.x`, `scale`), so the viewer's vantage point never shifts under
them.

FOV 34, near 0.1, far 420.

---

## 3. Scroll reactions

`src/scroll.ts` publishes a float **act** — one act per section, measured off each section's
real `offsetTop`/`offsetHeight`, so a section's own height decides how long its beat lasts.
Nothing is expressed in hardcoded `vh`. Add a section to `ACT_SECTIONS` and the ring, the
camera, and the background all pick it up.

`3.37` means "37% of the way from act 3 to act 4." Every track below is lerped against it.

| Act | Section | fill | dim | x | scale | What the viewer sees |
|---|---|---|---|---|---|---|
| 0 | Hero | 0.34 | 1.0 | 4.4 | 1.0 | Dial in the right third, foreground, floor tick visible ahead |
| 1 | Hero pin end | 0.34 | 0.92 | 4.0 | 1.06 | Starts to drift |
| 2 | 01 The problem | 0.34 | **0.19** | 0.4 | 1.55 | Recedes to centre and dims — the old way takes the stage |
| 3 | 02 Pulse | 0.44 | 0.21 | 0.4 | 1.55 | Backdrop; fill creeps |
| 4 | 03 The floor | 0.54 | 0.23 | 0.4 | 1.50 | " |
| 5 | 04 How it works | 0.62 | 0.20 | 0.4 | 1.50 | " |
| 6 | 05 The cycle | 0.71 | 0.22 | 0.4 | 1.48 | Approaching the tick |
| 7 | **06 Why Footing** | **0.94** | **1.0** | 0.4 | **1.75** | **Clears the floor, goes warm, opens to frame the copy inside it** |
| 8 | 07 The offer | 1.0 | 0.42 | 0.4 | 1.90 | Complete, receding |
| 9–10 | 08 FAQ / 09 CTA | 1.0 | 0.0 | 0.4 | 2.0 | Gone; daylight |

Two decisions inside that table are worth defending:

**The floor is deliberately not cleared until act 7.** The gap is what the copy spends five
sections arguing about. Closing it early throws away the only reward the scroll has to give.

**At act 7 the dial scales to 1.75 so the copy sits *inside* it.** Outer radius 2.72 × 1.75 ≈
4.76 world units against a ~4.9 half-frame — that's the ceiling before it crops. "Why
Footing?" framed inside the completed, warm ring is the single image the page is built
toward.

**Everything is lerped toward, never snapped.** Scroll position is a step function at frame
granularity; driving uniforms straight off it visibly stutters. `MathUtils.lerp(current,
target, 0.07)` throughout.

---

## 4. Hover reactions

Deliberately minimal. This is a health product, not a toy — a dial that chases the cursor
undermines the steadiness the whole brand is built on.

**Parallax.** `rotation.y += pointer.x * 0.07`, `rotation.x -= pointer.y * 0.05`. Roughly
4° of travel. Enough that the dial feels like it occupies space; not enough to feel dragged.

**Proximity glow.** The leading head brightens as the cursor nears the dial's centre:

```ts
const cx = (sample('x', t) / 8.1) * 0.5              // world x → NDC-ish
const d  = Math.hypot(pointer.x - cx, pointer.y * (size.height / size.width))
hover.current = Math.max(0, 1 - d / 0.5)
```

**Screen-space distance, not a raycast.** A raycast against a thin annulus only fires on the
band itself, so the response dies everywhere inside the ring — which is exactly where the
cursor sits when someone is reading the readout. Distance-to-centre is what "the cursor is
near the ring" actually means, and it costs one `hypot` per frame instead of a BVH traversal.

**Idle motion** runs regardless: two out-of-phase sines, 14s and 19s periods, ±0.035 rad. A
perfectly static dial reads as a screenshot; a spinning one reads as a loader.

---

## 5. Performance budget

Measured from `npm run build`, 2026-07-27:

| Asset | Raw | Gzip | On critical path? |
|---|---|---|---|
| `index.js` (app) | 24.2 KB | 7.6 KB | ✅ |
| `jsx-runtime.js` (React) | 191.3 KB | ~60 KB | ✅ |
| `index.css` | 26.4 KB | 6.0 KB | ✅ |
| **`HeroScene.js` (three + R3F + drei + postprocessing)** | **993.5 KB** | **263.2 KB** | ❌ lazy |
| Fonts (Inter var + Instrument Serif, latin subsets) | ~90 KB | — | ✅ (swap) |

**Critical path ≈ 242 KB raw / ~74 KB gzip.** The 3D chunk is `React.lazy` + `Suspense` and
is never fetched on the flat tier at all.

### Targets

| Metric | Target | How it's held |
|---|---|---|
| LCP | < 2.0s | **The H1 is DOM text.** It paints before WebGL initialises; the canvas fades in at +1200ms *behind* copy that's already on screen |
| Frame rate | 60fps desktop | One draw call, one 220-segment ring, no lights, no shadows, no textures |
| Canvas entry | 600ms fade | Never a pop-in. The CSS gradient is the poster |
| DPR | 1.5, auto-drop to 1.0 | drei `<PerformanceMonitor onDecline>` |

### Why it's cheap

The whole scene is **one transparent mesh with no lighting**. `RingsScene` carries a single
`ambientLight` and nothing else — the arc is emissive by construction, so a key, a fill, and
a sweep would all cost frames to change nothing. Post-processing is Bloom + Noise + Vignette;
**depth of field is switched off for this variant** because the dial is the subject and
softening it would be self-defeating.

The honest number to watch is the 263 KB gzip 3D chunk. It buys one ring. If that trade ever
stops feeling worth it, §7's fallback already renders the whole page without it.

---

## 6. Mobile

**Mobile gets no canvas at all.** Below 768px, `useCapability` returns the `flat` tier and
`<HeroScene>` is never imported.

This is a deliberate call, not a compromise:

- 70%+ of this traffic will be phones. A thermally-throttled 45fps canvas is a worse
  experience than a beautiful static gradient, and it costs battery on a health app people
  open several times a day.
- The emotional payload — the dark→daylight arc — is **pure CSS** and runs identically on
  every device. The part that actually carries the story is free.
- It removes 263 KB gzip from the majority of sessions.

The 3D is a desktop reward, not the product.

---

## 7. Fallback ladder

Each rung is independently shippable. `src/hero/useCapability.ts` picks one.

| Rung | Condition | What renders |
|---|---|---|
| **0 — Flat** | No WebGL · `prefers-reduced-motion` · `hardwareConcurrency < 4` · Save-Data · **< 768px** | CSS radial gradient + hairlines. No canvas. Every reveal resolves to its final state |
| **1 — Reduced** | Tablet / mid-tier | Canvas, no post-processing |
| **2 — Full** | Desktop with WebGL | Everything |

Reduced-motion is treated as rung 0 rather than as "same scene, slower." The page must be
fully comprehensible with zero motion, and it is: the copy carries the argument, the dial
only illustrates it.

---

## 8. Libraries and setup

```bash
npm create vite@latest site-v2 -- --template react-ts
npm i three @react-three/fiber @react-three/drei @react-three/postprocessing
npm i @fontsource-variable/inter @fontsource/instrument-serif
npm i -D @types/three
```

| Package | Role | Notes |
|---|---|---|
| `three` | Renderer | — |
| `@react-three/fiber` | Three as JSX | Scene graph in the mental model you already have |
| `@react-three/drei` | `PerformanceMonitor`, `Html` | `Html` renders crisp DOM text inside the scene — used for the centre readout |
| `@react-three/postprocessing` | Bloom, Noise, Vignette | Bloom is what makes the arc read as light rather than as a coloured shape |

**Not used, on purpose:** GSAP/ScrollTrigger and Lenis. The blueprint specs both for Phase 3
and they're the right tools for pinned multi-beat timelines. This prototype's scroll is ~110
lines of dependency-free rAF, which is enough to judge whether the beats land and keeps the
critical path small. Swap when the choreography outgrows it.

### Wiring order

1. **Tokens first** — `src/hero/tokens.ts` mirrors the CSS custom properties. The canvas and
   the DOM must read the same palette or the two halves won't fuse.
2. **One `<Canvas>` for the whole page**, `position: fixed` behind the content. Sections are
   *acts*, not separate canvases. Multiple canvases is the most common way this kind of site
   dies.
3. **Scroll module before scene** — get `actProgress()` publishing and verify against
   `--act` in devtools before wiring any keyframes.
4. **Ring, then choreography, then post.** Each stage is checkable on its own.

---

## 9. Traps hit while building this

Real ones, all cost time.

**`position: fixed` must not go on `<Canvas className>`.** That class lands on R3F's internal
wrapper, which it measures with a `ResizeObserver` before creating the renderer. A wrapper
that is itself the fixed element intermittently measures 0×0 on first pass, and R3F then
waits forever for a resize that never comes: canvas element present, drawing buffer stuck at
300×150, no children mounted, **no error anywhere**. Give it a sized parent div to fill.

**Module-level mutable state breaks under Vite HMR.** Vite serves hot-updated modules with a
`?t=` cache-buster, so after an edit some importers hold the new instance and others still
hold the old one. `let act = 0` in `scroll.ts` silently split into two copies: the page's CSS
vars animated from one while the canvas read a frozen zero from the other. Nothing threw.
Anchor shared state to `globalThis`:

```ts
const S = ((globalThis as Record<string, unknown>).__footingScroll ??= { act: 0, ... })
```

**A throw inside `useFrame`/rAF kills the loop silently.** A `vh` reference that was scoped to
a helper rather than the tick body froze the entire choreography with no console error and no
visual clue beyond "nothing moves." When scroll-driven anything stops responding, check
whether the callback is still executing *before* debugging the maths.

**`EffectComposer` types its children as elements.** `{cond && <Effect/>}` and JSX comments
inside it are type errors, not skipped passes. Render two separate composer trees instead.

**Scrims are not optional.** A full-bleed background will put body copy over whatever the
scene happens to be doing there. Left-aligned sections get a directional scrim
(`.hero::before`, `.sec:not(.on-light)::before`); the one centred section whose copy sits
inside a lit dial gets a radial one. Light sections must be *excluded* — the scrim smears
dark across cream.

**Don't fade a fixed daylight layer under statically-light sections.** Text colour flips at a
hard section boundary while a layer's opacity is continuous, so there's always a stretch of
scroll where dark text sits on a half-lit background and turns to mud. Let light sections
paint their own opaque background and carry the dissolve in a gradient at their top edge.
