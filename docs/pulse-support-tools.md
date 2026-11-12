# Practical support lives in Pulse — November 12, 2026

The permanent three-action support card has moved off Today. Pulse's start screen now has a compact, initially collapsed “Make today easier” section beneath its suggestions. Expanding it reveals Today went sideways, Everyday tools, and Take it easier (or Manage lighter tracking while active). The same scrolling pane supports portrait and expanded layouts.

Today retains its active lighter-tracking status, Manage action, and resume-choice state. Profile's Tracking section retains Take it easier. When Pulse is off and its tab is hidden, Profile also offers the non-AI support tools, so opting out does not hide practical features.

Opening the Pulse tab no longer requests AI consent. Tool browsing, opening the note flow, and opening reminder settings do not start a chat. Explicit AI actions still use `pulseMaySend` and AppState's consent-gated handoff; no backend consent enforcement changed. Requests from a tool are held until its sheet dismisses, checked against the originating account, and dropped on account change. Saving notes still triggers Today's existing meal-note refresh notification. Siri/quick-action entry points remain available without restoring the permanent Today card.

The new UI checks use isolated preview fixtures without granting consent, sending AI requests, saving notes or changing reminders. They cover the three Pulse destinations, a still-required consent sheet on explicit AI use, Pulse-off fallback in Profile, and active lighter-tracking status on Today. No release build, push, or deployment is part of this UI change.

Verification: 19 distinct checks passed (9 Profile rendering, 6 Pulse gates, 2 expanded-layout UI, and 2 support-tool UI tests). The final screenshot run also passed. `git diff --check` is clean.

[Portrait and expanded screenshot gallery](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/pulse-support-2026-11-12/index.html). Captures use sample fixtures. Approved for commit, push, and a new TestFlight build on November 12, 2026.
