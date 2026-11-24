# Data model: R02-G14-04

| Entity | Fields | Rules |
|---|---|---|
| `MoonlitMechanismOrbit` | yaw, pitch (radians) | yaw ±25°, pitch −10° … +15°; authored (0, 0); presentation only |
| `MoonlitMechanismPick` | lamp, ladder, card(index), gear(index), empty | lamp and ladder first (22 points), then a card (inside its rectangle or the nearest centre within 22 points), then the front-most gear (outline circle 3.75 s + 8 points) |
| `MoonlitMechanismGestureAction` | chooseGear(g), pendingTurn(gear, teeth), turn(step, count), pendingLamp(steps), lampStep(step, count), reseat(g), showFrame(k), run, resetView | turn, lampStep, reseat, showFrame and run map onto `handle.turn [s]` × count, `lamp.step [s]` × count, `gear.reseat [g, 1]`, `frame.show [k]` and `machine.run` |
| `MoonlitMechanismGestureController` | state, orbit, touched pick, start/last points, swept angle, press time, last tap (time, place, pick) | handle(event, viewSize, snapshot) — the snapshot carries the gears, the stage and the actions left |
