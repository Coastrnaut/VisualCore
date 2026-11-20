# Research: R02-G01-06

- **R1 Plans as pure functions.** Decision: `AuroraLoomFeedbackPlan.after(old:new:)` and `.refused(reason:)` return the
  announcement and haptic for a change, from the two cores alone. Rationale: exact host tests of texts and kinds; the
  presenter only routes them. Alternatives: building text in the presenter (iOS-only tests, less coverage).
- **R2 Where change is observed.** Decision: the presenter compares the core it describes with the previous one
  (`describe` runs after every accepted action); refusals are planned where the presenter or panel sends an action and
  receives `.rejected`. Rationale: the engine already calls `describe` after accepted actions; no core change.
- **R3 Lights.** Decision: `AuroraLoomLights` eases each of the 12 crossing levels and the win glow linearly toward the
  snapshot's lit targets over 0.15 s (0.45 s under Reduce Flashing), driven by presentation time. Rationale: removes
  instant flashes, measurable on the host. Alternatives: shader-side smoothing (not measurable on the host).
- **R4 Sound.** Decision: an `AmbientLoopRecipe` per (steps, stage): three partials at a pentatonic mapping of the wave
  steps, a fourth (fifth above the root) when won, gains lowered when failed; rebuilt only at level open, play end or
  toggle on, since `AmbientLoopPlayer` fixes its recipe at creation. Rationale: reuses the shipped player and session
  category (`.ambient`, mixes with other audio); no per-move audio churn.
- **R5 Injected feedback route.** Decision: the presenter holds `feedback: ExperienceFeedback` (default `.shared`) and
  passes it as the port's `route:`; tests inject recording sinks and `voiceOverRunning: { true }`. Rationale: exact,
  deterministic simulator tests without real VoiceOver.
