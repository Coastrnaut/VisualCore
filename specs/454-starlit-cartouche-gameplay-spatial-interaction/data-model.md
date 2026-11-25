# Data model: R02-G16-04

| Entity | Fields | Rules |
|---|---|---|
| `StarlitCartoucheOrbit` | yaw, pitch (radians) | yaw ±60°, pitch −20° … +35°; authored (0, 0); presentation only |
| `StarlitCartoucheSceneSnapshot` (edit) | + launchBeat (beat + chosen wait), launchPositions (every star at the launch beat) | presentation only; never in the digest; at wait 0 equal to the current positions |
| `StarlitCartouchePick` | star(index), ship, slider, empty | the front-most star whose projected ring radius (0.098) grown by 8 points holds the touch; the ship's star is `ship`; the slider is the projected wait-pip box grown by 8 points |
| `StarlitCartoucheGestureAction` | chooseDestination(star), chooseWait(wait), fly(star, wait), preview(star), clearPreview, resetView, explain(reason) | fly and the choices map onto `route.fly [star, wait]` and `route.choose [star, wait]`; explain carries the ship, no-corridor or finished-play reason |
| `StarlitCartoucheGestureController` | state (idle, starPress, shipPress, shipDrag, sliderDrag, emptyPress, orbiting, cancelled), orbit, touched pick, start/last points, pending destination, press time, last tap (time, place, pick) | handle(event, viewSize, snapshot) — the snapshot carries the stars, the ship's star, the choice, the stage and the corridors |
| Preview material | code 22 `preview`: dashed sapphire ribbon 0.03 wide, a_normal.x distance along | drawn only while playing and when a corridor joins the ship's star and the destination |
