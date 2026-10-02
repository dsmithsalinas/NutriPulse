import { useCallback, useEffect, useRef, useState } from 'react'
import { useReveal } from '../useReveal'
import { TESTFLIGHT_URL } from '../links'

/*
 * "A day with Pulse": one Thursday, shot cycle day 3, told in six moments. The slides are the
 * social carousel (marketing/social/feature-set-1.3.1, c01-day-with-pulse), rendered as one panorama,
 * so laid edge to edge here the time rail and the light of the day run unbroken. Its cover (1) and end
 * card (8) are bookends on either side; the six moments between them are what the times step through.
 *
 * It plays on its own while on screen, pauses on hover, stops for good once someone swipes or
 * drags, and never autoplays with reduced motion. The Pause button covers WCAG 2.2.2.
 */

const MOMENTS = [
  { file: 2, time: '7:40 AM', alt: '7:40 AM. Breakfast, said out loud: "Greek yogurt with berries" logged by voice, 30g. Pulse: "30g before 8. Good start."' },
  { file: 3, time: '9:00 AM', alt: "9:00 AM. A quick day 3 check-in, appetite 3 of 5. Pulse: \"Appetite's a 3 today. I'll keep ideas small and dense.\" The check-in never changes or recommends a dose." },
  { file: 4, time: '3:30 PM', alt: '3:30 PM. 85g by mid-afternoon on the Today screen. Pulse: "45g to go. One protein-forward dinner covers it."' },
  { file: 5, time: '6:10 PM', alt: '6:10 PM. "Not very hungry tonight. What\'s easy?" Pulse suggests going small and dense, and a protein shake is added.' },
  { file: 6, time: '8:15 PM', alt: '8:15 PM. 136g, floor cleared, and Today turns lime. Pulse: "You\'re there."' },
  { file: 7, time: '9:30 PM', alt: '9:30 PM. Seven days in a row on the protein floor goal. Pulse: "Seven in a row. See you at breakfast."' },
]
const SLIDES = [{ file: 1, time: '', alt: '' }, ...MOMENTS, { file: 8, time: '', alt: '' }]
const DWELL_MS = 4500

function useInView<T extends HTMLElement>() {
  const ref = useRef<T>(null)
  const [inView, setInView] = useState(false)
  useEffect(() => {
    const el = ref.current
    if (!el) return
    const io = new IntersectionObserver(([e]) => setInView(e.isIntersecting), { threshold: 0.35 })
    io.observe(el)
    return () => io.disconnect()
  }, [])
  return [ref, inView] as const
}

