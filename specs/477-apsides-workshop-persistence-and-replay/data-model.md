# Data model: R02-G18-07

| Entity | Fields | Rules |
|---|---|---|
| `ApsidesWorkshopProgress.Result` | actionsSpent, stars, trace [ApsidesWorkshopAction] (effective `.periapsis(k, d)` and `.size(a)` tunings, then `.play`), verified | a win replaces only when better (ties keep the earlier trace); trace bounded (R6) |
| `ApsidesWorkshopMode` | campaign, practice, daily(level), replay(level) | replay never records; refuses other play actions except tutorial.dismiss, clock.show and settings.sound |
| `ApsidesWorkshopReconciliation` | reconcile(progress) → (progress, dropped); netTrace(records) | a result with a trace is kept only when its replay wins spending at most actionsSpent tunings and stars = stars rule(actionsSpent, the certified tuning count); untraced results kept unverified; frontier unchanged |
| Snapshot schema 3 | level, mode, progress (results with traces), records, sound, tutorial | migration 1 → 2 → 3; 2 → 3 adds empty traces, verified false, sound off; the sound choice is snapshotted, never digested |
