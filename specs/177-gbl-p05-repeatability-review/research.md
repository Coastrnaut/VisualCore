# Research: A24-P05 (feature 177)

- **R1 Background detection.** `FrameInfo.time` is wall-clock since the host's first frame and never paused, so a
  background gap is one long interval; the recorder's 0…1,000 ms rule already interrupts the run. Decision: no new
  hook; a test proves it.
- **R2 Qualification derived, not stored.** Rationale: old saved results get it without migration, and one rule
  serves list, view and export.
- **R3 Comparability keys.** Case fingerprint, device model, OS version, app build and tier; thermal and Low Power
  Mode qualify a trial but do not exclude it. Rationale: the manual's risk 1 asks for context and repeated trials.
- **R4 Spread, not statistics across trials.** Rationale: a handful of trials; a range is honest, a confidence claim
  would be invented.
- **R5 Interface chunk f3.** The A24 tests run serially in their own chunk, as `e3` does for A23.
