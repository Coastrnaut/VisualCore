# Data model: R02-G12-07

| Entity | Fields | Rules |
|---|---|---|
| `HarmonicBridgesProgress.Result` | actionsSpent, stars, trace [HarmonicBridgesAction] (effective tunings and the test), verified | a win replaces only when better (ties keep the earlier trace); trace bounded (R6) |
| `HarmonicBridgesMode` | campaign, practice, daily(level), replay(level) | replay never records; refuses other play actions except tutorial.dismiss and settings.sound |
| `HarmonicBridgesReconciliation` | reconcile(progress) → (progress, dropped); netTrace(records) | a result with a trace is kept only when its replay wins spending at most actionsSpent and stars = stars rule(actionsSpent, the certified witness action count); untraced results kept unverified; frontier unchanged |
| Snapshot schema 3 | level, mode, progress (results with traces), records, sound, tutorial | migration 1 → 2 → 3; 2 → 3 adds empty traces, verified false, sound off; the sound choice is snapshotted, never digested |
