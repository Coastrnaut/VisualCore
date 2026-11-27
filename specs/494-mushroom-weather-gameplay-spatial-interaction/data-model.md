# Data model: R02-G20-04

| Entity | Fields | Rules |
|---|---|---|
| `MushroomWeatherViewOrbit` | yaw, pitch (radians) | yaw within ±60°, pitch −20° … +35°; authored = (0, 0); not saved |
| `MushroomWeatherPreview` | kind (pod: slot and target site or removal; moonlight: level), previewed arrangement, previewed run (fields, colony runs, growth, failure) | presentation only; never in the digest |
| `MushroomWeatherPick` | pod(slot), site(index), vent(index), moon, scrubber, floor, empty | the target drawn last wins |
| `MushroomWeatherGestureController` | state (idle, sitePress, podPress, podDrag, ventPress, moonPress, moonDrag, scrubberPress, scrubDrag, floorPress, emptyPress, orbiting, cancelled), touched target, start and last points, press time, last tap time and place, orbit | thresholds: tap 10 pt and 0.5 s, drag 16 pt, double tap 0.35 s and 22 pt, moon 40 pt per level |
| `MushroomWeatherGestureAction` | place(slot, cell), move(slot, cell), remove(slot), setVent(index, open), setMoonlight(level), showCycle, preview, clearPreview, selectSlot, resetView, explain | kernel actions only while playing; `clock.show` in any stage |
