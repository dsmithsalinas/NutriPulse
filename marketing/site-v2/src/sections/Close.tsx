import { useReveal } from '../useReveal'

/**
 * Sections 07–09 plus the footer — the close.
 *
 * This is where the page turns to daylight. 07 carries the transition (it starts
 * dark and ends light, driven by --light-p from src/scroll.ts); 08 and 09 are
 * statically light via .on-light. The arc closes where it began — same promise,
 * opposite light level.
 */

/* ─────────────────────────────── 07 — The offer ──────────────────────── */

export function Section07() {
  const head = useReveal<HTMLDivElement>()
  const card = useReveal<HTMLDivElement>(0.3)

  return (
    <section id="s07" className="sec sec-offer">
      <div className="wrap">
        <div className="sec-head" data-reveal ref={head}>
          <p className="eyebrow-sm">The beta</p>
          <h2>Free while we&rsquo;re building it.</h2>
        </div>

        <div className="offer" data-reveal ref={card}>
          <ul className="offer-list">
            <li>
              <strong>Everything, unlocked.</strong> Voice logging, the full coach, GLP-1
              tracking, workouts, trends. No tiers, no upsell inside the app.
            </li>
            <li>
              <strong>Free for the whole beta.</strong> No card, no trial clock. What
              it&rsquo;ll cost afterwards isn&rsquo;t decided yet&thinsp;&mdash;&thinsp;when
              it is, you&rsquo;ll hear it from us before you hear it from a paywall.
            </li>
            <li>
              <strong>iPhone only, for now.</strong> Footing is small enough that one
              person can build it properly, and that means one platform first.
            </li>
          </ul>

          <a className="btn btn-lg" href="#s09">
            Join the beta →
          </a>

          <p className="offer-steps">
            <strong>Two steps, in this order.</strong> Install{' '}
            <a href="https://apps.apple.com/app/testflight/id899247664">
              Apple&rsquo;s free TestFlight app
            </a>
            , then tap the button above in Safari on your iPhone. Opening TestFlight on its
            own &mdash; or tapping the link inside another app&rsquo;s browser &mdash; lands
            you on an empty screen asking for a code you don&rsquo;t need.
          </p>
        </div>
      </div>
    </section>
  )
}

/* ─────────────────────────────── 08 — Questions ──────────────────────── */

/**
 * Ordered by emotional weight, not by frequency. The first and the fourth are
 * the two that actually decide it: "will this be another thing I quit" and
 * "what happens when I stop".
 */
const QA: { q: string; a: React.ReactNode }[] = [
  {
    q: 'I’ve quit every tracking app I’ve tried. Why would this be different?',
    a: (
      <>
        Because what made you quit wasn&rsquo;t the tracking&thinsp;&mdash;&thinsp;it was the
        verdict at the end of it. Footing doesn&rsquo;t grade your day. It tells you
        what&rsquo;s left and how to get there, and it says something when you show up.
      </>
    ),
  },
  {
    q: 'Is this just another tracker with a chatbot bolted on?',
    a: (
      <>
        The coach isn&rsquo;t sitting next to your log&thinsp;&mdash;&thinsp;it reads it.
        Pulse sees food, weight, training, sleep, and your injection schedule together, and
        answers with your numbers rather than general advice. That connection is the
        product; the log is just where it gets its facts.
      </>
    ),
  },
  {
    q: 'Do I have to log everything?',
    a: (
      <>
        No. Protein is the number that matters most on a GLP-1, and Footing is built so
        that one is easy to hit. Log what you can. Pulse works with what it has and
        won&rsquo;t nag you for the rest.
      </>
    ),
  },
  {
    q: 'What happens when I come off the medication?',
    a: (
      <>
        The muscle you protected on the way down is what holds the result afterwards.
        That&rsquo;s the whole reason Footing centres on protein rather than calories
        &mdash; the habit that matters most later is the one you&rsquo;re building now.
      </>
    ),
  },
  {
    q: 'Is my health data private?',
    // Every claim below is drawn from the Privacy Policy (public/privacy.html),
    // which is the source of truth. If the practices there change, change this
    // answer in the same commit — a marketing page that contradicts the policy
    // is worse than one that says nothing.
    a: (
      <>
        We don&rsquo;t sell it. It&rsquo;s stored with access scoped to your account, so no
        other user can reach it. When you message Pulse, your message and a snapshot of your
        relevant data go to our AI provider so it can answer about your day rather than
        generically &mdash; and Pulse only ever sees your own. If you connect Apple Health,
        that data is only ever used to show you and to give Pulse context, never for
        advertising. You can delete everything, permanently, from inside the app. The{' '}
        <a href="/privacy">Privacy Policy</a> names every provider and exactly what each
        one receives.
      </>
    ),
  },
  {
    q: 'Is any of this medical advice?',
    a: (
      <>
        No. Footing is a nutrition and wellness tracker, not a medical device. Pulse
        won&rsquo;t diagnose anything and won&rsquo;t tell you to change a dose. It can
        remind you of the schedule you set&thinsp;&mdash;&thinsp;that&rsquo;s the line, and
        it doesn&rsquo;t move.
      </>
    ),
  },
  {
    q: 'Android?',
    a: (
      <>
        Not yet. Join the beta anyway and you&rsquo;ll be the first to know when there is
        one.
      </>
    ),
  },
]

