# Research: R02-G08-07

- **R1 Saving is shared.** Decision: rely on the app's `SavedStateStore` (atomic write-then-replace, quarantine of
  unreadable files, newer-schema refusal) and the engine's `MigrationChain`. Rationale: one audited path for every
  experience; this feature only defines the payload.
- **R2 Trace per result.** Decision: store the winning play's effective cuts (`FacetedForgeAction.cut(piece,
  direction, depth)`; an undone cut left out unless redone) — not the kernel records. Rationale:
  actions are the minimal, replayable proof; the net list (every undo cancelling the last net action, every redo
  restoring it) needs no undo in replay.
- **R3 Reconciliation on restore.** Decision: replay each trace on a fresh play of its certified level (campaign budget);
  keep the result only when it wins, the trace's length is at most `cutsMade` (which counts undone cuts too) and
  the stars match the stars rule for `cutsMade`; report the count dropped.
  Rationale: an edited save cannot claim unearned scores; honest saves lose nothing.
- **R4 Frontier as saved.** Decision: restore the frontier exactly as saved (the lesson of features 307 … 367).
  Rationale: raising it from kept results would open levels for an honest daily win, which never opens levels.
- **R5 Replay as a mode.** Decision: `replay(level)` with `replay.start/step/stop` in the core, so a replay is part of
  the deterministic state and testable on the host.
- **R6 Trace bound.** Decision: a trace with more than 32 cuts, or with an illegal cut, never verifies. Rationale: a recorded
  win uses at most its level's budget (8 … 19 cuts in the certified catalog; practice records nothing); the bound keeps
  restore work small against an edited file.
- **R7 Cuts made versus trace.** Decision: `cutsMade` keeps counting undone cuts (R02-G08-05's rule), so reconciliation
  requires `trace.count ≤ cutsMade` instead of equality. Rationale: an honest play with undos has more cuts made than
  effective cuts; a lowered `cutsMade` still cannot claim fewer cuts than the replayed trace proves, and a raised one
  only worsens the score. Alternatives: storing undo and redo in the trace (replay would need undo; rejected by Q1).
