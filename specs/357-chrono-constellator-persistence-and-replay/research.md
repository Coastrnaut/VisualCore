# Research: R02-G06-07

- **R1 Saving is shared.** Decision: rely on the app's `SavedStateStore` (atomic write-then-replace, quarantine of
  unreadable files, newer-schema refusal) and the engine's `MigrationChain`. Rationale: one audited path for every
  experience; this feature only defines the payload.
- **R2 Trace per result.** Decision: store the winning play's net actions (`ChronoConstellatorAction`: phase changes,
  holds, releases, steps and rewinds; an undone action left out unless redone) — not the kernel records. Rationale:
  actions are the minimal, replayable proof; the net list (every undo cancelling the last net action, every redo
  restoring it) needs no undo in replay.
- **R3 Reconciliation on restore.** Decision: replay each trace on a fresh play of its certified level (campaign budget);
  keep the result only when it wins with exactly `bestEdits` edits in use and matching stars; report the count dropped.
  Rationale: an edited save cannot claim unearned scores; honest saves lose nothing.
- **R4 Frontier as saved.** Decision: restore the frontier exactly as saved (the lesson of features 307 … 347).
  Rationale: raising it from kept results would open levels for an honest daily win, which never opens levels.
- **R5 Replay as a mode.** Decision: `replay(level)` with `replay.start/step/stop` in the core, so a replay is part of
  the deterministic state and testable on the host.
- **R6 Trace bound.** Decision: a trace with more than 64 actions, or with an illegal action, never verifies. Rationale:
  a winning play needs at most 20 edits (the largest budget) plus its steps and rewinds; the bound keeps restore work
  small against an edited file.
