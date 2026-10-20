# Pulse ring — canonical brand asset system

Version 2 · 2026-10-01 · Approved foundation, finalized state system. This file owns Pulse ring construction, state meaning, usage and motion. SVGs live in [marketing/characters/pulse-ring](../marketing/characters/pulse-ring/README.md). Implementation in the running app is a separate integration task.

## Brand architecture and authority

Footing = product/brand. Pulse = intelligence/coach, represented by the ring. Cove = emotional companion. Pulse provides information and guidance; Cove reacts and supports. They may appear together but must never merge visually or functionally. No face, eyes, mouth, mascot-like behavior, sparkles, chatbot bubble, or generic AI decoration on Pulse. Cove alone owns emotional character behavior.

The approved foundation derives from `orbit-exports/export/footing-mark.svg` and the arc-track-node identity in `Shared/PulseMark.swift`. These assets do not redesign the Footing logo or Cove. [Brand architecture](brand-architecture.md), [Pulse voice](pulse-persona.md), [Cove identity](cove.md) and [Cove motion](cove-motion.md) remain separate authorities. Current Daylight tokens supersede conflicting legacy marketing exports.

## Canonical design rules

1. Ring geometry communicates state first.
2. Color communicates meaning/emphasis second.
3. A center glyph only clarifies the state when needed.
4. The signature node is fixed at (18.99, 61.29), radius 7.5 in a 100×100 viewBox: roughly 7–8 o’clock. Never move, scale independently, orbit, pulse, or attach it to the progress endpoint.
5. Indigo means active Pulse behavior. Lime `#D9F99D` means positive completion/floor cleared. Navy/neutral tones mean neutral, rest, or lower emphasis. Pale tonal equivalents are used on dark surfaces.
6. Pulse is always faceless and product-like. No character performance, bounce, excitement, warning/error framing, or red/orange alarm treatment in this system.

## Geometry and sizes

Center (50,50), ring radius 33, stroke 6, round caps/joins. Ready and non-determinate states retain the 250° clockwise arc from twelve o’clock. Fixed node is rendered last above the ring. The faint remainder is a full track, not a second progress ring. Keep 8 viewBox units of external clear space. Do not mirror, skew or rotate the complete mark.

Progress is the explicit data-bearing exception: foreground sweep = `360 × clamp(value / denominator, 0, 1)` degrees clockwise from twelve. 60% = 216°. Omit the center glyph. At zero omit the active arc; at 100% use a full circle. The fixed signature node stays at 250° regardless of progress; it is branding, not another data point or the moving endpoint. Pair with an explicit percentage/amount label so its small protrusion cannot be mistaken for filled data.

Floor Cleared uses a completed ring plus check, even when the floor is lower than the daily target. It is a categorical confirmation, not a claim that every nutrition target reached 100%. The v1 rule to keep an opening on success and its center progress rail are superseded.

Export masters in `svg/` have the shared viewBox and default 80×80 dimensions. Exact 32, 48 and 80 px variants are in `svg/32/`, `svg/48/`, and `svg/80/`; geometry is identical, never rescaled independently. At 32 px the ring stroke is 1.92 px, node diameter 4.8 px, and glyph stroke 1.28 px. Below 32 px use the shipped neutral identity with a label; this state set is validated at 32/48/80.

## Palette and contrast

| Role | Daylight | Dark surface |
|---|---|---|
| Active/Pulse | #4F46E5 | #C7D2FE (pale indigo) |
| Neutral / Check-in / Rest | #0F172A | #CBD5E1 (pale neutral) |
| Track | #B8BFCD | #817EA6 |
| Completion | #D9F99D | #D9F99D |
| Completion boundary / check | #4D7C0F / #1A2E05 | #1A2E05 check on lime |
| Thinking segment | #1E1B4B | #EEF1F6 |

