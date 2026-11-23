# Data model: R02-G11-04

| Entity | Fields | Rules |
|---|---|---|
| `EchoCartographerOrbit` | yaw, pitch (radians) | yaw ±35°, pitch −15° … +20°; authored (0, 0); presentation only |
| `EchoCartographerPick` | marker(cell), cell(cell), empty | markers first (22 points), then the floor cell under the point |
| `EchoCartographerGestureAction` | pulse(x, y), claim(x, y), mark(x, y), moveCursor(x, y), resetView | pulse, claim and mark map onto the declared `cell.*` controls |
| `EchoCartographerGestureController` | state, orbit, touched pick, start/last points, press time, armed hold, last tap | handle(event, viewSize, snapshot, play) |
