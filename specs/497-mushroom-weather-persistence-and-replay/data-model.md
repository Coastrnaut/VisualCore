# Data model: R02-G20-07

| Entity | Fields | Rules |
|---|---|---|
| `MushroomWeatherProgress.Result` | actionsSpent, stars, trace [MushroomWeatherAction] (effective pod, vent and moonlight actions, then `.run`), verified | a win replaces only when better (ties keep the earlier trace); trace bounded (R6) |
| `MushroomWeatherMode` | campaign, practice, daily(level), replay(level) | replay never records; refuses other play actions except tutorial.dismiss, clock.show and settings.sound |
| `MushroomWeatherReconciliation` | reconcile(progress) → (progress, dropped); netTrace(records) | a result with a trace is kept only when its replay wins spending at most actionsSpent actions and stars = stars rule(actionsSpent, the certified action count); untraced results kept unverified; frontier unchanged |
| Snapshot schema 3 | level, mode, progress (results with traces), records, sound, tutorial | migration 1 → 2 → 3; 2 → 3 adds empty traces, verified false, sound off; the sound choice is snapshotted, never digested |
