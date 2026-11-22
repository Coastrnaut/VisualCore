# Data model: R02-G07-07

| Entity | Fields | Rules |
|---|---|---|
| `AmethystEscapeProgress.Result` | bestMoves, stars, trace [AmethystEscapeAction], verified | a win replaces only when better (ties keep the earlier trace); trace bounded (R6) |
| `AmethystEscapeMode` | campaign, practice, daily(level), replay(level) | replay never records; refuses other play actions except tutorial.dismiss and settings.sound |
| `AmethystEscapeReconciliation` | reconcile(progress) → (progress, dropped); netTrace(records) | a result with a trace is kept only when its replay wins with exactly bestMoves and its stars; untraced results kept unverified; frontier unchanged |
| Snapshot schema 3 | level, mode, progress (results with traces), records, sound, tutorial | migration 1 → 2 → 3; 2 → 3 adds empty traces, verified false, sound off; the sound choice is snapshotted, never digested |
