# Data model: R02-G06-04

| Entity | Fields | Rules |
|---|---|---|
| `ChronoConstellatorOrbit` | yaw, pitch (radians) | yaw ±40°, pitch 30° … 75°, authored (0, 55°); presentation only |
| `ChronoConstellatorPick` | star(Int), cell(Int), timeline(Double: x fraction 0 … 1), empty | nearest star sphere hit, else the field plane (timeline band before cells), else nearest projected star or loop cell centre within 22 points |
| `ChronoConstellatorGestureController` | state (idle, starDrag, scrub, orbiting, cancelled), picked star, start point and time, travel, candidate cell, scrub tick, orbit, last empty tap time | at most two actions per gesture |
| `ChronoConstellatorGestureAction` | phase(star, index), step(ticks), rewind, hold(star, start, length), release(star, start), select(star), resetView | each maps onto a declared control except select and resetView (presentation) |
