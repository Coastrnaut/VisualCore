# Data model: R02-G01-07

| Entity | Fields | Rules |
|---|---|---|
| `AuroraLoomProgress.Result` | bestMoves, stars, trace: [AuroraLoomMove], verified | trace.count == bestMoves when verified; fewer moves replace |
| `AuroraLoomReconciliation` | kept progress, dropped count | each verified result replayed on its certified level |
| `AuroraLoomMode.replay(level:)` | level, position in the trace | other play actions refused (`r02-g01.replay`) |
| Snapshot schema 3 | level, records, progress (results with traces), mode, tutorial | migrations 1 → 2 → 3 |
