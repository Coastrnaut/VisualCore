# Research: R02-G14-07

- **R1 Saving is shared.** Decision: rely on the app's `SavedStateStore` (atomic write-then-replace, quarantine of
  unreadable files, newer-schema refusal) and the engine's `MigrationChain`. Rationale: one audited path for every
  experience; this feature only defines the payload.
- **R2 Trace per result.** Decision: store the winning play's effective actions (`MoonlitMechanismAction` a turn with its step, a re-seat with its gear and step, a lamp step with its step, or the run, as
  the kernel applied them; an undone action left out unless redone) — not the kernel records.
  Rationale: actions are the minimal, replayable proof; the net list (every undo cancelling the last net action, every
  redo restoring it) needs no undo in replay.
- **R3 Reconciliation on restore.** Decision: replay each trace on a fresh play of its certified level (campaign
  budget); keep the result only when it wins, the actions the trace spends is at most `actionsSpent` (which counts undone
  actions too) and the stars match the stars rule for `actionsSpent`; report the count dropped. Rationale: an edited save cannot claim
  unearned scores; honest saves lose nothing.
- **R4 Frontier as saved.** Decision: restore the frontier exactly as saved (the lesson of features 307 … 427).
  Rationale: raising it from kept results would open levels for an honest daily win, which never opens levels.
- **R5 Replay as a mode.** Decision: `replay(level)` with `replay.start/step/stop` in the core, so a replay is part of
  the deterministic state and testable on the host.
- **R6 Trace bound.** Decision: a trace with more than 64 actions, or with an action the kernel refuses, never verifies.
  Rationale: a winning play spends at most 60 actions (the kernel's largest budget), so an honest effective trace has at
  most 60; the bound keeps restore work small
  against an edited file.
- **R7 Actions spent versus trace.** Decision: `actionsSpent` keeps counting undone turns, re-seats, lamp steps and runs (R02-G14-05's rule),
  so reconciliation requires the trace's actions to be at most `actionsSpent` instead of equality. Rationale: an honest play
  with undos spends more than its effective actions; a lowered `actionsSpent` still cannot claim less than the replayed
  trace proves, and a raised one only worsens the score. Alternatives: storing undo and redo in the trace (replay would
  need undo; rejected by Q1).