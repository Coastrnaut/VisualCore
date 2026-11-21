# Data model: R02-G05-07

| Entity | Fields | Rules |
|---|---|---|
| `ColorfallCanyonsProgress.Result` | bestActions, stars, trace [ColorfallCanyonsAction], verified | a win replaces only when better; trace bounded (R6) |
| `ColorfallCanyonsMode` | campaign, practice, daily(level), replay(level) | replay never records; refuses other play actions except tutorial.dismiss |
| `ColorfallCanyonsReconciliation` | reconcile(progress) → (progress, dropped) | a result with a trace is kept only when its replay wins having spent exactly bestActions with its stars; untraced results kept unverified; frontier unchanged |
| Snapshot schema 3 | level, mode, progress (results with traces), records, tutorial, sound | migration 1 → 2 → 3; 2 → 3 adds empty traces, verified false, sound off; the sound choice is snapshotted, never digested |
