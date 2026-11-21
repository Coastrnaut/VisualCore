# Research: R02-G05-07

- **R1 Saving is shared.** Decision: rely on the app's `SavedStateStore` (atomic write-then-replace, quarantine of
  unreadable files, newer-schema refusal) and the engine's `MigrationChain`. Rationale: one audited path for every
  experience; this feature only defines the payload.
- **R2 Trace per result.** Decision: store the winning play's net actions (`ColorfallCanyonsAction`: carves, valve
  toggles and steps; an undone action left out unless redone) — not the kernel records. Rationale: actions are the
  minimal, replayable proof; the net list (the records with every undo cancelling the last net action and every redo
  restoring it) needs no undo in replay; bounded by the budget and the tick limit.
- **R3 Reconciliation on restore.** Decision: replay each trace on a fresh play of its certified level (campaign
  budget); keep the result only when it wins having spent exactly `bestActions` with matching stars; report the count
  dropped. Rationale: an edited save cannot claim unearned scores; honest saves lose nothing.
- **R4 Frontier as saved.** Decision: restore the frontier exactly as saved (the lesson of features 307, 317 and 327).
  Rationale: raising it from kept results would open levels for an honest daily win, which never opens levels.
- **R5 Replay as a mode.** Decision: `replay(level)` with `replay.start/step/stop` in the core, so a replay is part of
  the deterministic state and testable on the host.
- **R6 Trace bound.** Decision: a trace with more than 30 carves and valve toggles (the largest budget) or more than
  3,600 steps (the largest tick limit), or with an illegal action, never verifies. Rationale: bounded restore work
  against an edited file.
