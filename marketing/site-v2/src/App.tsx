import { lazy, Suspense, useEffect } from 'react'
import { startScrollTracking } from './scroll'
import { useCapability } from './hero/useCapability'
import { Section01 } from './sections/Section01'
import { Section02, Section03, Section04, Section05, Section06 } from './sections/Story'
import { Section07, Section08, Section09, Footer } from './sections/Close'

// The 3D chunk is never on the critical path — the hero paints as text first.
const HeroScene = lazy(() =>
  import('./hero/HeroScene').then((m) => ({ default: m.HeroScene })),
)

function BrandMark({ size = 30 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" aria-hidden="true">
      <defs>
        <linearGradient id="bm" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="#6366F1" />
          <stop offset="100%" stopColor="#8B5CF6" />
        </linearGradient>
        <radialGradient id="bmg" cx="0.28" cy="0.12" r="0.9">
          <stop offset="0%" stopColor="#fff" stopOpacity="0.3" />
          <stop offset="58%" stopColor="#fff" stopOpacity="0" />
        </radialGradient>
      </defs>
      <rect width="64" height="64" rx="14.32" fill="url(#bm)" />
      <rect width="64" height="64" rx="14.32" fill="url(#bmg)" />
      <g transform="translate(12.80, 12.80) scale(0.38)">
        <circle cx="50" cy="50" r="33" stroke="#fff" strokeWidth="6" fill="none" opacity="0.24" />
        <path d="M 50 17 A 33 33 0 1 1 18.99 61.29" stroke="#fff" strokeWidth="6" strokeLinecap="round" fill="none" />
        <circle cx="18.99" cy="61.29" r="7.5" fill="#fff" />
      </g>
    </svg>
  )
}

export default function App() {
  const tier = useCapability()

  useEffect(() => startScrollTracking(), [])

  return (
    <>
      <div className="bg-lerp" />

      {tier === 'full' ? (
        <Suspense fallback={<div className="flat-scene" />}>
          <HeroScene />
        </Suspense>
      ) : (
        <div className="flat-scene" />
      )}

      <div className="bleed">
        <div className="bleed-glow" />
      </div>

      <nav>
        <a className="brand" href="#top">
          <BrandMark />
          <span>Footing</span>
        </a>
        <div className="nav-links">
          <a href="#s01">How it works</a>
          <a href="#s01">For GLP-1</a>
          <a className="btn sm nav-cta nav-cta-link" href="#s01">
            Join the beta
          </a>
        </div>
      </nav>

      <div className="hero-pin" id="top">
        <header className="hero">
          <div className="wrap">
            <div className="hero-copy">
              <p className="eyebrow">
                <span className="dot" />
                Now on TestFlight · iPhone
              </p>

              <h1>
                <span className="line"><span>Coached,</span></span>
                <span className="line"><span>not scolded.</span></span>
              </h1>

              <p className="sub">
                On a GLP-1 the goal flips: it&rsquo;s not about eating less, it&rsquo;s about
                eating <em>enough</em>. Footing tracks the protein floor that protects your
                results &mdash; and puts a coach in your corner who&rsquo;s actually read your
                whole day.
              </p>

              <div className="cta-row">
                <a className="btn" href="#s01">Join the beta →</a>
                <a className="btn-text" href="#s01">See how it works ↓</a>
              </div>

              <p className="micro">Free during the beta · No card · iPhone</p>

            </div>
          </div>
        </header>
      </div>

      <Section01 />
      <Section02 />
      <Section03 />
      <Section04 />
      <Section05 />
      <Section06 />
      <Section07 />
      <Section08 />
      <Section09 />
      <Footer mark={<BrandMark size={26} />} />
    </>
  )
}
