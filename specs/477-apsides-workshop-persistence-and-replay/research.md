# Research: R02-G18-07

- **R1 Saving is shared.** Decision: rely on the app's `SavedStateStore` (atomic write-then-replace, quarantine of
  unreadable files, newer-schema refusal) and the engine's `MigrationChain`. Rationale: one audited path for every
  experience; this feature only defines the payload. - **R2 Trace per result.** Decision: store the winning play's
  effective actions (`ApsidesWorkshopAction.periapsis(k, d)` and `.size(a)` as the kernel applied them, an undone tuning
  left out unless redone, then `.play`) — not the kernel records. Rationale: actions are the minimal, replayable proof;
  the net list (every undo cancelling the last net action, every redo restoring it) needs no undo in replay; a level is
  won only by its play, so every honest trace ends with `.play`. - **R3 Reconciliation on restore.** Decision: replay
  each trace on a fresh play of its certified level (campaign budget); keep the result only when it wins, the tunings
  the trace spends are at most `actionsSpent` (which counts undone tunings too) and the stars match the stars rule for
  `actionsSpent`; report the count dropped. Rationale: an edited save cannot claim unearned scores; honest saves lose
  nothing. - **R4 Frontier as saved.** Decision: restore the frontier exactly as saved (the lesson of features 307 …
  467). Rationale: raising it from kept results would open levels for an honest daily win, which never opens levels. -
  **R5 Replay as a mode.** Decision: `replay(level)` with `replay.start/step/stop` in the core, so a replay is part of
  the deterministic state and testable on the host. - **R6 Trace bound.** Decision: a trace with more than 64 actions,
  an action the kernel refuses, an action after the play or no final play never verifies. The kernel's budget is at most
  24, so an honest trace has at most 25 actions (24 tunings and the play); the bound only stops an edited save from
  making the check replay a very long list. - **R7 Actions spent versus trace.** Decision: `actionsSpent` keeps counting
  undone tunings (R02-G18-05's rule), so reconciliation requires the trace's tunings to be at most `actionsSpent`
  instead of equality. Rationale: an honest play with undos spends more than its effective tunings; a lowered
  `actionsSpent` still cannot claim less than the replayed trace proves, and a raised one only worsens the score.
  Alternatives: storing undo and redo in the trace (replay would need undo; rejected by Q1).
