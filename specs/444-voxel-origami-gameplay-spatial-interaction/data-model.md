# Data model: R02-G15-04

| Entity | Fields | Rules |
|---|---|---|
| `VoxelOrigamiOrbit` | yaw, pitch (radians) | yaw ±60°, pitch −20° … +35°; authored (0, 0); presentation only |
| `VoxelOrigamiPick` | cube(index), empty | the front-most cube whose projected eight-corner outline, grown by 8 points, holds the touch; cube 0 is the root |
| `VoxelOrigamiTurnPrediction` | hinge, plus and minus screen motions of the tracked cube, the swinging cube farthest from the hinge line, lowest index on ties (view points) | nil when the hinge swings nothing or for the root |
| `VoxelOrigamiGestureAction` | chooseHinge(h), pendingTurn(hinge, step), clearPending, turn(hinge, step), resetView, explain(reason) | turn and chooseHinge map onto `hinge.turn [h, step]` and `hinge.choose [h]`; explain carries the root, idle-hinge or finished-play reason |
| `VoxelOrigamiGestureController` | state, orbit, touched pick, start/last points, pending step, press time, last tap (time, place, pick) | handle(event, viewSize, snapshot) — the snapshot carries the cubes, the turns, the turnable hinges, the stage and the actions left |
