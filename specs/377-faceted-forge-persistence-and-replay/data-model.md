# Data model: R02-G08-07

| Entity | Fields | Rules |
|---|---|---|
| `FacetedForgeProgress.Result` | cutsMade, stars, trace [FacetedForgeAction] (effective cuts), verified | a win replaces only when better (ties keep the earlier trace); trace bounded (R6) |
| `FacetedForgeMode` | campaign, practice, daily(level), replay(level) | replay never records; refuses other play actions except tutorial.dismiss and settings.sound |
| `FacetedForgeReconciliation` | reconcile(progress) → (progress, dropped); netTrace(records) | a result with a trace is kept only when its replay wins with trace.count ≤ cutsMade and stars = stars rule(cutsMade); untraced results kept unverified; frontier unchanged |
| Snapshot schema 3 | level, mode, progress (results with traces), records, sound, tutorial | migration 1 → 2 → 3; 2 → 3 adds empty traces, verified false, sound off; the sound choice is snapshotted, never digested |
