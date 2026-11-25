# Research: R02-G17-01

- **R1 Ticks, not seconds.** Decision: the kernel counts whole ticks of the miniature clock; the catalog's 0.008333 s
  timestep is the presentation clock of later features. Rationale: an exact clock; no floating point decides a rule.
- **R2 Periodic lattice orbits with a phase.** Decision: a body's position at tick t is orbit[(t + phase) mod period]
  with 4 … 24 lattice positions. Rationale: "position and phase miniature orbits" made exact and periodic, so the solver
  can enumerate phase vectors; the phase is the player's lever ("drag orbital handles").
- **R3 Depth bands.** Decision: every pair of bodies keeps one front-to-back order at every tick (the front body's
  smallest z above the back body's largest z), checked when the level is built. Rationale: "validate depth ordering to
  disambiguate occultations" becomes a property of the level, so every eclipse has one front body without a tie rule.
  Alternatives: ordering by z per tick with a tie rule (an eclipse could change its label mid-interval, which makes the
  target ambiguous).
- **R4 Strict overlap.** Decision: discs eclipse when the squared distance is strictly below the squared radius sum;
  touching discs do not. Rationale: an exact, symmetric integer test; "circle-circle overlap computed analytically".
- **R5 Events and classes.** Decision: an event is the first tick of each run of eclipse ticks of a pair; an interval
  runs to the last such tick; its class is the deepest over its ticks (total or annular before partial). Rationale:
  "ordered interval overlap timestamps and visibility classification" exactly.
- **R6 Judge order.** Decision: walk events by tick (ties by front then back body): a match advances, the next target
  outside its window fails `window`, any other event fails `unwanted`, no events left fails `horizon`; events after the
  last match are ignored. Rationale: "unwanted eclipse occurs before required eclipse" made exact, with one reason per
  run.
- **R7 Run as the commitment.** Decision: phase changes cost actions and keep the level playing; `run` costs nothing and
  ends it; the predicted outcome is reported after every action. Rationale: the timeline is fully determined by the
  phases, so a "run" is the player's decision to commit, and undo from failed lets the player try again (as undo from
  failed in feature 451).
- **R8 Fingerprints as the signed snapshot.** Decision: the play fingerprint (SHA-256 of schema, level fingerprint,
  phases, actions spent, stage, failure) and records with previous and next fingerprints, as feature 451.
