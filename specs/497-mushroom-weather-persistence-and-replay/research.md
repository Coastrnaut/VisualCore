# Research: R02-G20-07

- **R1 Saving is shared.** Decision: rely on the app's `SavedStateStore` (atomic write-then-replace, quarantine of
  unreadable files, newer-schema refusal) and the engine's `MigrationChain`. Rationale: one audited path for every
  experience; this feature only defines the payload. - **R2 Trace per result.** Decision: store the winning play's
  effective actions (the pod, vent and moonlight actions as the kernel applied them, an undone action left out unless
  redone, then `.run`) — not the kernel records. Rationale: actions are the minimal, replayable proof;
  the net list (every undo cancelling the last net action, every redo restoring it) needs no undo in replay; a level is
  won only by its run, so every honest trace ends with `.run`. - **R3 Reconciliation on restore.** Decision: replay
  each trace on a fresh play of its certified level (campaign budget); keep the result only when it wins, the actions the trace spends are at most `actionsSpent` (which counts undone actions too) and the stars match the stars rule for
  `actionsSpent`; report the count dropped. Rationale: an edited save cannot claim unearned scores; honest saves lose
  nothing. - **R4 Frontier as saved.** Decision: restore the frontier exactly as saved (the lesson of features 307 …
  487). Rationale: raising it from kept results would open levels for an honest daily win, which never opens levels. -
  **R5 Replay as a mode.** Decision: `replay(level)` with `replay.start/step/stop` in the core, so a replay is part of
  the deterministic state and testable on the host. - **R6 Trace bound.** Decision: a trace with more than 64 actions,
  an action the kernel refuses, an action after the run or no final run never verifies. The kernel's budget is at most
  24, so an honest trace has at most 25 actions (24 pod, vent and moonlight actions and the run); the bound only stops an edited save from
  making the check replay a very long list. - **R7 Actions spent versus trace.** Decision: `actionsSpent` keeps counting
  undone actions (R02-G20-05's rule), so reconciliation requires the trace's actions to be at most `actionsSpent`
  instead of equality. Rationale: an honest play with undos spends more than its effective actions; a lowered
  `actionsSpent` still cannot claim less than the replayed trace proves, and a raised one only worsens the score.
  Alternatives: storing undo and redo in the trace (replay would need undo; rejected by Q1).
