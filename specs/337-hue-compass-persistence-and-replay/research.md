# Research: R02-G04-07

- **R1 Saving is shared.** Decision: rely on the app's `SavedStateStore` (atomic write-then-replace, quarantine of
  unreadable files, newer-schema refusal) and the engine's `MigrationChain`. Rationale: one audited path for every
  experience; this feature only defines the payload.
- **R2 Trace per result.** Decision: store the winning play's net actions (`HueCompassAction`: turns, probes, the
  selection; an undone turn left out) — not the kernel records. Rationale: actions are the minimal, replayable proof;
  undo exists only for turns, so the net list is well defined and needs no undo in replay; bounded by the allowance.
- **R3 Reconciliation on restore.** Decision: replay each trace on a fresh play of its certified level (campaign
  allowance); keep the result only when it wins having spent exactly `bestUnits` with matching stars; report the count
  dropped. Rationale: an edited save cannot claim unearned scores; honest saves lose nothing.
- **R4 Frontier as saved.** Decision: restore the frontier exactly as saved (the lesson of features 307, 317 and 327).
  Rationale: raising it from kept results would open levels for an honest daily win, which never opens levels.
- **R5 Replay as a mode.** Decision: `replay(level)` with `replay.start/step/stop` in the core, so a replay is part of
  the deterministic state and testable on the host.
- **R6 Trace bound.** Decision: a trace longer than 24 units plus 48 turns per unit, or with an illegal action, never
  verifies. Rationale: bounded restore work against an edited file.
