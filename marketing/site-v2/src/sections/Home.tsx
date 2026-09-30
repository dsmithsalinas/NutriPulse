import type { ReactNode } from 'react'
import { useReveal } from '../useReveal'
import { ProteinTile } from '../ProteinTile'
import { TESTFLIGHT_URL, TESTFLIGHT_APP_URL, TESTFLIGHT_QR } from '../links'

/*
 * The home page in Daylight. Every product picture is built from the app's own tiles, and every
 * claim is one the app actually makes (docs/daylight-redesign.md, honesty rule). The FAQ's
 * privacy answer must agree with public/privacy.html — change both in the same commit.
 */

export function Mark({ size = 24, small = false }: { size?: number; small?: boolean }) {
  return (
    <span className={small ? 'mark small' : 'mark'}>
      <svg width={size} height={size} viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <circle cx="12" cy="12" r="8.3" stroke="#fff" strokeOpacity="0.28" strokeWidth="3.2" />
        <path d="M12 3.7 A8.3 8.3 0 1 1 4.2 14.84" stroke="#fff" strokeWidth="3.2" strokeLinecap="round" />
        <circle cx="4.2" cy="14.84" r="2.7" fill="#fff" />
      </svg>
    </span>
  )
}

function Check() {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#4F46E5" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M20 6 9 17l-5-5" />
    </svg>
  )
}

export function Nav() {
  return (
    <header className="nav">
      <div className="wrap">
        <a className="brand" href="#top" aria-label="Footing, back to top">
          <Mark /><span className="brand-word d">Footing</span>
        </a>
        <nav className="nav-links" aria-label="Main">
          <a href="#pulse">Pulse</a>
          <a href="#glp1">For GLP-1</a>
          <a href="#control">Privacy</a>
          <a href="#faq">FAQ</a>
          <a className="btn btn-lime" href={TESTFLIGHT_URL}>Join the beta</a>
        </nav>
      </div>
    </header>
  )
}

