# Data model: R02-G12-04

| Entity | Fields | Rules |
|---|---|---|
| `HarmonicBridgesOrbit` | yaw, pitch (radians) | yaw ±35°, pitch −15° … +20°; authored (0, 0); presentation only |
| `HarmonicBridgesPick` | pip(step), goal, string(index), empty | pips first, then the goal, then the nearest string, each within 22 points |
| `HarmonicBridgesGestureAction` | choose(string, peg), preview(string, peg), tune(string, peg), test, resetView | tune and test map onto `string.tune` and `crossing.test` |
| `HarmonicBridgesGestureController` | state, orbit, touched pick, start/last points, press time, previewed peg, last tap | handle(event, viewSize, snapshot) — the snapshot carries pegs, locks and stage |
