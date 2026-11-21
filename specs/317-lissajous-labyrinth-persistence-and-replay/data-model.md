# Data model: R02-G02-07

| Entity | Fields | Rules |
|---|---|---|
| `LissajousLabyrinthProgress.Result` | bestActions, stars, trace [LissajousLabyrinthAction], verified | a win replaces only with fewer actions; trace ≤ 64 actions |
| `LissajousLabyrinthMode` | campaign, practice, daily(level), replay(level) | replay never records; refuses other play actions |
| `LissajousLabyrinthReconciliation` | reconcile(progress) → (progress, dropped) | a result with a trace is kept only when its replay wins in exactly bestActions with its stars; untraced results kept unverified; frontier unchanged |
| Snapshot schema 3 | level, mode, progress (results with traces), records, tutorial | migration 1 → 2 → 3; 2 → 3 adds empty traces, verified false |
