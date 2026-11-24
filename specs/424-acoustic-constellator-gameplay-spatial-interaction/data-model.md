# Data model: R02-G13-04

| Entity | Fields | Rules |
|---|---|---|
| `AcousticConstellatorOrbit` | yaw, pitch (radians) | yaw ±35°, pitch −15° … +20°; authored (0, 0); presentation only |
| `AcousticConstellatorPick` | coherence(bar), hold(pip), star(index), link(index), empty | gauges first (coherence before hold), then the nearest star, then the nearest link, each within 22 points |
| `AcousticConstellatorGestureAction` | choose(star), choosePair(a, b), preview(from, target?, point), link(a, b), unlink(a, b), nudge(star), listen, resetView | link, unlink, nudge and listen map onto `link.add`, `link.remove`, `star.nudge [s, 1]` and `constellation.listen` |
| `AcousticConstellatorGestureController` | state, orbit, touched pick, start/last points, press time, drag target, last tap | handle(event, viewSize, snapshot) — the snapshot carries links, fixed links and stage |
