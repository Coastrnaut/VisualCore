# Research: R02-G01-07

- **R1 Saving is shared.** Decision: rely on the app's `SavedStateStore` (atomic write-then-replace of `state.json`,
  quarantine of unreadable files, newer-schema refusal) and the engine's `MigrationChain`. Rationale: one audited path
  for every experience; this feature only defines the payload. Alternatives: an experience-owned file (duplicates the
  shared guarantees).
- **R2 Trace per result.** Decision: store the winning moves (ribbon, control, step) of the best result, not the kernel
  records. Rationale: moves are the minimal, replayable proof; records also hold undo/redo and fingerprints that the
  replay recomputes. Bounded by the allowance (≤ 64 moves).
- **R3 Reconciliation on restore.** Decision: replay each trace on a fresh play of its certified level; keep the result
  only when it wins in exactly `bestMoves` with matching stars; report the count dropped. Rationale: "reconcilable
  scores" — an edited save cannot claim unearned scores, honest saves lose nothing. Alternatives: a hash over results
  (a forger recomputes it; the replay cannot be forged).
- **R4 Replay as a mode.** Decision: `replay(level)` with `replay.start/step/stop` in the core so a replay is part of
  the deterministic state and testable on the host. Alternatives: presenter-only playback (not host-testable; the kernel
  state would diverge from the drawing).