The dark track is an opaque muted indigo-neutral, replacing the faint v1 opacity treatment. It remains visible at 32 px on both `#1E1B4B` and `#2A2766` without matching the active stroke’s brightness. See [validation](../marketing/characters/pulse-ring/validation.md) for measured contrast. On light, the track is supporting context; active stroke, node, labels and cue carry meaning. A lime completion stroke on light is edged with thin dark-lime inner/outer boundaries; the node receives an inset outline that does not change its outer radius. Never use lime alone for small text or a low-contrast essential boundary on white.

Use a visible state label. Retest any other surface; do not paste the dark variant over an arbitrary photo. Avoid color-only meaning. The 60% portion has an exact geometric sweep (round caps add a small optical extension); do not count the fixed node as a second progress segment.

## State definitions

### Ready (`ready`)

- **Meaning / use:** Pulse is available, no active capture or processing. Use in a Pulse header, entry point or neutral avatar.
- **Construction / color:** established 250° arc, track, fixed node, empty center; navy/neutral.
- **Static:** the supplied neutral mark, no animation.
- **Optional motion / reduced motion:** none; same static asset in both settings.
- **Do not use:** recording, processing, progress, urgent failures, or to suggest Pulse has begun speaking unprompted.

### Listening (`listening`)

- **Meaning / use:** microphone capture is actually active in Talk to Log or a supported voice flow.
- **Construction / color:** established open arc, fixed node and three small vertical waveform bars; active indigo. Foundation glyph retained.
- **Static:** unequal bar lengths communicate audio capture alongside “Listening.”
- **Optional motion:** slow 2.8 s arc-opacity breathing between .88 and 1; bars vary minimally with real input amplitude. Never scale/move the node. Stop immediately when capture stops.
- **Reduced motion:** supplied still, constant bars/opacity and visible capture label/control.
- **Do not use:** when the microphone is off, merely available, or transcribing after capture has ended (use Thinking).

### Thinking (`thinking`)

- **Meaning / use:** Pulse is considering an in-flight request; duration is unknown.
- **Construction / color:** empty center; a 36° tonal segment lies on the existing indigo ring, with its static leading position at 60–96°. No interior spinner or extra orbit.
- **Static:** highlighted segment at 60–96°, paired with “Thinking.”
- **Optional motion:** segment travels slowly between start angles 20° and 190° along the existing arc, easing forward and back over 4.8 s. The segment never crosses the fixed node or rotates the entire ring. No chase dots or accelerating spinner.
- **Reduced motion:** supplied fixed segment and label; announce only meaningful request state changes.
- **Do not use:** known numeric progress, idle decoration, or as a claim that Pulse has human feelings.

### Progress (`progress`)

- **Meaning / use:** measured progress with a known denominator, such as 81.6g of an illustrative 136g protein floor (60%).
- **Construction / color:** indigo clockwise ring sweep equal to percentage; no center glyph; fixed node. The included asset is precisely 216° / 60%.
- **Static:** render actual value with amount and denominator outside the ring; the example asset must not stand in for arbitrary data.
- **Optional motion:** interpolate only between real values over 240–400 ms; no endless loading motion or fabricated forward movement. Keep node fixed.
- **Reduced motion:** jump directly to the true sweep; update adjacent value text without counting animation.
- **Do not use:** an unknown-duration request, unspecified target, or the sample 60% as user data. A floor and full daily target must never be conflated.

### Floor Cleared (`floor-cleared`)

- **Meaning / use:** confirmed protein floor met. Context board shows 136g against an explicitly illustrative 136g floor; production uses the user’s actual floor.
- **Construction / color:** completed ring in #D9F99D, fixed lime node, small check on a lime disc. Dark-lime boundaries preserve visibility on Daylight. The foundation check is retained; the full ring implements the explicit completion decision.
- **Static:** completed lime ring and check with amount and “Floor cleared.”
- **Optional motion:** complete the sweep and transition to lime over 320 ms once upon confirmed completion. No bounce, scale pop, sparks or confetti. Node may change color but not position or size.
- **Reduced motion:** immediate static success asset and label.
- **Do not use:** partial progress, a fabricated target, all-goals-met claims, or health/outcome guarantees.

