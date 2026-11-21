# Data model: R02-G04-04

| Entity | Fields | Rules |
|---|---|---|
| `HueCompassOrbit` | yaw (−40° … 40°), tilt (15° … 60°, authored 35°) | presentation only; clamped; reset to authored |
| `HueCompassDial` | projected centre, hub radius (≥ 30 pt), dead zone 20 pt | pure functions of camera and view size |
| `HueCompassGestureController` | state (idle, swiping, orbiting, cancelled), start bearing, accumulated angle, preview steps, last tap time | at most one action per gesture; nothing while not playing |
| Action | `compass.turn [steps −47 … 48, not 0]` or `compass.probe` | sent through the adapter |
