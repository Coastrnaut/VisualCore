# Data model: R02-G16-07

| Entity | Fields | Rules |
|---|---|---|
| `StarlitCartoucheProgress.Result` | actionsSpent, stars, trace [StarlitCartoucheAction] (effective legs, each `.leg(star, wait)`), verified | a win replaces only when better (ties keep the earlier trace); trace bounded (R6) |
| `StarlitCartoucheMode` | campaign, practice, daily(level), replay(level) | replay never records; refuses other play actions except tutorial.dismiss, route.choose and settings.sound |
| `StarlitCartoucheReconciliation` | reconcile(progress) → (progress, dropped); netTrace(records) | a result with a trace is kept only when its replay wins spending at most actionsSpent and stars = stars rule(actionsSpent, the certified witness action count); untraced results kept unverified; frontier unchanged |
| Snapshot schema 3 | level, mode, progress (results with traces), records, sound, tutorial | migration 1 → 2 → 3; 2 → 3 adds empty traces, verified false, sound off; the sound choice is snapshotted, never digested |
