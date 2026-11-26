# Data model: R02-G19-07

| Entity | Fields | Rules |
|---|---|---|
| `MicroscopicAuroraProgress.Result` | actionsSpent, stars, trace [MicroscopicAuroraAction] (effective `.place(slot:well:)` and `.remove(slot:)` actions, then `.play`), verified | a win replaces only when better (ties keep the earlier trace); trace bounded (R6) |
| `MicroscopicAuroraMode` | campaign, practice, daily(level), replay(level) | replay never records; refuses other play actions except tutorial.dismiss, clock.show and settings.sound |
| `MicroscopicAuroraReconciliation` | reconcile(progress) → (progress, dropped); netTrace(records) | a result with a trace is kept only when its replay wins spending at most actionsSpent placements and removals and stars = stars rule(actionsSpent, the certified placement or removal count); untraced results kept unverified; frontier unchanged |
| Snapshot schema 3 | level, mode, progress (results with traces), records, sound, tutorial | migration 1 → 2 → 3; 2 → 3 adds empty traces, verified false, sound off; the sound choice is snapshotted, never digested |
