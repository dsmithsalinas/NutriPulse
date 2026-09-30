import { useEffect, useRef, useState } from 'react'

/**
 * The hero: Today's protein tile playing the app's floor-cleared moment on a loop.
 * The liquid rises while the grams count up, holds at "28g to go", then tops up past the
 * floor: lime floods up through the tile, bubbles leave the top and pop, the count bounces.
 *
 * Mirrors ProteinTile + FloorClearedFizz in the iOS app (Features/Today/Components/TodayTiles.swift).
 * Reduced Motion: a still tile at 112g. Off screen: the loop pauses.
 */
const FLOOR = 140
const LOOP = 9400
const STILL = 3000 // a moment in the hold, for Reduced Motion

const clamp = (x: number) => Math.min(Math.max(x, 0), 1)
const ease = (x: number) => 1 - Math.pow(1 - clamp(x), 3)

const BUBBLES: [x: number, size: number, rise: number, delay: number][] = [
  [16, 14, 72, 0], [32, 10, 100, 0.08], [48, 18, 62, 0.03], [63, 11, 112, 0.14], [78, 13, 84, 0.06], [40, 8, 126, 0.12],
]

function frame(t: number) {
  let fill = 0, lime = 0, grams = 0
  if (t < 500) {
    grams = 0
  } else if (t < 2300) {
    const f = ease((t - 500) / 1800); fill = 80 * f; grams = 112 * f
  } else if (t < 3900) {
    fill = 80; grams = 112
  } else if (t < 4800) {
    const q = ease((t - 3900) / 900); fill = 80 + 20 * q; lime = 100 * q; grams = 112 + 34 * q
  } else {
    fill = 100; lime = 100; grams = 146
  }
  const fade = t > 8500 ? 1 - clamp((t - 8500) / 700) : 1
  const popT = (t - 4800) / 260
  const pop = popT > 0 && popT < 1 ? 1 + 0.1 * Math.sin(Math.PI * popT) : 1
  const p = (t - 4550) / 1500
  const bubbles = BUBBLES.map(([x, size, rise, d]) => {
    const l = (p - d) / 0.78
    if (l <= 0 || l >= 1) return { x, size, top: 16, o: 0 }
    return {
      x,
      size: l > 0.82 ? size * (1 + (l - 0.82) * 3) : size,
      top: 16 - rise * ease(l),
      o: l > 0.82 ? (1 - l) / 0.18 : 1,
    }
  })
  return { fill, lime, grams: Math.round(grams), fade, pop, bubbles, cleared: lime > 40 }
}

const WAVE = 'M0 10 C75 0 75 0 150 10 C225 20 225 20 300 10 C375 0 375 0 450 10 C525 20 525 20 600 10 V20 H0 Z'

function Liquid({ level, color, lime, fade }: { level: number; color: string; lime?: boolean; fade: number }) {
  return (
    // The crest rides above the level, and at the brim it clears the tile's top edge entirely, so a
    // full tile is solid colour with no wave troughs showing the layer beneath (the app flattens
    // its wave near the brim for the same reason).
    <div className={lime ? 'liquid lime' : 'liquid'} style={{ height: `calc(${level}% + ${(level / 100) * 16}px)`, opacity: fade }}>
      <div className="crest">
        <svg viewBox="0 0 600 20" preserveAspectRatio="none" aria-hidden="true"><path d={WAVE} fill={color} /></svg>
      </div>
      <div className="body" style={{ background: color }} />
    </div>
  )
}

export function ProteinTile() {
  const [t, setT] = useState(0)
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)')
    if (reduce.matches) { setT(STILL); return }

    let raf = 0, visible = true, last = 0, elapsed = 0, prev = performance.now()
    const tick = (now: number) => {
      raf = requestAnimationFrame(tick)
      const dt = now - prev
      prev = now
      if (!visible || document.hidden) return
      elapsed += Math.min(dt, 64)
      if (now - last < 33) return
      last = now
      setT(elapsed % LOOP)
    }
    raf = requestAnimationFrame(tick)
    const io = new IntersectionObserver(([e]) => { visible = e.isIntersecting })
    if (ref.current) io.observe(ref.current)
    return () => { cancelAnimationFrame(raf); io.disconnect() }
  }, [])

  const f = frame(t)
  const label = f.cleared ? 'var(--lime-label)' : 'var(--hero-label)'
  const ink = f.cleared ? 'var(--lime-ink)' : '#fff'
  const sub = f.cleared ? 'var(--lime-label)' : 'var(--hero-sub)'

  return (
    <div className="ptile" ref={ref} role="img"
      aria-label="Footing's protein tile: the liquid rises toward a 140 gram protein floor, then turns lime when the floor is cleared.">
      <div className="ptile-box">
        <Liquid level={f.fill} color="#4F46E5" fade={f.fade} />
        <Liquid level={f.lime} color="#D9F99D" lime fade={f.fade} />
        <div className="ptile-top" style={{ color: label }} aria-hidden="true">
          <span className="eb" style={{ color: label }}>Protein</span>
          <span>floor {FLOOR}</span>
        </div>
        <div className="ptile-num" style={{ opacity: f.fade }} aria-hidden="true">
          <span className="n d" style={{ color: ink, transform: `scale(${f.pop})` }}>{f.grams}<small>g</small></span>
          <span className="s" style={{ color: sub }}>{f.cleared ? 'Floor cleared' : `${FLOOR - f.grams}g to go`}</span>
        </div>
      </div>
      {f.bubbles.map((b, i) => (
        <span key={i} className="bubble" aria-hidden="true"
          style={{ left: `${b.x}%`, top: b.top, width: b.size, height: b.size, opacity: b.o }} />
      ))}
    </div>
  )
}
