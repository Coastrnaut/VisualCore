# Research: R02-G06-01

- **R1 Closed-form positions instead of integration.** Decision: a star's cell at tick t is loop[(φ + t − h(t)) mod L],
  h(t) the held ticks among 1 … t (clarification Q2). Rationale: the source's "fixed-step deterministic integration" of
  motion on a loop is exactly this sum; the closed form makes any tick computable directly (scrubbing, rewind, the
  solver's phase search) and a step-by-step reference equals it, which tests prove. Alternatives: continuous orbits with
  floating point (device drift), per-tick mutable stepping only (no random access to the timeline).
- **R2 Timeline as an event log.** Decision: the timeline is the start phases plus the holds (star, start, length); edits
  only at tick 0; replay recomputes from it. Rationale: "record and replay … event log of tick-indexed actions"; editing
  only at the start keeps replay unambiguous ("rewind without ambiguity"). Alternatives: editing mid-replay (the past
  would change under the player).
- **R3 Budget as edits in use.** Decision: edits in use = changed phases + holds; releasing or restoring frees them.
  Rationale: the budget then measures the solution's size, which R02-G06-02 certifies as the smallest edit count;
  undo and redo need no separate refund rule. Alternatives: a spend-only budget (punishes exploration).
- **R4 Collision, then win, then time.** Decision: per tick collision, win, time; nothing judged at tick 0. Rationale:
  targets are distinct, so a win never coincides with a collision; a level is never won before the replay starts.
- **R5 Signed snapshots.** Decision: the timeline fingerprint (SHA-256 of phases and holds) is the snapshot replays are
  compared by, and records carry previous and next play fingerprints. Rationale: the source's "signed snapshots" and
  "tick-accurate replay hash" without any key material (no secrets in an offline game).
