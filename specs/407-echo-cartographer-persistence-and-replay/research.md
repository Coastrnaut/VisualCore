# Research: R02-G11-07

- **R1 Saving is shared.** Decision: rely on the app's `SavedStateStore` (atomic write-then-replace, quarantine of
  unreadable files, newer-schema refusal) and the engine's `MigrationChain`. Rationale: one audited path for every
  experience; this feature only defines the payload.
- **R2 Trace per result.** Decision: store the winning play's effective actions (`EchoCartographerAction` pulse, claim or mark with its cell, as the
  kernel applied them; an undone action left out unless redone) — not the kernel records.
  Rationale: actions are the minimal, replayable proof; the net list (every undo cancelling the last net action, every
  redo restoring it) needs no undo in replay.
- **R3 Reconciliation on restore.** Decision: replay each trace on a fresh play of its certified level (campaign
  energy); keep the result only when it wins, the energy the trace spends is at most `energySpent` (which counts undone
  actions too) and the stars match the stars rule for `energySpent`; report the count dropped. Rationale: an edited save cannot claim
  unearned scores; honest saves lose nothing.
- **R4 Frontier as saved.** Decision: restore the frontier exactly as saved (the lesson of features 307 … 397).
  Rationale: raising it from kept results would open levels for an honest daily win, which never opens levels.
- **R5 Replay as a mode.** Decision: `replay(level)` with `replay.start/step/stop` in the core, so a replay is part of
  the deterministic state and testable on the host.
- **R6 Trace bound.** Decision: a trace with more than 128 actions, or with an action the kernel refuses, never verifies.
  Rationale: a winning play spends at most 60 energy (the kernel's largest) and its markers toggle at most 8 cells, so an
  honest effective trace stays far below 128; the bound keeps restore work small
  against an edited file.
- **R7 Energy spent versus trace.** Decision: `energySpent` keeps counting undone pulses and claims (R02-G11-05's rule),
  so reconciliation requires the trace's energy to be at most `energySpent` instead of equality. Rationale: an honest play
  with undos spends more than its effective actions; a lowered `energySpent` still cannot claim less than the replayed
  trace proves, and a raised one only worsens the score. Alternatives: storing undo and redo in the trace (replay would
  need undo; rejected by Q1).