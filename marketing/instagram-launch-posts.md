# Instagram launch set — @tryfooting

Five posts announcing the NutriPulse → Footing rename and opening the beta.
Voice per `site-v2-voice.md`: sentence case, no exclamation marks, no banned words,
non-shaming law outranks conversion instinct. Zero emoji across the set — the one
allowed emoji is spent on the streak card in the product.

Link in bio: **tryfooting.app** (the beta CTA on the site is the one-tap TestFlight hand-off).

**Images:** `marketing/social/out/*.png`, 1080×1350. Rendered by `marketing/social/build.py`
off the same tokens and fonts as `marketing/site-v2` — see `marketing/social/README.md`.

**Suggested posting order:** 1 → 2 → 4 → 3 → 5, one every 2–3 days. Post 1 and 2 back-to-back
in the same week so the name lands with its reason attached.

---

## Post 1 — The name change

**Format:** carousel, 3 slides
1. `p1-s1-name.png` — NutriPulse struck through, Footing beneath it
2. `p1-s2-nothing-breaks.png` — "Nothing breaks."
3. `p1-s3-named-after-work.png` — the positioning line, gradient on "the work"

**Caption:**

> NutriPulse is now Footing.
>
> Same app, same account, same coach. If you already have it on your phone, nothing breaks — the icon just says something different.
>
> The old name described a category. This one describes the job. On a GLP-1 the goal flips: it's not about eating less, it's about eating enough, and holding that up day after day is the actual work. We wanted a name that pointed at the work instead of at the medication.
>
> More on where "Footing" comes from tomorrow.
>
> Link in bio.

**Alt text:** Text on a dark background reading "NutriPulse is now Footing."

**Hashtags:** #glp1 #glp1community #glp1support #proteinfirst #nutritiontracking #weightlossapp #buildinpublic #indieapp

---

## Post 2 — Why "Footing"

**Format:** single image — `p2-s1-quote.png`. Serif italic quote card, dark ground, amber
rule. Same Instrument Serif treatment as §06 on the site, so the post and the landing page
read as one thing.

**On-image text:**

> A footing is the base poured beneath a floor so nothing above it sinks.

**Caption:**

> A footing is the base poured beneath a floor so nothing above it sinks.
>
> On a GLP-1, protein is that base. The shot does its part — and your protein floor is what keeps the result standing once it has.
>
> That's the whole reason for the name. Appetite drops, eating gets hard, and the thing quietly at risk is the muscle you'd rather keep. A floor is a minimum you clear, not a target you beat.
>
> Most apps in this category are named after the medication. This one is named after the work.

**Alt text:** A dark card with serif italic text: "A footing is the base poured beneath a floor so nothing above it sinks."

**Hashtags:** #glp1 #glp1nutrition #proteinfloor #musclepreservation #glp1community #semaglutidesupport #tirzepatidesupport

---

## Post 3 — The beta is open

**Format:** carousel, 2 slides
1. `p3-s1-beta-open.png` — headline plus the live TestFlight QR (decoded and verified against
   `site-v2/src/links.ts`; it resolves to `testflight.apple.com/join/tGubSF3Z`)
2. `p3-s2-free.png` — the daylight slide, far end of the site's dark→ground arc

**Caption:**

> Footing is in TestFlight, and there's room for more people.
>
> What you get: logging that takes a sentence instead of a search, a protein floor built around your dose schedule, and a coach that has already read your day before you ask it anything.
>
> What we want back: tell us where it annoyed you. Beta is the one window where a single message actually changes the app, and yours would.
>
> Free while we're building it. Link in bio — it hands off to TestFlight in a tap.

**Alt text:** Two cards reading "The beta is open" and "Free while we're building it."

**Hashtags:** #testflight #betatesting #glp1 #glp1community #glp1journeysupport #nutritionapp #buildinpublic #indieapp #iosapp

---

## Post 4 — Coached, not scolded

**Format:** carousel, 3 slides
1. `p4-s1-scorecard.png` — the conventional-tracker summary from §01 of the site, same rows
   and the same single use of red in the whole system
2. `p4-s2-pulse.png` — a Pulse exchange
3. `p4-s3-coached.png` — "Coached, not scolded."

**On slide 2:** the exchange is written, not screenshotted — same as the one already live in
`Story.tsx`. It stays inside what Pulse can actually see: it reads this person's log and makes
no general claim about how weight behaves. Swap in a real screenshot once you have one worth
showing; a genuine exchange always beats a composed one.

**Caption:**

> Tracking shouldn't feel like getting graded.
>
> You know the screen. Red numbers, a bar you went over, a verdict at the end of a day you were genuinely trying. And you quit — not because you lack discipline, but because nothing about that day was worth coming back to.
>
> Footing is built the other way around. Short on protein? Pulse won't only flag it. It'll tell you how to close the gap with food you actually eat. And when you clear your floor three days running, it says so — because the moment you feel good about showing up is the moment you come back tomorrow.
>
> Coached, not scolded. That's the whole idea.

**Alt text:** Three app screens: a conventional tracker's red daily summary, a coaching reply from Pulse, and a card reading "Coached, not scolded."

**Hashtags:** #glp1 #glp1community #proteinfirst #nutritiontracking #nonshaming #weightlosssupport #glp1nutrition

---

## Post 5 — Founder note (optional, and the honest one)

**Format:** single image — `p5-s1-founder.png`, the second daylight slide. Or a face-to-camera
reel if you'd rather; the caption works read aloud.

**Caption:**

> The unglamorous half of the name story: the App Store already had a NutriPulse. Found that out later than I'd like to admit.
>
> So I had to pick again, and picking again turned out to be the good part. NutriPulse was a name I chose before I understood what I was building. Footing is one I chose after.
>
> A year of watching how people actually use a shot taught me the thing nobody says up front — the medication handles appetite, and everything that keeps the result standing afterward is still yours to do. Protein, movement, sleep, showing up. That's the footing. The app's only job is to make that part light enough that you keep doing it.
>
> Beta's open. Link in bio.

**Alt text:** A plain text card reading "The unglamorous half of the story."

**Hashtags:** #buildinpublic #indiehacker #founderstory #glp1 #glp1community #iosdev

---

## Notes

**Prescription-drug language.** Nothing in this set names a brand-name medication, and it
should stay that way. Meta restricts prescription-drug promotion, and brand names bring
trademark exposure for no gain — "GLP-1," "the shot," and "your dose" carry the meaning and
are how people search anyway. Same reason `semaglutidesupport` / `tirzepatidesupport` are the
only generic-name tags here and sit in a single post; drop them if reach doesn't justify it.

**No testimonials.** The site rule holds on social: no quote goes out until a real beta user
says it. Nothing in this set is attributed to anyone but you.

**Health claims.** None of these promise an outcome — they describe what the app does. Keep it
that way; the moment a caption says "lose more fat" or "keep more muscle" as a result, it's a
health claim you'd have to stand behind.

**First 125 characters.** That's all Instagram shows before "more." Every caption above front-
loads its point into the first line, so the fold does no damage.
