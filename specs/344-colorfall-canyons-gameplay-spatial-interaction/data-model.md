# Data model: R02-G05-04

| Entity | Fields | Rules |
|---|---|---|
| `ColorfallCanyonsOrbit` | yaw, pitch (radians) | yaw ±40°, pitch 25° … 70°, authored (0, 50°); presentation only |
| `ColorfallCanyonsPick` | cell(Int), spring(Int), empty | nearest ray hit, else nearest projected centre within 22 points |
| `ColorfallCanyonsGestureController` | state (idle, dragging, orbiting, cancelled), picked cell, start point, travel, orbit, last empty tap time | one action per gesture |
| `ColorfallCanyonsGestureAction` | carve(cell), valve(spring), resetView | carve after ≥ 16 points; valve on a spring tap; reset on a double tap within 0.35 s on empty space |
