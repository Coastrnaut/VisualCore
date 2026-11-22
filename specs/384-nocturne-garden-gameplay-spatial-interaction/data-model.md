# Data model: R02-G09-04

| Entity | Fields | Rules |
|---|---|---|
| `NocturneGardenOrbit` | yaw, pitch (radians) | yaw ±35°, pitch 0° … 30° down; authored 8°; presentation only |
| `NocturneGardenPick` | lantern, bloom(Int), cell(Int), outside, empty | lantern → blooms → bed; 22-point minimum target |
| `NocturneGardenDragPreview` | bloom, anchor (column, row), cells, shared, either, leak, removes | cells = kernel union with the moved bloom; presentation only |
| `NocturneGardenGestureAction` | plant(kind, column, row, size), move(bloom, column, row), remove(bloom), resize(bloom, size), sun(elevation), choose(bloom), resetView | all but choose and resetView map onto declared controls |
| `NocturneGardenGestureController` | state (idle, bedPress, bloomPress, bloomDrag, lanternDrag, pinch, orbiting, cancelled), orbit, preview, touch-down data, last tap | only event timestamps are read |
| Snapshot `preview` | sorted cells or empty | drawn as a pale dashed outline (material code 12) |
