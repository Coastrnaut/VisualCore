# Research: R02-G09-07

- **R1 Saving is shared.** Decision: rely on the app's `SavedStateStore` (atomic write-then-replace, quarantine of
  unreadable files, newer-schema refusal) and the engine's `MigrationChain`. Rationale: one audited path for every
  experience; this feature only defines the payload.
- **R2 Trace per result.** Decision: store the winning play's effective moves (`NocturneGardenAction` plant, move,
  resize, remove and sun as the kernel applied them; an undone move left out unless redone) — not the kernel records.
  Rationale: actions are the minimal, replayable proof; the net list (every undo cancelling the last net action, every
  redo restoring it) needs no undo in replay, and bloom numbers stay those of the canonical order the play had.
- **R3 Reconciliation on restore.** Decision: replay each trace on a fresh play of its certified level (campaign
  budget); keep the result only when it wins, the trace's length is at most `movesMade` (which counts undone moves too)
  and the stars match the stars rule for `movesMade`; report the count dropped. Rationale: an edited save cannot claim
  unearned scores; honest saves lose nothing.
- **R4 Frontier as saved.** Decision: restore the frontier exactly as saved (the lesson of features 307 … 377).
  Rationale: raising it from kept results would open levels for an honest daily win, which never opens levels.
- **R5 Replay as a mode.** Decision: `replay(level)` with `replay.start/step/stop` in the core, so a replay is part of
  the deterministic state and testable on the host.
- **R6 Trace bound.** Decision: a trace with more than 40 moves (the kernel's largest budget), or with an illegal move,
  never verifies. Rationale: a recorded win uses at most its level's campaign budget; the bound keeps restore work small
  against an edited file.
- **R7 Moves made versus trace.** Decision: `movesMade` keeps counting undone moves (R02-G09-05's rule), so
  reconciliation requires `trace.count ≤ movesMade` instead of equality. Rationale: an honest play with undos has more
  moves made than effective moves; a lowered `movesMade` still cannot claim fewer moves than the replayed trace proves,
  and a raised one only worsens the score. Alternatives: storing undo and redo in the trace (replay would need undo;
  rejected by Q1).
