# Data model: R02-G03-07

| Entity | Fields | Rules |
|---|---|---|
| `WaveKnotKeeperProgress.Result` | bestMoves, stars, trace [WaveKnotKeeperMove], verified | a win replaces only with fewer moves; trace ≤ 64 moves |
| `WaveKnotKeeperMode` | campaign, practice, daily(level), replay(level) | replay never records; refuses other play actions except point.select and tutorial.dismiss |
| `WaveKnotKeeperReconciliation` | reconcile(progress) → (progress, dropped) | a result with a trace is kept only when its replay wins in exactly bestMoves with its stars; untraced results kept unverified; frontier unchanged |
| Snapshot schema 3 | level, mode, progress (results with traces), records, tutorial | migration 1 → 2 → 3; 2 → 3 adds empty traces, verified false |
