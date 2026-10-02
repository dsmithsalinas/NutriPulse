import { Nav, Hero, Problem, Flip, PulseSection, HowItWorks, Glp1, Control, Name, Beta, Faq, Footer } from './sections/Home'
import { DayWithPulse } from './sections/DayWithPulse'

export default function App() {
  return (
    <>
      <a className="skip" href="#main">Skip to content</a>
      <Nav />
      <main id="main">
        <Hero />
        <Problem />
        <Flip />
        <PulseSection />
        <DayWithPulse />
        <HowItWorks />
        <Glp1 />
        <Control />
        <Name />
        <Beta />
        <Faq />
      </main>
      <Footer />
    </>
  )
}
