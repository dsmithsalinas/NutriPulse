import { useReveal } from '../useReveal'

/**
 * Section 01 — Recognition.
 *
 * Goal: prove we know their last failure better than they can describe it.
 * Drives: keep scrolling. No CTA here on purpose — asking for the click while
 * the visitor is sitting in the bad feeling reads as opportunism.
 *
 * The load-bearing move is the attribution flip: the failure belongs to the
 * tools, not the user. A visitor who finishes this section thinking "that
 * wasn't my fault" is listening for the rest of the page. That's the
 * non-shaming law (docs/pulse-persona.md §3) applied to marketing, not just
 * to Pulse.
 */

/** The scorecard every other app shows. Cold, correct, and joyless — the
 *  horror is that it's completely normal, so don't caricature it. */
const SCORECARD = [
  { label: 'Calories', value: '2,320', delta: '+320 over' },
  { label: 'Protein', value: '88g', delta: '−38 under' },
  { label: 'Fiber', value: '13g', delta: '−12 under' },
  { label: 'Streak', value: 'Broken', delta: 'was 6 days' },
]

export function Section01() {
  const head = useReveal<HTMLDivElement>()
  const card = useReveal<HTMLDivElement>(0.3)
  const quote = useReveal<HTMLDivElement>(0.4)
  const turn = useReveal<HTMLDivElement>(0.4)

  return (
    <section id="s01" className="s01">
      <div className="wrap">
        <div className="s01-top">
          <div className="s01-copy" data-reveal ref={head}>
            <p className="eyebrow-sm">The problem</p>
            <h2>Tracking shouldn&rsquo;t feel like getting graded.</h2>
            <p className="s01-body">
              Every app on your phone tells you when you went over. When you fell short.
              When you were off-plan. Four numbers, all of them red, every night.
            </p>
          </div>

          <div className="s01-card-wrap" data-reveal ref={card}>
            <div className="scorecard" aria-label="A typical daily summary from a conventional tracking app">
              <div className="scorecard-head">
                <span>Daily summary</span>
                <span className="scorecard-date">Thu, Jul 24</span>
              </div>
              <ul className="scorecard-rows">
                {SCORECARD.map((r) => (
                  <li key={r.label}>
                    <span className="sc-label">{r.label}</span>
                    <span className="sc-value">{r.value}</span>
                    <span className="sc-delta">{r.delta}</span>
                  </li>
                ))}
              </ul>
              <div className="scorecard-foot">0 of 4 goals met</div>
            </div>
            <p className="scorecard-caption">Every other app. Every single day.</p>
          </div>
        </div>

        <div className="s01-quote-wrap" data-reveal ref={quote}>
          <blockquote className="s01-quote">
            So one day you look at the red numbers and think&thinsp;&mdash;&thinsp;
            <em>why am I doing this to myself?</em>
          </blockquote>
        </div>

        <div className="s01-turn" data-reveal ref={turn}>
          <p className="s01-turn-lede">
            And you quit. Not because you lack discipline&thinsp;&mdash;&thinsp;because nothing
            about that day was worth coming back to.
          </p>
          <p className="s01-turn-flip">
            Footing starts from the opposite premise: you hit your goals when something is
            actually <strong>in your corner</strong>.
          </p>
        </div>
      </div>
    </section>
  )
}
