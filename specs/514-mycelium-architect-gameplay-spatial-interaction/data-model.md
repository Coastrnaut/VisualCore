# Data model: R02-G22-04

| Entity | Fields | Rules |
|---|---|---|
| `MyceliumArchitectPickTarget` | empty, gauge, sprout(direction), root, cell(column, row) | reverse painter's order |
| `MyceliumArchitectGestureController` | state (idle, sitePress, rootPress, seedDrag, sproutPress, unseedDrag, gaugePress, scrub, cellPress, emptyPress, orbiting, cancelled), target, start and last points, press time, last tap time and place | only event timestamps read |
| `MyceliumArchitectGestureAction` | send(adapter control, values), showPulse(pulse), inspect(cell?), preview(action), clearPreview, orbit(yaw, pitch), resetView, explain(text) | kernel actions only while playing |
| `MyceliumArchitectViewOrbit` | yaw, pitch | yaw ±60°, pitch −20° … +35°; camera re-fitted with ≥ 5 % margin |
| `MyceliumArchitectPreview` | action, previewed report and verdict, or refusal | never in the digest |
| Snapshot additions | tool, preview, inspected cell, orbit | presentation only; schema stays 1 |
