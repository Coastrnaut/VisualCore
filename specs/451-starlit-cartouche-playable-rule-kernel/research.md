# Research: R02-G16-01

- **R1 Beats, not seconds.** Decision: the kernel counts whole beats (one quantized launch tick); a beat is 30
  presentation ticks of 0.008333 s for later features. Rationale: "quantized launch ticks" made exact; no floating point
  decides a rule. Alternatives: the 0.008333 s tick itself (120 per second; every window and wait would be large numbers
  without changing any decision).
- **R2 Periodic lattice orbits.** Decision: a star's position at beat b is orbit[b mod length] with 1 … 4 lattice
  positions. Rationale: "a moving 3D star chart" with exact, periodic motion that the solver can expand in time; the
  period divides 12, so the chart repeats every 12 beats at most.
- **R3 Range gates corridors.** Decision: a corridor is flyable at the departure beat when its stars' squared distance
  is at most r². Rationale: makes the motion matter to the rules (a leg must wait for its stars to come close), decided
  by an integer comparison. An out-of-range leg is refused, not a failure, as an idle hinge is in feature 441: it changes
  nothing and would only inflate the solver's state space.
- **R4 Failure order.** Decision: departure window, hazard, arrival window, deadline, stroke. Rationale: follows the
  leg in time (leaving, travelling, arriving), then the two rules about the whole route; one leg reports one reason.
- **R5 Stray strokes fail.** Decision: a corridor outside the symbol fails the leg (`stroke`). Rationale: the drawn set
  only grows, so a stray stroke can never be part of a win; failing at once is honest and lets undo recover.
- **R6 Hazard tubes on corridors.** Decision: a hazard names a corridor and a closed beat interval; a leg meets it when
  [t₀, t₁] intersects the interval. Rationale: "route crosses hazard tube" decided exactly; the tube is drawn across the
  corridor in later features. Alternatives: free 3D capsules (floating point, and corridors would need sweeping).
- **R7 Fingerprints as the signed snapshot.** Decision: the play fingerprint (SHA-256 of schema, level fingerprint,
  ship star and beat, drawn strokes, legs flown, actions spent, stage, failure) and records with previous and next
  fingerprints, as feature 441.
- **R8 Undo from failed.** Decision: undo from failed returns to playing before the failing leg and refunds its action
  (recorded); a won level refuses undo.
