# Data model: R02-G01-04

| Entity | Fields | Rules |
|---|---|---|
| `AuroraLoomHandleID` | ribbon 0 … 2, control (wave = anchor, phase = dial) | handle id = ribbon · 2 + control |
| `AuroraLoomHandles` | anchor rail x = +L/2 + 0.45, dial centre x = −L/2 − 0.45, dial radius 0.3, lanes | anchor y = H · (2w/15 − 1); dial knob angle = p · 22.5° |
| `AuroraLoomOrbit` | azimuthOffset (−40° … 40°), elevation (10° … 60°) | default (0°, 28°); presentation only |
| `AuroraLoomGestureState` | idle, dragging(handle, start step, candidate), orbiting, cancelled | see research R3 |
| `AuroraLoomGestureController` | tracker, state, selection (ribbon), orbit, preview | outputs at most one move per gesture |