export function Section08() {
  const head = useReveal<HTMLDivElement>()
  const list = useReveal<HTMLDivElement>(0.15)

  return (
    <section id="s08" className="sec sec-faq on-light">
      <div className="wrap">
        <div className="sec-head" data-reveal ref={head}>
          <p className="eyebrow-sm">Straight answers</p>
          <h2>The things you&rsquo;re actually wondering.</h2>
        </div>

        <div className="faq" data-reveal ref={list}>
          {QA.map((item) => (
            <details key={item.q}>
              <summary>
                {item.q}
                <span className="faq-chev" aria-hidden="true" />
              </summary>
              <div className="faq-a">{item.a}</div>
            </details>
          ))}
        </div>
      </div>
    </section>
  )
}

/* ────────────────────────────── 09 — Closing CTA ─────────────────────── */

export function Section09() {
  const ref = useReveal<HTMLDivElement>(0.3)

  return (
    <section id="s09" className="sec sec-close on-light">
      <div className="wrap">
        {/* No nav, no links, no alternatives. One action. */}
        <div className="close-block" data-reveal ref={ref}>
          <p className="eyebrow-sm">Now on TestFlight</p>
          <h2>
            Stop getting graded.
            <br />
            Start getting coached.
          </h2>
          <p className="close-lede">
            The beta is open. Track like you&rsquo;ve got someone in your corner, because
            you will.
          </p>
          <a className="btn btn-lg" href="https://testflight.apple.com/">
            Join the beta on TestFlight →
          </a>
          <p className="close-micro">
            Install{' '}
            <a href="https://apps.apple.com/app/testflight/id899247664">TestFlight</a> first,
            then tap this in Safari on your iPhone.
          </p>
        </div>
      </div>
    </section>
  )
}

/* ──────────────────────────────── Footer ─────────────────────────────── */

export function Footer({ mark }: { mark: React.ReactNode }) {
  return (
    <footer className="on-light">
      <div className="wrap">
        <div className="foot-top">
          <div className="foot-brand">
            {mark}
            <span>Footing</span>
          </div>
          <p className="foot-tag">Coached, not scolded.</p>
        </div>
        <p className="foot-legal">
          Footing is a personal nutrition and wellness tracker, not a medical device. It
          doesn&rsquo;t diagnose, treat, or provide dosing guidance &mdash; always talk to
          your doctor about medication and health decisions.
        </p>
        <p className="foot-links">
          <a href="/terms">Terms</a>
          <a href="/privacy">Privacy</a>
          <a href="mailto:support@tryfooting.app">Contact</a>
        </p>
      </div>
    </footer>
  )
}
