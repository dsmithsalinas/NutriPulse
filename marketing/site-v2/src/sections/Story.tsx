import { useReveal } from '../useReveal'

/**
 * Sections 02–06: the argument.
 *
 * Order is load-bearing and matches marketing/site-v2-blueprint.md §3:
 *   02 Pulse       — show the coach working before explaining it
 *   03 The floor   — the one genuinely new idea, which buys every later claim
 *   04 How         — kill the effort objection
 *   05 The cycle   — GLP-1 fluency, after generic capability so it reads as
 *                    depth rather than as a niche limitation
 *   06 Why Footing — the name, placed where it pays off rather than up front
 *
 * All copy is written to docs/pulse-persona.md — see marketing/site-v2-voice.md
 * for the rules and the banned list.
 */

/* ───────────────────────────── 02 — Meet Pulse ───────────────────────── */

/**
 * Pulse demonstrating itself. This is the most persuasive artifact available
 * pre-launch: the coach's actual voice, answering a real question, with real
 * numbers. Describing a coach is a feature claim; showing one is proof.
 *
 * Two exchanges, not one — the second is deliberately short to demonstrate the
 * persona's "length matches the question" rule. A coach that writes a paragraph
 * about dinner is not the coach we're claiming to have built.
 */
const THREAD = [
  {
    from: 'you' as const,
    text: 'How am I doing today?',
  },
  {
    from: 'pulse' as const,
    text: "Strong, and on the hard version of a good day — 142g of protein with dinner still ahead, two days after your shot when appetite is usually lowest. You're 43g from your floor and dinner alone normally covers that. 530 calories left if you want them.",
  },
  {
    from: 'you' as const,
    text: 'What should I eat?',
  },
  {
    from: 'pulse' as const,
    text: "Keep it dense so you don't have to fight the volume. The chicken and Greek yogurt you had Tuesday puts you over.",
  },
]

export function Section02() {
  const head = useReveal<HTMLDivElement>()
  const chat = useReveal<HTMLDivElement>(0.25)
  const tail = useReveal<HTMLDivElement>(0.3)

  return (
    <section id="s02" className="sec sec-pulse">
      <div className="wrap">
        <div className="sec-head" data-reveal ref={head}>
          <p className="eyebrow-sm">The coach</p>
          <h2>Ask it anything. It already read your day.</h2>
        </div>

        <div className="thread" data-reveal ref={chat}>
          {THREAD.map((m, i) => (
            <div key={i} className={`msg msg-${m.from}`}>
              {m.from === 'pulse' && (
                <span className="msg-who">
                  <span className="pulse-dot" aria-hidden="true" />
                  Pulse
                </span>
              )}
              <p>{m.text}</p>
            </div>
          ))}
        </div>

        <div className="sec-tail" data-reveal ref={tail}>
          <p className="lede">
            Pulse is the coach built into Footing. It sees your food, your weight, your
            training, your sleep, and where you are in the injection cycle&thinsp;&mdash;&thinsp;
            and it connects dots you can&rsquo;t see from inside your own day.
          </p>
          <p className="lede-flip">
            Every other app hands you a dashboard and walks away. Footing hands you
            someone who&rsquo;s <strong>been paying attention</strong>.
          </p>
        </div>
      </div>
    </section>
  )
}

/* ─────────────────────────── 03 — The protein floor ──────────────────── */

