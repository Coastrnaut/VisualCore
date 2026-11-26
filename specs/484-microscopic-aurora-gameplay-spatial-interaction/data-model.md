# Data model: R02-G19-04

| Entity | Fields | Rules |
|---|---|---|
| `MicroscopicAuroraViewOrbit` | yaw, pitch (radians) | yaw within ±60°, pitch −20° … +35°; authored = (0, 0); not saved |
| `MicroscopicAuroraPreview` | slot, target (a site or removal), previewed wells, previewed swim (positions, density, lit cells, coverage, coherence, failure), frozen | presentation only; never in the digest |
| `MicroscopicAuroraPick` | well(slot), site(index), scrubber, field, empty | the target drawn last wins |
| `MicroscopicAuroraGestureController` | state (idle, sitePress, wellPress, wellDrag, scrubberPress, scrubDrag, fieldPress, emptyPress, orbiting, cancelled), touched target, start and last points, press time, last tap time and place, orbit, freeze | thresholds: tap 10 pt and 0.5 s, drag 16 pt, double tap 0.35 s and 22 pt |
| `MicroscopicAuroraGestureAction` | place(slot, well), move(slot, well), remove(slot), showTick, preview, clearPreview, toggleFreeze, selectSlot, resetView, explain | kernel actions only while playing; `clock.show` in any stage |
| `MicroscopicAuroraMaterial` (additions) | 20 `ghostWell`, 21 `scrubber` | codes 0 … 19 unchanged; the ghost well draws the dragged well at its target, the scrubber the track and its mark |