export function Hero() {
  const copy = useReveal<HTMLDivElement>(0)
  const tiles = useReveal<HTMLDivElement>(0)
  return (
    <section className="hero" id="top">
      <div className="wrap">
        <div className="stack" data-reveal ref={copy}>
          <h1 className="d">Coached,<br />not scolded.</h1>
          <p className="lede">
            On a GLP-1 the goal flips: it’s not about eating less, it’s about eating <strong>enough</strong>.
            Footing tracks the protein floor that protects your results, and puts a coach in your corner who’s
            actually read your day.
          </p>
          <div className="cta-row">
            <a className="btn btn-primary" href={TESTFLIGHT_URL}>Join the beta</a>
            <a className="btn btn-white" href="#pulse">See how it works</a>
          </div>
          <p className="fine">Free during the beta · No card · iPhone</p>
        </div>

        <div className="today" data-reveal ref={tiles}>
          <ProteinTile />
          <div className="today-col">
            <div className="tile cal" aria-label="Calories: 710 left">
              <div className="cal-head"><p className="eb" style={{ color: 'var(--muted)' }}>Calories</p><span className="cal-num d">710 <small>left</small></span></div>
              <div className="meter"><span style={{ width: '62%', background: 'var(--calories)' }} /></div>
              <div className="macro"><span>Carbs</span><span><strong>96</strong> / 180g</span></div>
              <div className="meter thin"><span style={{ width: '53%', background: 'var(--carbs)' }} /></div>
              <div className="macro"><span>Fiber</span><span><strong>17</strong> / 28g</span></div>
              <div className="meter thin"><span style={{ width: '61%', background: 'var(--fiber)' }} /></div>
            </div>
            <div className="tile tile-lime shot" aria-label="Shot cycle: day 3 of 7">
              <p className="eb" style={{ color: 'var(--lime-label)' }}>Shot cycle</p>
              <span className="shot-title d">Day 3 of 7</span>
              <div className="dots" aria-hidden="true">
                {[0, 1, 2, 3, 4, 5, 6].map((i) => <span key={i} className={i < 3 ? 'on' : ''} />)}
              </div>
            </div>
          </div>
          <div className="tile pulse-note">
            <Mark size={20} small />
            <div>
              <p className="eb" style={{ color: 'var(--primary-text)' }}>Pulse</p>
              <p>Day 3 after your shot, when appetite is often lowest. Dinner usually covers your last 28g. The turkey chili you’ve had four times this week would do it.</p>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

export function Problem() {
  const a = useReveal<HTMLDivElement>()
  const b = useReveal<HTMLDivElement>()
  return (
    <section className="sec">
      <div className="wrap split">
        <div className="stack" data-reveal ref={a}>
          <p className="eb" style={{ color: 'var(--danger)' }}>The problem</p>
          <h2 className="h2 d">Tracking shouldn’t feel like getting graded.</h2>
          <p className="lede">Every app on your phone tells you when you went over. When you fell short. When you were off-plan. Four numbers, all of them red, every night.</p>
          <p className="lede">So one day you look at the red numbers and quit. Not because you lack discipline, but because nothing about that day was worth coming back to.</p>
          <p className="lede" style={{ color: 'var(--ink)', fontWeight: 600 }}>Footing starts from the opposite premise.</p>
        </div>
        <div className="compare" data-reveal ref={b}>
          <div className="tile score">
            <p className="eb" style={{ color: 'var(--faint)' }}>Every other app</p>
            <div className="score-row"><span>Calories</span><b>+320 over</b></div>
            <div className="score-row"><span>Protein</span><b>−38 under</b></div>
            <div className="score-row"><span>Fiber</span><b>−12 under</b></div>
            <div className="score-row"><span>Streak</span><b>Broken</b></div>
            <div className="score-foot">0 of 4 goals met</div>
          </div>
          <div className="tile tile-lime cleared">
            <p className="eb" style={{ color: 'var(--lime-label)' }}>Footing</p>
            <span className="n d">146<small>g</small></span>
            <b>Floor cleared</b>
            <span style={{ marginTop: 'auto', fontSize: 15, lineHeight: 1.5, color: 'var(--lime-label)' }}>Cleared before dinner, three days running. That’s a first.</span>
          </div>
        </div>
      </div>
    </section>
  )
}

function Stage({ grams, level, label }: { grams: number; level: number; label: string }) {
  return (
    <div className="stage">
      <div className="stage-box">
        <div className="stage-fill" style={{ height: `${level}%` }} />
        <span className="n d">{grams}<small>g</small></span>
      </div>
      {label}
    </div>
  )
}

export function Flip() {
  const ref = useReveal<HTMLDivElement>()
  return (
    <section className="sec-tight">
      <div className="wrap">
        <div className="flip">
          <div className="stack">
            <p className="eb" style={{ color: 'var(--hero-label)' }}>The flip</p>
            <h2 className="h2 d">Every other app draws a ceiling. This one draws a floor.</h2>
            <p className="lede">Your appetite already handles eating less. The hard part now is eating enough: enough protein to hold on to muscle while the weight comes off. That number is your protein floor, a minimum to clear, not a target to beat.</p>
          </div>
          <div className="stages" data-reveal ref={ref} aria-label="A protein floor filling through the day: 42 grams at breakfast, 112 after lunch, 146 and cleared at dinner.">
            <Stage grams={42} level={30} label="Breakfast" />
            <Stage grams={112} level={76} label="After lunch" />
            <div className="stage">
              <div className="stage-box done">
                <span className="bubble" style={{ left: '22%', top: -34, width: 14, height: 14 }} aria-hidden="true" />
                <span className="bubble" style={{ left: '48%', top: -58, width: 18, height: 18 }} aria-hidden="true" />
                <span className="bubble" style={{ left: '70%', top: -26, width: 10, height: 10 }} aria-hidden="true" />
                <span className="n d">146<small>g</small></span>
                <em>Floor cleared</em>
              </div>
              Dinner
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

export function PulseSection() {
  const head = useReveal<HTMLDivElement>()
  const grid = useReveal<HTMLDivElement>()
  return (
    <section className="sec" id="pulse">
      <div className="wrap">
        <div className="split split-end" data-reveal ref={head}>
          <div className="stack">
            <p className="eb" style={{ color: 'var(--primary-text)' }}>Pulse, your coach</p>
            <h2 className="h2 d">Ask it anything. It already read your day.</h2>
          </div>
          <p className="lede">Pulse sees what you’ve logged, where you are in your shot week, your goals, and Apple Health if you connect it. It answers with your numbers and your foods, not generic advice, and never suggests what you’ve told it you avoid.</p>
        </div>
        <div className="pulse-grid" data-reveal ref={grid}>
          <div className="tile pulse-start">
            <span className="greet d">What’s on your mind, Sam?</span>
            <span style={{ fontSize: 15, color: 'var(--muted)' }}>I’ve got today’s log, your shot week and your goals.</span>
            <p className="eb" style={{ color: 'var(--muted)', fontSize: 12 }}>Suggested for right now</p>
            <div className="sugg">
              <div style={{ background: 'var(--hero-deep)', color: '#fff' }}><span className="gap">28g to go</span>Give me an easy dinner to close my protein</div>
              <div style={{ background: 'var(--lime)', color: 'var(--lime-ink)' }}><span style={{ fontSize: 13, color: 'var(--lime-label)' }}>Shot day 3</span>Help me get protein in when I’m not hungry</div>
            </div>
            <div className="chips"><span className="chip">Meal ideas</span><span className="chip">How I’m trending</span><span className="chip">Eating out</span></div>
          </div>
          <div className="tile convo">
            <span className="me">What’s an easy dinner to close my protein?</span>
            <div className="them">
              <Mark size={18} small />
              <p>You’re 28g from your floor, and appetite is often low on day 3. Keep it dense so you don’t have to fight the volume. Either of these covers it:</p>
            </div>
            <div className="foods">
              <div className="food"><b>Turkey chili</b><span>You’ve had it 4× this week</span><span className="log">Log it</span></div>
              <div className="food"><b>Greek yogurt bowl</b><span>Easy when you’re not hungry</span><span className="log">Log it</span></div>
            </div>
            <div className="chips follow"><span className="chip">Make it vegetarian</span><span className="chip">Plan tomorrow</span></div>
          </div>
        </div>
      </div>
    </section>
  )
}

export function HowItWorks() {
  const ref = useReveal<HTMLDivElement>()
  return (
    <section className="sec">
      <div className="wrap">
        <div className="stack" style={{ maxWidth: 760 }}>
          <p className="eb" style={{ color: 'var(--primary-text)' }}>How it works</p>
          <h2 className="h2 d">Three things, done properly.</h2>
        </div>
        <div className="three" data-reveal ref={ref}>
          <div className="tile step">
            <p className="eb" style={{ color: 'var(--faint)' }}>01 · Talk it, log it</p>
            <h3 className="d">Logging takes a sentence, not a search.</h3>
            <p style={{ color: 'var(--muted)' }}>Say what you ate the way you’d tell a friend. Footing finds real nutrition data and logs it in a tap.</p>
            <div className="step-demo" style={{ background: 'var(--inset)' }}>
              <i style={{ fontSize: 15 }}>“Chipotle bowl, chicken, rice, pico and cheese”</i>
              <div className="row"><span>Chicken, grilled</span><b>32g</b></div>
              <div className="row"><span>Cilantro-lime rice</span><b>4g</b></div>
              <div className="row"><span>Monterey Jack</span><b>7g</b></div>
            </div>
          </div>
          <div className="tile tile-violet step">
            <p className="eb" style={{ color: 'var(--violet-label)' }}>02 · Monday Recap</p>
            <h3 className="d">Your week, read back to you.</h3>
            <p style={{ color: 'var(--violet-label)' }}>One card on Monday: what happened, what went well, the pattern, and one thing to focus on. No scorecard.</p>
            <div className="step-demo">
              <b style={{ fontSize: 15, lineHeight: 1.4 }}>Five floor days out of six logged, up from two.</b>
              <div className="week" aria-hidden="true"><span /><span /><span className="low" /><span /><span /><span className="none" /><span /></div>
              <span className="focus"><b>Focus:</b> a protein snack on shot day, when dinner is hardest.</span>
            </div>
          </div>
          <div className="tile tile-lime step">
            <p className="eb" style={{ color: 'var(--lime-label)' }}>03 · Earned wins</p>
            <h3 className="d">It notices when you show up.</h3>
            <p style={{ color: 'var(--lime-label)' }}>Clear your floor and the protein tile fills with lime. Streaks get a quiet nod, not fireworks, and a missed day is never called a failure.</p>
            <div className="streak"><span className="n d">7 days</span><p>at your floor. Nice work.</p></div>
          </div>
        </div>
      </div>
    </section>
  )
}

export function Glp1() {
  const a = useReveal<HTMLDivElement>()
  const b = useReveal<HTMLDivElement>()
  return (
    <section className="sec" id="glp1">
      <div className="wrap split">
        <div className="stack" data-reveal ref={a}>
          <p className="eb" style={{ color: 'var(--primary-text)' }}>For GLP-1</p>
          <h2 className="h2 d">Built for how the shot actually works.</h2>
          <p className="lede">Appetite isn’t flat across the week, and neither is what you need. Footing follows your shot cycle, and Pulse plans around it.</p>
          <ul className="checks">
            <li><Check />Protein floors, not calorie ceilings</li>
            <li><Check />A Strong Week plan every Monday</li>
            <li><Check />Shot reminders on the schedule you set</li>
            <li><Check />Pause or stop tracking any time; the rest keeps working</li>
          </ul>
          <p className="fine" style={{ fontSize: 15 }}>Pulse never advises a dose or a schedule change. It reminds you of yours.</p>
        </div>
        <div className="glp-grid" data-reveal ref={b}>
          <div className="tile tile-lime dose">
            <p className="eb" style={{ color: 'var(--lime-label)' }}>It’s dose day</p>
            <h3 className="d">Time for your shot</h3>
            <span style={{ fontSize: 15, fontWeight: 600, color: 'var(--lime-label)' }}>Zepbound · 5 mg</span>
            <span className="btn btn-ink" style={{ alignSelf: 'flex-start', minHeight: 44, fontSize: 15 }}>Log your shot</span>
          </div>
          <div className="tile" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <p className="eb" style={{ color: 'var(--muted)' }}>Appetite this cycle</p>
            <div className="bars" aria-hidden="true">
              {[92, 38, 30, 44, 62, 78, 86].map((h, i) => <span key={i} className={i >= 1 && i <= 3 ? 'low' : ''} style={{ height: `${h}%` }} />)}
            </div>
            <span style={{ fontSize: 14, lineHeight: 1.5, color: 'var(--muted)' }}>From your own check-ins. Days 1–3 are your hardest, so that’s where Pulse plans dense protein.</span>
          </div>
          <div className="tile tile-violet strong">
            <div className="strong-head"><p className="eb">Your Strong Week</p><span>Week of Sep 28</span></div>
            <div><b>This week</b><p>Traveling Tue–Thu, with your shot on Saturday.</p></div>
            <div><b>Food focus</b><p>Pack two protein snacks for the flights.</p></div>
            <div><b>Movement</b><p>Hotel walks count. Keep one strength day.</p></div>
          </div>
        </div>
      </div>
    </section>
  )
}

export function Control() {
  const head = useReveal<HTMLDivElement>()
  const grid = useReveal<HTMLDivElement>()
  return (
    <section className="sec" id="control">
      <div className="wrap">
        <div className="split split-end" data-reveal ref={head}>
          <div className="stack">
            <p className="eb" style={{ color: 'var(--primary-text)' }}>Privacy and control</p>
            <h2 className="h2 d">You decide what Pulse knows.</h2>
          </div>
          <p className="lede">We don’t sell your data. When you message Pulse, your message and the parts of your day it needs go to our AI provider so it can answer about you. Footing asks before that ever happens, and you can turn it off.</p>
        </div>
        <div className="four" data-reveal ref={grid}>
          <div className="tile ctl">
            <h3 className="d">What Pulse knows</h3>
            <p>Allergies, how you eat, foods you love and ones you skip. You add them; Pulse never guesses an allergy.</p>
            <div className="chips demo"><span className="chip allergy">Peanuts</span><span className="chip">Pescatarian</span><span className="chip" style={{ background: 'var(--lime)', color: 'var(--lime-ink)' }}>Greek yogurt</span><span className="chip">No cilantro</span></div>
          </div>
          <div className="tile ctl">
            <h3 className="d">It asks first</h3>
            <p>Nothing goes to the AI until you say yes, and the screen spells out exactly what’s sent.</p>
            <span className="consent-btn demo">Turn on Pulse</span>
          </div>
          <div className="tile ctl">
            <h3 className="d">Turn Pulse off</h3>
            <p>One switch in Profile. Logging, your floor and your history all keep working without it.</p>
            <div className="toggle demo"><span>Pulse</span><span className="switch" aria-hidden="true" /></div>
          </div>
          <div className="tile ctl">
            <h3 className="d">Pause the shot</h3>
            <p>Stopped or taking a break? Footing hides every shot prompt and reminder until you’re back. Your history stays.</p>
            <div className="paused demo">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#475569" strokeWidth="2.2" strokeLinecap="round" aria-hidden="true"><circle cx="12" cy="12" r="9" /><path d="M10 9v6M14 9v6" /></svg>
              Tracking paused
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

export function Name() {
  return (
    <section className="sec-tight">
      <div className="wrap">
        <div className="name">
          <div className="stack" style={{ gap: 18 }}>
            <p className="eb" style={{ color: 'var(--faint)' }}>The name</p>
            <h2 className="h2 d">Why Footing?</h2>
          </div>
          <div className="stack" style={{ gap: 16 }}>
            <p className="pull">A footing is the base poured beneath a floor so nothing above it sinks.</p>
            <p className="lede" style={{ fontSize: 18 }}>On a GLP-1, protein is that base. The shot does its part. Your protein floor is what keeps the result standing. Most apps in this category are named after the medication. This one is named after the work.</p>
          </div>
        </div>
      </div>
    </section>
  )
}

export function Beta() {
  return (
    <section className="sec-tight" id="beta">
      <div className="wrap">
        <div className="beta">
          <div className="stack">
            <p className="eb" style={{ color: 'var(--lime-label)' }}>The beta</p>
            <h2 className="h2 d">Stop getting graded. Start getting coached.</h2>
            <p className="lede">Free for the whole beta. Everything unlocked, no card, no trial clock. If Footing costs something later, you’ll hear it from us before you hear it from a paywall.</p>
            <a className="btn btn-ink" href={TESTFLIGHT_URL}>Join the beta on TestFlight</a>
            <p className="fine" style={{ color: 'var(--lime-label)', fontWeight: 600, fontSize: 15 }}>iPhone for now. Android is in development.</p>
          </div>
          <div className="beta-steps">
            <p className="eb" style={{ color: 'var(--muted)' }}>Two steps, in this order</p>
            <div className="row"><span className="num d">1</span><span>Install Apple’s free <a href={TESTFLIGHT_APP_URL}><b>TestFlight</b></a> app from the App Store.</span></div>
            <div className="row"><span className="num d">2</span><span>Tap <b>Join the beta</b> in Safari on your iPhone. Opening it inside another app’s browser asks for a code you don’t need.</span></div>
            {/* Desktop only: TestFlight installs on a phone, so a laptop visitor needs a way across. */}
            <div className="qr">
              <img src={TESTFLIGHT_QR} alt="QR code that opens the Footing beta on your phone" width="104" height="104" />
              <span>On a laptop? Scan this with your iPhone’s camera to open the beta there.</span>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

const QA: { q: string; a: ReactNode }[] = [
  {
    q: 'I’ve quit every tracking app I’ve tried. Why is this different?',
    a: 'What made you quit wasn’t the tracking. It was the verdict at the end of it. Footing doesn’t grade your day. It tells you what’s left, how to get there, and says something when you show up.',
  },
  {
    q: 'Is this just a tracker with a chatbot bolted on?',
    a: 'The coach isn’t sitting next to your log; it reads it. Pulse sees your food, weight, workouts, goals and shot schedule together, and answers with your numbers and your own foods rather than general advice.',
  },
  {
    q: 'Do I have to log everything?',
    a: 'No. Protein is the number that matters most on a GLP-1, and Footing is built so that one is easy to hit. Log what you can. Pulse works with what it has and won’t nag you for the rest.',
  },
  {
    q: 'What if I stop or pause the medication?',
    a: 'Tell Footing in Profile and it hides every shot prompt, reminder and cycle insight until you’re back, while your history and everything else keep working. The muscle you protected on the way down is what holds the result afterwards, which is why Footing centres on protein.',
  },
  {
    q: 'Is my health data private?',
    // Must agree with public/privacy.html. Change both in the same commit.
    a: (
      <>
        We don’t sell it, and access is scoped to your account so no other user can reach it. Pulse only runs after
        you agree: your message and the parts of your data it needs go to our AI provider so it can answer about you,
        and you can turn Pulse off in Profile at any time. Apple Health data is only used to show you and to give
        Pulse context, never for advertising. You can delete everything from inside the app. The{' '}
        <a href="/privacy">Privacy Policy</a> names every provider and exactly what each one receives.
      </>
    ),
  },
  {
    q: 'Is any of this medical advice?',
    a: 'No. Footing is a nutrition and wellness tracker, not a medical device. Pulse won’t diagnose anything and won’t tell you to change a dose. It can remind you of the schedule you set. That’s the line, and it doesn’t move.',
  },
  {
    q: 'Android?',
    a: 'It’s in development. For now Footing is iPhone-only, so it can be built properly on one platform first.',
  },
]

export function Faq() {
  const ref = useReveal<HTMLDivElement>(0.1)
  return (
    <section className="sec" id="faq">
      <div className="wrap faq-grid">
        <div className="stack">
          <p className="eb" style={{ color: 'var(--primary-text)' }}>Straight answers</p>
          <h2 className="h2 d">The things you’re actually wondering.</h2>
        </div>
        <div data-reveal ref={ref}>
          <div className="faq">
            {QA.map((item) => (
              <details key={item.q}>
                <summary>{item.q}</summary>
                <div className="a">{item.a}</div>
              </details>
            ))}
          </div>
        </div>
      </div>
    </section>
  )
}

export function Footer() {
  return (
    <footer className="foot">
      <div className="wrap">
        <div className="foot-brand">
          <span className="word d">Footing</span>
          <span className="tag">Coached, not scolded.</span>
          <p>Footing is a personal nutrition and wellness tracker, not a medical device. It doesn’t diagnose, treat, or give dosing guidance. Always talk to your doctor about medication and health decisions.</p>
        </div>
        <nav className="foot-links" aria-label="Legal">
          <a href="/terms">Terms</a>
          <a href="/privacy">Privacy</a>
          <a href="/contact">Contact</a>
        </nav>
      </div>
    </footer>
  )
}
