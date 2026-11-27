# Data model: R02-G21-07

| Entity | Fields | Rules |
|---|---|---|
| `BinaryGardensProgress.Result` | actionsSpent, stars, trace, verified | see below |
| `BinaryGardensMode` | campaign, practice, daily(level), replay(level) | replay never records |
| `BinaryGardensReconciliation` | reconcile(progress) → (progress, dropped); netTrace(records) | frontier unchanged |
| Replay | level, trace, position | position = trace actions applied |
| Snapshot schema 3 | level, mode, progress, records, sound, tutorial | sorted keys; migration 1 → 2 → 3 |

- **Result**: `trace` is [BinaryGardensAction], the effective ring, phase, luminosity and tilt actions of the winning
  play, then `.run`; `verified` is true for a win recorded under schema 3. A campaign or daily win replaces the stored
  result only when it spends fewer actions (ties keep the earlier trace); practice and replay record nothing; the trace
  is bounded (64 actions) and an honest one holds at most 25.
- **Mode**: `replay(level)` refuses every control except `replay.start`, `replay.step`, `replay.stop`,
  `tutorial.dismiss`, `clock.show` and `settings.sound` with `r02-g21.replay`; it never changes progress; it plays the
  certified level with the campaign budget, tutorial done, tick 48 shown at its start.
- **Reconciliation**: a result with a trace or marked verified is kept only when its replay on a fresh play of the
  certified level wins with exactly one final run, spending at most `actionsSpent` actions, and `stars` equals the
  stars rule for `actionsSpent` and the certified plan's size; untraced, unverified results are kept unverified; the
  dropped count is never in the digest or `==`.
- **Replay**: the position is the play's ring, phase, luminosity, tilt and run records; `replay.step` applies
  `trace[position]` while the play is playing, else `r02-g21.replay-end`; a saved replay's action records must be a
  prefix of the verified trace, else the payload is `damaged`.
- **Snapshot schema 3**: 2 → 3 gives every result an empty trace and `verified: false` and sets `sound` false; 1 → 2
  is feature 505's step; schema 4 or newer is refused by the shared store; the sound choice is snapshotted and in `==`,
  never digested; the digest (`"r02-g21.binary-gardens.v3"`) covers level, play fingerprint, progress and mode.
