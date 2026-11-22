# Data model: R02-G07-04

| Entity | Fields | Rules |
|---|---|---|
| `AmethystEscapeOrbit` | yaw, pitch (radians) | yaw ±40°, pitch 30° … 75°, authored (0, 50°); presentation only |
| `AmethystEscapePick` | pearl, shell(Int), empty | the pearl sphere first, else the innermost shell top plane hit inside its annulus, else the nearest within 22 points |
| `AmethystEscapeGestureController` | state (idle, shellDrag, pearlPress, orbiting, cancelled), picked shell, start point and time, travel, swept angle, candidate sectors, orbit, isolated shell, last tap time and place | at most ⌊S/2⌋ turns per gesture |
| `AmethystEscapeGestureAction` | turn(shell, step), advance, select(shell), isolate(shell or nil), resetView | turn and advance map onto declared controls; the rest are presentation |
| Preview snapshot | the drawn snapshot with one shell's offset turned by n sectors (and the pearl when in it) | never sent to the kernel |