export function DayWithPulse() {
  const head = useReveal<HTMLDivElement>()
  const [playerRef, inView] = useInView<HTMLDivElement>()
  const track = useRef<HTMLDivElement>(null)
  const times = useRef<HTMLDivElement>(null)
  const programmatic = useRef(false)
  const [active, setActive] = useState(0)
  const reduced = typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches
  const [playing, setPlaying] = useState(!reduced)
  const [hovering, setHovering] = useState(false)
  const running = playing && inView && !hovering

  // Where each slide's centre sits, measured from the track's own left edge, lead-in margin included.
  const centres = () => {
    const el = track.current
    if (!el) return []
    const left = el.getBoundingClientRect().left - el.scrollLeft
    return [...el.querySelectorAll<HTMLElement>('.day-slide')].map(s => { const r = s.getBoundingClientRect(); return r.left - left + r.width / 2 })
  }

  const goTo = useCallback((i: number) => {
    const el = track.current
    if (!el) return
    programmatic.current = true
    el.scrollTo({ left: centres()[i + 1] - el.clientWidth / 2, behavior: reduced ? 'auto' : 'smooth' })
    setActive(i)
    window.setTimeout(() => { programmatic.current = false }, 700)
  }, [reduced])

  // Keep the highlighted time in step with whatever slide sits in the middle.
  useEffect(() => {
    const el = track.current
    if (!el) return
    const onScroll = () => {
      if (programmatic.current) return
      const mid = el.scrollLeft + el.clientWidth / 2
      const c = centres()
      const nearest = c.reduce((best, x, i) => Math.abs(x - mid) < Math.abs(c[best] - mid) ? i : best, 0)
      setActive(Math.max(0, Math.min(MOMENTS.length - 1, nearest - 1)))
    }
    el.addEventListener('scroll', onScroll, { passive: true })
    return () => el.removeEventListener('scroll', onScroll)
  }, [])

  // On a phone the time row scrolls; keep the current time in it without moving the page.
  useEffect(() => {
    const row = times.current
    const chip = row?.children[active] as HTMLElement | undefined
    if (!row || !chip || row.scrollWidth <= row.clientWidth) return
    row.scrollTo({ left: chip.offsetLeft - row.offsetLeft - (row.clientWidth - chip.offsetWidth) / 2, behavior: reduced ? 'auto' : 'smooth' })
  }, [active, reduced])

  // Start centred on the first moment.
  useEffect(() => { goTo(0) }, [goTo])

  // Autoplay: move on after a dwell, back to the start after the last moment.
  useEffect(() => {
    if (!running) return
    const t = window.setTimeout(() => goTo((active + 1) % MOMENTS.length), DWELL_MS)
    return () => window.clearTimeout(t)
  }, [running, active, goTo])

  // A swipe, drag, or wheel on the strip means the visitor is driving: stop autoplay.
  const takeOver = () => { if (!programmatic.current) setPlaying(false) }

  return (
    <section className="sec day" id="day" aria-labelledby="day-title">
      <div className="wrap">
        <div className="split split-end" data-reveal ref={head}>
          <div className="stack">
            <p className="eb" style={{ color: 'var(--primary-text)' }}>A day with Pulse</p>
            <h2 className="h2 d" id="day-title">One Thursday, breakfast to bed.</h2>
          </div>
          <p className="lede">Shot cycle day 3, a 130g floor, and appetite on the low side. Here’s what Pulse noticed across the day, and what it said.</p>
        </div>
      </div>

      <div className="day-player" ref={playerRef}
        role="region" aria-roledescription="carousel" aria-label="A day with Pulse, six moments"
        onMouseEnter={() => setHovering(true)} onMouseLeave={() => setHovering(false)}>
        <div className="day-track" ref={track} tabIndex={0}
          onPointerDown={takeOver} onWheel={takeOver} onTouchStart={takeOver}
          onKeyDown={(e) => {
            if (e.key === 'ArrowRight') { e.preventDefault(); setPlaying(false); goTo(Math.min(active + 1, MOMENTS.length - 1)) }
            if (e.key === 'ArrowLeft') { e.preventDefault(); setPlaying(false); goTo(Math.max(active - 1, 0)) }
          }}>
          {SLIDES.map((m, i) => {
            const bookend = !m.time
            return (
              <div className="day-slide" key={m.file} {...(bookend
                ? { 'aria-hidden': true }
                : { role: 'group', 'aria-roledescription': 'slide', 'aria-label': `${i} of ${MOMENTS.length}, ${m.time}` })}>
                <img src={`/day/day-${m.file}-1080.webp`} srcSet={`/day/day-${m.file}-540.webp 540w, /day/day-${m.file}-1080.webp 1080w`}
                  sizes="(max-width: 640px) 82vw, 420px" width={1080} height={1350} alt={m.alt} loading={i < 3 ? 'eager' : 'lazy'} decoding="async" />
              </div>
            )
          })}
        </div>

        <div className="wrap">
          <div className="day-controls">
            <div className="day-times" ref={times} role="group" aria-label="Jump to a time">
              {MOMENTS.map((m, i) => (
                <button key={m.time} type="button" className="day-time" aria-current={i === active ? 'true' : undefined}
                  onClick={() => goTo(i)}>
                  {m.time}
                  {i === active && running && <span className="day-fill" key={`fill-${active}`} style={{ animationDuration: `${DWELL_MS}ms` }} aria-hidden="true" />}
                </button>
              ))}
            </div>
            <div className="day-buttons">
              <button type="button" className="day-icon" aria-label="Previous moment" onClick={() => { setPlaying(false); goTo(Math.max(active - 1, 0)) }} disabled={active === 0}>
                <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M15 18l-6-6 6-6" /></svg>
              </button>
              <button type="button" className="day-icon" aria-label="Next moment" onClick={() => { setPlaying(false); goTo(Math.min(active + 1, MOMENTS.length - 1)) }} disabled={active === MOMENTS.length - 1}>
                <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M9 18l6-6-6-6" /></svg>
              </button>
              <button type="button" className="day-play" onClick={() => setPlaying(p => !p)} aria-pressed={!playing}>
                {playing ? 'Pause' : 'Play'}
              </button>
              <a className="btn btn-primary day-cta" href={TESTFLIGHT_URL}>Join the beta</a>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
