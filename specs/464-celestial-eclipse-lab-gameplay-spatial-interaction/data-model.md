# Data model: R02-G17-04

| Entity | Fields | Rules |
|---|---|---|
| `CelestialEclipseLabOrbit` | yaw, pitch (radians) | yaw ±60°, pitch −20° … +35°; authored (0, 0); presentation only |
| `CelestialEclipseLabSceneSnapshot` (edit) | + previewBody, previewOffset (nil when no drag), previewIntervals and previewMatched (the kernel's timeline of the current phases with the previewed body at the previewed offset) | presentation only; never in the digest |
| `CelestialEclipseLabPick` | body(index), dial, empty | the front-most body whose projected disc radius (r · s) grown by 8 points holds the touch; the dial is the projected strip-and-brackets box grown by 8 points |
| `CelestialEclipseLabGestureAction` | choosePlanet(body), showTick(tick), setPhase(body, offset), preview(body, offset), clearPreview, resetView, explain(reason) | setPhase and the choices map onto `orbit.phase [body, offset]`, `orbit.choose [body]` and `clock.show [tick]`; explain carries the fixed-body or finished-play reason |
| `CelestialEclipseLabGestureController` | state (idle, planetPress, planetDrag, dialDrag, emptyPress, orbiting, cancelled), orbit, touched pick, start/last points, pending offset, press time, last tap (time, place) | handle(event, viewSize, snapshot) — the snapshot carries the bodies, phases, shown tick, stage and geometry inputs |
| Panel pending offset | the chosen planet's pending offset (wrapping 0 … period − 1), previewed like a drag | phase − and + move it (no action spent); "Set phase" sends one `orbit.phase [body, offset]` when it differs from the current phase |
| Ghost material | code 17 `ghost`: a dashed outline disc at the previewed position | drawn only while a phase drag previews |
