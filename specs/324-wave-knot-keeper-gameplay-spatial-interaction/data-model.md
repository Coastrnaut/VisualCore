# Data model: R02-G03-04

| Entity | Fields | Rules |
|---|---|---|
| `WaveKnotKeeperOrbit` | yaw (−40° … 40°), pitch (5° … 60°, authored 20°) | presentation only; reset returns to authored |
| Handle pick | point index, screen position, depth | touch radius ≥ 22 pt; nearest to the eye wins |
| Drag candidate | point, direction 0 … 5 or none | best-aligned projected step; snap ≥ max(6 pt, half the projected step) |
| `WaveKnotKeeperGestureController` state | idle, dragging(point, start), orbiting, cancelled | ≤ 1 action per gesture; moves only while playing |
