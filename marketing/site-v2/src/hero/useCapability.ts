import { useEffect, useState } from 'react'

export type Tier = 'full' | 'flat'

/**
 * The degradation ladder from the blueprint, collapsed to the two rungs that
 * matter for the hero: `full` gets the canvas, `flat` gets the CSS scene.
 *
 * Mobile falls to `flat` on purpose. Most of this traffic is phones, and a
 * thermally-throttled 45fps canvas is worse than a beautiful gradient — the
 * subgrade→daylight arc is the emotional payload and it costs nothing in CSS.
 */
/**
 * WebGL support, probed exactly once.
 *
 * The probe MUST cache and MUST release the context it creates. Browsers cap
 * live WebGL contexts (~16 per process) and drop the oldest when you exceed it.
 * Probing on every call — this used to run on every resize event — burns
 * through that budget in seconds, and the symptom is baffling: the page starts
 * fine, then "THREE.WebGLRenderer: Context Lost", then the real canvas silently
 * fails to get a context at all and R3F never boots, with no error thrown.
 */
let webglSupported: boolean | null = null

function probeWebGL(): boolean {
  if (webglSupported !== null) return webglSupported
  try {
    const c = document.createElement('canvas')
    const gl = c.getContext('webgl2') ?? c.getContext('webgl')
    webglSupported = !!gl
    gl?.getExtension('WEBGL_lose_context')?.loseContext()
  } catch {
    webglSupported = false
  }
  return webglSupported
}

function detect(): Tier {
  if (typeof window === 'undefined') return 'flat'

  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return 'flat'

  // A background or not-yet-laid-out tab reports innerWidth 0. Treat that as
  // "unknown", not "phone" — otherwise the page decides it's mobile before it
  // has been measured and never picks the canvas back up. The resize listener
  // re-runs this once real layout arrives.
  const w = window.innerWidth
  if (w > 0 && w < 768) return 'flat'
  if ((navigator.hardwareConcurrency ?? 8) < 4) return 'flat'

  const conn = (navigator as Navigator & { connection?: { saveData?: boolean } }).connection
  if (conn?.saveData) return 'flat'

  return probeWebGL() ? 'full' : 'flat'
}

export function useCapability(): Tier {
  // Start flat so the first paint is never blocked on a WebGL probe; upgrade
  // after mount. This is also what keeps the H1 as the LCP element.
  const [tier, setTier] = useState<Tier>('flat')

  useEffect(() => {
    setTier(detect())

    const mq = window.matchMedia('(prefers-reduced-motion: reduce)')
    const onChange = () => setTier(detect())

    // Debounced, because crossing the 768px breakpoint tears down and rebuilds
    // the whole WebGL scene — doing that on every frame of a window drag is
    // expensive and racy.
    let t: ReturnType<typeof setTimeout>
    const onResize = () => {
      clearTimeout(t)
      t = setTimeout(onChange, 250)
    }

    mq.addEventListener('change', onChange)
    window.addEventListener('resize', onResize)
    return () => {
      clearTimeout(t)
      mq.removeEventListener('change', onChange)
      window.removeEventListener('resize', onResize)
    }
  }, [])

  return tier
}