export function Section03() {
  const head = useReveal<HTMLDivElement>()
  const viz = useReveal<HTMLDivElement>(0.3)

  return (
    <section id="s03" className="sec sec-floor">
      <div className="wrap">
        <div className="sec-split">
          <div className="sec-head" data-reveal ref={head}>
            <p className="eyebrow-sm">The flip</p>
            <h2>On a GLP-1, the goal flips.</h2>
            <p className="body">
              It was never going to be about eating less&thinsp;&mdash;&thinsp;your appetite
              already handled that. The hard part now is eating <em>enough</em>. Enough
              protein to protect the muscle underneath the weight you&rsquo;re losing.
            </p>
            <p className="body">
              That number is your <strong>protein floor</strong>. Not a target to beat. A
              minimum to clear, every single day. It&rsquo;s the one number Footing puts in
              front of everything else, because it&rsquo;s the one that decides what
              you&rsquo;re left with at the end.
            </p>
          </div>

          <div className="floor-viz" data-reveal ref={viz}>
            <div className="floor-card">
              <div className="floor-card-head">
                <span>Protein</span>
                <span className="floor-card-day">Today</span>
              </div>
              <div className="floor-bar">
                <div className="floor-fill" />
                <div className="floor-mark">
                  <span>floor · 120g</span>
                </div>
              </div>
              <div className="floor-nums">
                <strong>142g</strong>
                <span>floor cleared &mdash; muscle protected</span>
              </div>
            </div>
            <p className="viz-caption">
              Every other app draws a ceiling. This one draws a floor.
            </p>
          </div>
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────────── 04 — How it works ─────────────────────── */

const STEPS = [
  {
    n: '01',
    kicker: 'Effortless in',
    title: 'Logging takes a sentence, not a search.',
    body: 'Tell Pulse what you ate the way you’d tell a friend. It pulls real nutrition data, shows you the breakdown, and logs it in a tap. The tedious part — the part that made you quit last time — is gone.',
    demo: (
      <div className="demo demo-log">
        <p className="demo-said">
          &ldquo;A Chipotle bowl with chicken, rice, pico, and cheese.&rdquo;
        </p>
        <ul>
          <li><span>Chicken, grilled</span><span>180 cal · 32P</span></li>
          <li><span>Cilantro-lime rice</span><span>210 cal · 4P</span></li>
          <li><span>Pico de gallo</span><span>25 cal · 1P</span></li>
          <li><span>Monterey Jack</span><span>110 cal · 7P</span></li>
        </ul>
      </div>
    ),
  },
  {
    n: '02',
    kicker: 'Honest, but useful',
    title: 'It tells you the truth, then what to do about it.',
    body: 'Short on protein? Pulse won’t just flag it. It’ll tell you exactly how to close the gap, with food you actually eat. Honest when you need it — never just to make you feel small.',
    demo: (
      <div className="demo demo-coach">
        <p className="demo-q">Why isn&rsquo;t my weight moving?</p>
        <p className="demo-a">
          You&rsquo;ve been under 1,200 calories four days running. At that level your
          body starts protecting fat instead of burning it. Eat closer to 1,700
          tomorrow and give it a week.
        </p>
      </div>
    ),
  },
  {
    n: '03',
    kicker: 'Earned celebration',
    title: 'It notices when you win.',
    body: 'Three days of hitting your floor. Every goal met before dinner. Pulse says so — because the moment you feel good about showing up is the moment you come back tomorrow. That’s the part every other app forgot.',
    demo: (
      <div className="demo demo-win">
        <div className="win-row">
          <span>Protein</span>
          <strong>185g</strong>
          <span className="win-ok">goal hit</span>
        </div>
        <p className="demo-a">Three days running now. That&rsquo;s a first. 🔥</p>
      </div>
    ),
  },
]

export function Section04() {
  const head = useReveal<HTMLDivElement>()

  return (
    <section id="s04" className="sec sec-how">
      <div className="wrap">
        <div className="sec-head" data-reveal ref={head}>
          <p className="eyebrow-sm">How it works</p>
          <h2>Three things, done properly.</h2>
        </div>

        <div className="steps">
          {STEPS.map((s) => (
            <Step key={s.n} {...s} />
          ))}
        </div>
      </div>
    </section>
  )
}

function Step({
  n,
  kicker,
  title,
  body,
  demo,
}: {
  n: string
  kicker: string
  title: string
  body: string
  demo: React.ReactNode
}) {
  const ref = useReveal<HTMLDivElement>(0.25)

  return (
    <div className="step" data-reveal ref={ref}>
      <div className="step-copy">
        <p className="step-n">
          {n} &mdash; {kicker}
        </p>
        <h3>{title}</h3>
        <p className="body">{body}</p>
      </div>
      <div className="step-demo">{demo}</div>
    </div>
  )
}

/* ────────────────────────── 05 — Built for the cycle ─────────────────── */

export function Section05() {
  const head = useReveal<HTMLDivElement>()
  const card = useReveal<HTMLDivElement>(0.3)

  return (
    <section id="s05" className="sec sec-cycle">
      <div className="wrap">
        <div className="sec-split">
          <div className="sec-head" data-reveal ref={head}>
            <p className="eyebrow-sm">For GLP-1</p>
            <h2>Built for how the shot actually works.</h2>
            <p className="body">
              Appetite isn&rsquo;t flat across the week and neither is what you need. Pulse
              knows where you are in the cycle&thinsp;&mdash;&thinsp;which days are hard,
              which days you can bank protein, when hydration slips without you noticing.
            </p>
            <ul className="ticks">
              <li>Protein floors, not calorie ceilings</li>
              <li>Hydration that keeps pace with the dose</li>
              <li>Injection reminders on the schedule you set</li>
            </ul>
            <p className="fineprint">
              Pulse never advises a dose or a schedule change. It reminds you of yours.
            </p>
          </div>

          <div className="cycle-card" data-reveal ref={card}>
            <div className="cycle-head">
              <span>GLP-1 · Today</span>
              <span className="cycle-dose">0.5 mg</span>
            </div>
            <p className="cycle-next">Next dose Saturday · in 2 days</p>
            <div className="cycle-rows">
              <div>
                <span>Protein floor</span>
                <strong className="ok">142 / 120g</strong>
              </div>
              <div>
                <span>Water</span>
                <strong>2.1 / 2.5 L</strong>
              </div>
            </div>
            <p className="cycle-note">
              <span className="pulse-dot" aria-hidden="true" />
              Day 2 after your shot &mdash; appetite&rsquo;s usually lowest now. Keep protein
              dense so you don&rsquo;t have to fight the volume.
            </p>
          </div>
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────────── 06 — Why Footing ──────────────────────── */

export function Section06() {
  const ref = useReveal<HTMLDivElement>(0.3)

  return (
    <section id="s06" className="sec sec-name">
      <div className="wrap">
        <div className="name-block" data-reveal ref={ref}>
          <p className="eyebrow-sm">The name</p>
          <h2>Why Footing?</h2>
          <p className="name-lede">
            A footing is the base poured beneath a floor so nothing above it sinks.
          </p>
          <p className="body">
            On a GLP-1, protein is that base. The shot does its part&thinsp;&mdash;&thinsp;
            and your protein floor is what keeps the result standing once it has.
          </p>
          <p className="name-flip">
            Most apps in this category are named after the medication. This one is named
            after <strong>the work</strong>.
          </p>
        </div>
      </div>
    </section>
  )
}
