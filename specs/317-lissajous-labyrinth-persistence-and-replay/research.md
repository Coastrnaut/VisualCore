# Research: R02-G02-07

- **R1 Saving is shared.** Decision: rely on the app's `SavedStateStore` (atomic write-then-replace, quarantine of
  unreadable files, newer-schema refusal) and the engine's `MigrationChain`. Rationale: one audited path for every
  experience; this feature only defines the payload.
- **R2 Trace per result.** Decision: store the winning actions (dial, value) of the best result — the play's undo stack
  of net changes — not the kernel records. Rationale: actions are the minimal, replayable proof; bounded by the
  allowance (≤ 64).
- **R3 Reconciliation on restore.** Decision: replay each trace on a fresh play of its certified level; keep the result
  only when it wins in exactly `bestActions` with matching stars; report the count dropped. Rationale: an edited save
  cannot claim unearned scores; honest saves lose nothing.
- **R4 Frontier as saved.** Decision: restore the frontier exactly as saved (the lesson of feature 307). Rationale:
  raising it from kept results would open levels for an honest daily win, which never opens levels, and change an honest
  save on restore.
- **R5 Replay as a mode.** Decision: `replay(level)` with `replay.start/step/stop` in the core, so a replay is part of the
  deterministic state and testable on the host.
