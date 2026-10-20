# Pulse ring integration

The app bundles byte-for-byte copies of the canonical ready, listening, thinking,
coaching and check-in SVGs, with both surface variants. `PulseRing` renders original
vector colors at a minimum 32 pt and hides the decorative image from VoiceOver;
adjacent Pulse/state labels carry the meaning. Surface selection is explicit because
Daylight cards remain light regardless of the system appearance.

- Pulse header: Ready; Listening only while dictation captures; Thinking during a request.
- Reply attribution: static Coaching ring.
- Request waiting row: static Thinking ring and “Pulse · Thinking”, replacing bouncing dots.
- Talk to Log: Listening while capture is active; Thinking while parsing. Both use the
  approved dark-surface artwork on the existing navy tile. The decorative waveform is removed.
- Home's optional Pulse nudge: neutral Check-in ring and “Pulse · Check-in”.

The shared small Footing identity used by navigation/widgets is unchanged. Sample
progress and completion assets are not used as user data. All integrated states are
static, so Reduce Motion gets the same artwork without recurring animation. There
are no new microphone, notification, coaching or data behavior changes.

Initially prepared and reviewed locally; subsequently authorized for TestFlight 1.3.3.

Validation: simulator build and both Profile rendering regression checks passed;
all ten bundled SVGs match the canonical source bytes; the Pulse start screen was
captured and visually inspected. Live recording/network flows were not exercised.

Screenshot fixtures (Debug only): `--pulse-preview --ring-chat-preview` shows the
sample conversation; add `--ring-thinking-preview` for the waiting row.
`--log-preview --ring-listening-preview` simulates capture, while
`--log-preview --ring-parsing-preview` holds parsing. These use the production views
and sample content, without starting recording or sending requests. All four states
were captured and visually inspected after a successful local simulator build.
