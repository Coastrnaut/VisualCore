# Data model: R02-G10-04

| Entity | Fields | Rules |
|---|---|---|
| `BackwardsAuroraOrbit` | yaw, pitch (radians) | yaw ±35°, pitch −15° … +20°; authored (0, 0); presentation only |
| `BackwardsAuroraPick` | end(start/end), band(k), sample(k), empty | ends first (22 points), then band, then sample column |
| `BackwardsAuroraFreezePreview` | start, end, samples, kinks, tear, matched, text | samples = kernel reversal; presentation only |
| `BackwardsAuroraSceneSnapshot.preview` | would-be samples (empty when none) | drawn as a pale dashed ribbon (material 13) |
| `BackwardsAuroraGestureAction` | setStart(k), setEnd(k), reverse(start, end), resetView | only reverse maps onto `wave.reverse` |
| `BackwardsAuroraGestureController` | state, orbit, preview, touched pick, start/last points, press time, last tap | handle(event, viewSize, snapshot, play, section) |
