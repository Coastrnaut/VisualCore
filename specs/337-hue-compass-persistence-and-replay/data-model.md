# Data model: R02-G04-07

| Entity | Fields | Rules |
|---|---|---|
| `HueCompassProgress.Result` | bestUnits, stars, trace [HueCompassAction], verified | a win replaces only with fewer units; trace bounded (R6) |
| `HueCompassMode` | campaign, practice, daily(level), replay(level) | replay never records; refuses other play actions except tutorial.dismiss |
| `HueCompassReconciliation` | reconcile(progress) → (progress, dropped) | a result with a trace is kept only when its replay wins having spent exactly bestUnits with its stars; untraced results kept unverified; frontier unchanged |
| Snapshot schema 3 | level, mode, progress (results with traces), records, tutorial | migration 1 → 2 → 3; 2 → 3 adds empty traces, verified false |
