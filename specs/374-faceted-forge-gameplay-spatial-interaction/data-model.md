# Data model: R02-G08-04

| Entity | Fields | Rules |
|---|---|---|
| `FacetedForgeOrbit` | yaw, pitch (radians) | yaw ±40°, pitch 10° … 60°, authored (0, 30°); presentation only |
| `FacetedForgePick` | rim, plane, piece(Int), empty | rim within 22 points of the projected outline, then the plane polygon, then the nearest opened face polygon, then a projected piece centre within 22 points |
| `FacetedForgeGestureController` | state (idle, rimDrag, depthDrag, planePress, piecePress, orbiting, cancelled), choice at touch-down, candidate choice, start point and time, travel, orbit, last tap time and place | at most one cut per gesture; choices clamped to the play |
| `FacetedForgeGestureAction` | choose(FacetedForgePreviewChoice), cut(piece, direction, depth), resetView | only cut maps onto a declared control (`piece.cut`); the rest are presentation |