### Check-in (`check-in`)

- **Meaning / use:** a low-pressure invitation to provide context or consider a next step, including a lower-protein day. “Check-in” matches existing Pulse product language.
- **Construction / color:** neutral open ring and fixed node; a short horizontal pause mark replaces the former vertical alert stroke. No exclamation, alarm color or notification badge.
- **Static:** quiet ring with pause mark plus the explicit “Check-in” label and a specific optional question.
- **Optional motion / reduced motion:** static in both modes; no attention-seeking pulse.
- **Do not use:** errors, emergencies, diagnoses, noncompliance judgments, or an unsolicited new chat. Respect the product’s existing user-initiated chat and notification settings.

### Rest (`rest`)

- **Meaning / use:** evening/rest context or an explicit quieter state.
- **Construction / color:** foundation crescent inside the established ring, fixed node; navy on light and pale neutral on dark.
- **Static:** supplied crescent and label.
- **Optional motion:** preferably static; a single 600 ms settle in ring opacity on entry is sufficient. No breathing mascot, sleep symbols or indefinite flashing.
- **Reduced motion:** immediate static asset.
- **Do not use:** to imply sleep tracking, automatic health inference, microphone activity or app suspension unless those are actual product functions.

### Pulse Coaching (`coaching`)

- **Meaning / use:** Pulse is actively delivering guidance next to a real recommendation message.
- **Construction / color:** indigo ring with a single restrained smooth wave through the center. Replaces the menu-like three lines; no enclosing bubble, face, sparkle or heartbeat shape.
- **Static:** one smooth guidance wave and visible Pulse attribution next to the recommendation.
- **Optional motion:** for real audio output only, vary wave amplitude slightly with output (3–9 units) while its center and ring/node remain fixed. For text, allow a single 240 ms stroke reveal on reply arrival, then hold still. Never animate silent text as continuous speech.
- **Reduced motion:** static wave, full visible text; audio controls remain usable.
- **Do not use:** background recording, request processing, navigation menus, or to attribute a coaching message to Cove.

## Asset use, accessibility and production

SVGs are self-contained vectors: no scripts, animations, raster images, fonts or external references. Optional motion above is an implementation contract, not embedded animation. All motion must honor Reduce Motion. Use `alt` on external image elements; for decorative duplication beside a visible label use empty alt. Standalone inline SVGs include an accessible name; remove role/name and set `aria-hidden="true"` when decorative. Progress widgets need a host progressbar with the real value/min/max, plus text; a static SVG accessible label alone is not a live progress control. Announce completion once, not animation frames.

Use [generate.py](../marketing/characters/pulse-ring/generate.py) to rebuild all 64 current exports; `svg(state, dark, size, progress)` supports real progress fractions, zero and full-circle cases. `manifest.json` inventories the canonical files. Keep exact old assets in `archive/v1/`, not in new designs. Migration: `neutral` → `ready`, `attention` → `check-in`, `speaking` → `coaching`. Update external consumers before deleting their cached URLs; these asset changes do not migrate app code automatically.

## Reference boards and release status

- [Icon sheet](../marketing/characters/pulse-ring/preview.html): all eight states, both surfaces, exact 32/48/80 px sizes.
- [Pulse in context](../marketing/characters/pulse-ring/context.html): eight illustrative product/marketing compositions using actual exported files. Copy and nutrition values are examples, not live user data or new shipped screens. Cove is shown as a CSS viewport crop of the unchanged approved source board; no new render or cutout is claimed.

The identity, state names, fixed node, state geometry, palette roles and SVG exports are canonical. Remaining provisional items are motion timing/amplitude pending in-product review, integration with real recording/audio/progress signals, and user comprehension checks for Thinking/Coaching at small sizes. Context-board copy, sample 136g floor and layouts are demonstration material, not a broader brand redesign or product launch. No outstanding approval is needed to use these static assets according to this specification.
