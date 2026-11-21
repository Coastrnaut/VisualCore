# Data model: R02-G02-04

| Entity | Fields | Rules |
|---|---|---|
| `LissajousLabyrinthSceneGeometry.stageBounds(level:)` | centre, radius R | holds every path of the level and every ball; independent of the dials |
| `LissajousLabyrinthHandles` | ringRadius 0.18 R, ringSpacing 0.45 R, ringOffset 1.35 R; one ring per dial | knob angle = value · 40° (frequencies 1 … 9) or value · 22.5° (phases 0 … 15); handle id = dial index 0 … 3 |
| `LissajousLabyrinthOrbit` | azimuthOffset (−40° … 40°), elevation (10° … 60°) | authored (0°, ≈ 21.5°); presentation only, never saved |
| `LissajousLabyrinthGesturePhase` | idle, turning(dial, start, candidate), orbiting, cancelled | see research R5 |
| `LissajousLabyrinthGestureController` | tracker, phase, selectedDial, orbit, accumulated angle | at most one action per gesture; only while playing |
| `LissajousLabyrinthPending` | values: [dial: Int] (only changed dials) | Apply order of research R7; cleared on any committed change, undo, redo, next level, restore |
