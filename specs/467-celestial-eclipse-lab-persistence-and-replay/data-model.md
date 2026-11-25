# Data model: R02-G17-07

| Entity | Fields | Rules |
|---|---|---|
| `CelestialEclipseLabProgress.Result` | actionsSpent, stars, trace [CelestialEclipseLabAction] (effective `.phase(body, offset)` changes, then `.run`), verified | a win replaces only when better (ties keep the earlier trace); trace bounded (R6) |
| `CelestialEclipseLabMode` | campaign, practice, daily(level), replay(level) | replay never records; refuses other play actions except tutorial.dismiss, orbit.choose, clock.show and settings.sound |
| `CelestialEclipseLabReconciliation` | reconcile(progress) → (progress, dropped); netTrace(records) | a result with a trace is kept only when its replay wins spending at most actionsSpent changes and stars = stars rule(actionsSpent, the certified change count); untraced results kept unverified; frontier unchanged |
| Snapshot schema 3 | level, mode, progress (results with traces), records, sound, tutorial | migration 1 → 2 → 3; 2 → 3 adds empty traces, verified false, sound off; the sound choice is snapshotted, never digested |
