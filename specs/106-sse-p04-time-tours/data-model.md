# Data model: A14-P04 (feature 106)

| Entity | Fields | Rules |
|---|---|---|
| `SimClock` (core helpers) | rates [1, 7, 30, 365] days/s, labels, step 1/120 s | `advance(dayOffset:rateIndex:)` → new day or clamp with `end-of-range` |
| `Tour` | id, title, stops [`TourStop`] | ≤ 6 stops; `bundled`: "Inner planets" (0, 1, 2, 3, 4), "Giant planets" (5, 6, 7, 8) |
| `TourStop` | bodyIndex, holdSteps 600, caption | caption built from catalog values with units and the source title |
| `SolarState` (schema 4) | schema 3 + playing, rateIndex 0…3, stopReason ("" or "end-of-range"), tourIndex −1…1, tourStop, tourStep 0…599, tourPaused | migrates 3 (paused, rate 0, no tour), 2, 1; damaged or newer refused |
| `SavedView` (schema 1) | selection 0…8, dayOffset (in range), rateIndex 0…3, yawSteps, pitchDegrees 5 + 10k in 5…85, zoomSteps −1…12, scaleMode 0…1 | JSON sorted keys; `damaged`, `newer-version`, `out-of-range`, `oversized` (> 4,096 bytes) |
| `LabelLayout` (experience) | body, point (pt), box 90 × 20 pt | hidden behind camera or off canvas; no overlaps; focused body first |
| `AnnouncementLimiter` (experience) | minimum interval 10 s, injected clock | event announcements pass; periodic date at most every 10 s |
