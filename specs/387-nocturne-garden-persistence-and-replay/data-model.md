# Data model: R02-G09-07

| Entity | Fields | Rules |
|---|---|---|
| `NocturneGardenProgress.Result` | movesMade, stars, trace [NocturneGardenAction] (effective moves), verified | a win replaces only when better (ties keep the earlier trace); trace bounded (R6) |
| `NocturneGardenMode` | campaign, practice, daily(level), replay(level) | replay never records; refuses other play actions except tutorial.dismiss and settings.sound |
| `NocturneGardenReconciliation` | reconcile(progress) → (progress, dropped); netTrace(records) | a result with a trace is kept only when its replay wins with trace.count ≤ movesMade and stars = stars rule(movesMade); untraced results kept unverified; frontier unchanged |
| Snapshot schema 3 | level, mode, progress (results with traces), records, sound, tutorial | migration 1 → 2 → 3; 2 → 3 adds empty traces, verified false, sound off; the sound choice is snapshotted, never digested |
