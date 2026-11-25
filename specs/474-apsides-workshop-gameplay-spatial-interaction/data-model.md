# Data model: R02-G18-04

| Entity | Fields | Rules |
|---|---|---|
| `ApsidesWorkshopViewOrbit` | yaw, pitch (radians) | yaw ±60°, pitch −20° … +35°; authored (0, 0); presentation only |
| `ApsidesWorkshopSceneSnapshot` (edit) | + previewOrbit (nil when no preview), previewPositions (its kernel positions), previewGauges (its readings, deviations and met flags) | presentation only; never in the digest; only for a valid pending orbit |
| `ApsidesWorkshopPick` | orbiter, sizeHandle, knob, loop, empty | the handle drawn last whose projected disc or marker (grown by 8 or 12 points) holds the touch; the loop within 10 points of its projected chords |
| `ApsidesWorkshopGestureAction` | tunePeriapsis(k, d), tuneSize(a), showTick(tick), preview(orbit), clearPreview, resetView, explain(reason) | the tunings and the tick map onto `orbit.periapsis [k, d]`, `orbit.size [a]` and `clock.show [tick]`; explain carries the invalid-orbit, tap-on-handle or finished-play reason |
| `ApsidesWorkshopGestureController` | state (idle, knobPress, knobDrag, handlePress, handleDrag, orbiterPress, crankDrag, emptyPress, orbiting, cancelled), orbit, touched pick, start/last points, pending orbit, press time, last tap (time, place) | handle(event, viewSize, snapshot) — the snapshot carries the orbit, positions, shown tick, stage and geometry inputs |
| Panel pending orbit | pending eccentricity, direction and size (direction wraps 0 … 23; the others clamp to their ranges), previewed like a drag | − and + move it (no action spent); "Set periapsis" sends one `orbit.periapsis [k, d]`, "Set size" one `orbit.size [a]`, when the pending value differs and the orbit is valid |
| Ghost material | code 22 `ghostPreview`: a dashed loop and outlined apsis markers at the previewed orbit | drawn only while a valid preview exists |
