# Data model: R02-G06-07

| Entity | Fields | Rules |
|---|---|---|
| `ChronoConstellatorProgress.Result` | bestEdits, stars, trace [ChronoConstellatorAction], verified | a win replaces only when better (ties keep the earlier trace); trace bounded (R6) |
| `ChronoConstellatorMode` | campaign, practice, daily(level), replay(level) | replay never records; refuses other play actions except tutorial.dismiss and settings.sound |
| `ChronoConstellatorReconciliation` | reconcile(progress) → (progress, dropped); netTrace(records) | a result with a trace is kept only when its replay wins with exactly bestEdits and its stars; untraced results kept unverified; frontier unchanged |
| Snapshot schema 3 | level, mode, progress (results with traces), records, sound, tutorial | migration 1 → 2 → 3; 2 → 3 adds empty traces, verified false, sound off; the sound choice is snapshotted, never digested |
