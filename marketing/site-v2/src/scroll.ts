/**
 * Page-level scroll choreography.
 *
 * Publishes every frame:
 *   heroProgress()  0 → 1 across the hero pin — copy drift, nav CTA dock
 *   actProgress()   0 → N as a float, indexing keyframes in Rings/HeroScene
 *   --scene-p       0 → 1 across the whole choreographed range
 *   --light-p       0 → 1 across the daylight transition (the offer section)
 *
 * One act per section, so a section's own height decides how long its beat
 * lasts. Add a section to ACT_SECTIONS and the camera, the ring, and the
 * background all pick it up — nothing is expressed in hardcoded vh.
 *
 * Still deliberately dependency-free. Phase 3 swaps this for Lenis + GSAP
 * ScrollTrigger, which is what pinned multi-beat timelines actually want; this
 * is enough to judge whether the beats land.
 */

export const PIN_VH = 0.4

/** Section ids in page order. Act i + 2 is section ACT_SECTIONS[i]. */
export const ACT_SECTIONS = [
  's01', // the problem
  's02', // meet Pulse
  's03', // the protein floor
  's04', // how it works
  's05', // built for the cycle
  's06', // why Footing — the ring clears the floor here
  's07', // the offer — daylight transition
  's08', // questions
  's09', // closing CTA
] as const

export const ACT_COUNT = ACT_SECTIONS.length + 2

/**
 * State lives on a global singleton rather than in module scope.
 *
 * Vite serves hot-updated modules with a `?t=` cache-buster, so after an edit
 * some importers hold the new instance and others still hold the old one. With
 * module-level `let act`, that silently splits into two copies: the page's CSS
 * vars animate from one while the canvas reads a frozen zero from the other,
 * and nothing errors. Anchoring to globalThis keeps one source of truth no
 * matter how many module instances exist.
 */
type ScrollState = { hero: number; act: number; running: boolean }

const S: ScrollState = ((globalThis as Record<string, unknown>).__footingScroll ??= {
  hero: 0,
  act: 0,
  running: false,
}) as ScrollState

export const heroProgress = () => S.hero
export const actProgress = () => S.act

const clamp01 = (n: number) => (n < 0 ? 0 : n > 1 ? 1 : n)

/**
 * Scroll positions at which each act is fully reached. Recomputed per frame so
 * font loading, image decode, and resize can't desync the camera from the copy.
 */
function stops(): number[] {
  const vh = window.innerHeight
  const marks = [0, vh * PIN_VH]

  for (const id of ACT_SECTIONS) {
    const el = document.getElementById(id)
    if (!el) {
      // Keep the array length stable even if a section hasn't mounted, so act
      // indices never shift underneath the keyframe tables.
      marks.push(marks[marks.length - 1] + vh)
      continue
    }
    // Settle partway in, not at the end: the move should finish while the copy
    // is still being read rather than continuing underneath it.
    //
    // Minus half a viewport because scrollY is the *top* of the window. Without
    // it the act only lands once the settle point reaches the top edge — by
    // which time the section is half gone, and the ring is always a beat behind
    // the copy it's meant to be scoring.
    marks.push(el.offsetTop + el.offsetHeight * 0.45 - vh * 0.5)
  }

  return marks
}

export function startScrollTracking() {
  if (S.running) return () => {}
  S.running = true

  const root = document.documentElement
  let frame = 0

  const tick = () => {
    const y = window.scrollY
    const vh = window.innerHeight
    const marks = stops()

    S.hero = clamp01(y / Math.max(1, marks[1]))

    // Piecewise lerp → a float like 3.37 meaning "37% of the way from act 3 to
    // act 4".
    let next = 0
    for (let i = 1; i < marks.length; i++) {
      const span = Math.max(1, marks[i] - marks[i - 1])
      next = i - 1 + clamp01((y - marks[i - 1]) / span)
      if (y < marks[i]) break
    }
    S.act = next

    root.style.setProperty('--hero-p', String(S.hero))
    root.style.setProperty('--act', String(S.act))
    root.style.setProperty('--scene-p', String(S.act / (marks.length - 1)))
    // Daylight is owned by the light sections themselves (they paint an opaque
    // background), so this drives only the fixed nav, which has to flip from
    // light-on-dark to dark-on-light as it crosses the boundary. Measured off
    // s08's real position rather than an act number: act spacing depends on
    // section heights, and the nav flipping even slightly early leaves white
    // links on a cream background.
    const s08 = document.getElementById('s08')
    root.style.setProperty(
      '--light-p',
      s08 ? String(clamp01((y + vh * 0.62 - s08.offsetTop) / (vh * 0.3))) : '0',
    )

    frame = requestAnimationFrame(tick)
  }

  frame = requestAnimationFrame(tick)

  return () => {
    cancelAnimationFrame(frame)
    S.running = false
  }
}
