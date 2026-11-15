# Data model: A13-P02

| Entity | Fields | Rules |
|---|---|---|
| `MazeGestures` | arbiter, drag start cell and point, rotation reference angle | presentation only; reset on suspension |
| Glow constants | halo 0.30, core 0.08 cell; halo opacity 0.25 | the glow stays within 0.15 cell of a segment |
| `MazeState` | unchanged (schema 1) | gestures change it only through actions |
