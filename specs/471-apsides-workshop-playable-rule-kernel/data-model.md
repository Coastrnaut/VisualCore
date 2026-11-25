# Data model: R02-G18-01

| Entity | Fields | Rules |
|---|---|---|
| `ApsidesWorkshopOrbit` | size a (8 … 48), eccentricity k (0 … 15), direction d (0 … 23) | valid when a(20 − k) ≥ 60 and a(20 + k) ≤ 1280 |
| `ApsidesWorkshopPoint` | x, y (Int, sky units, 256 per lattice unit) | within ±16,384 |
| `ApsidesWorkshopPlanet` | centre x, y (lattice −64 … 64), radius 1 … 8 | never overlaps the star (distance > radius + 2) |
| `ApsidesWorkshopTarget` | kind (sweep, periapsis, apoapsis), sector 0 … 7, low ≤ high (a sweep's share band in 0 … 1000; an apsis target's distance range in twentieths) | event tick: sweep first tick in the sector (T if none), periapsis 0, apoapsis T/2 |
| `ApsidesWorkshopLevel` | id, seed, difficulty 1 … 5, period T (even 16 … 96), planets (0 … 6), targets (1 … 6), starting orbit (valid), budget 1 … 24, tutorial, fingerprint | the starting orbit is valid and does not win; no two targets identical; schema 1; sorted-key JSON |
| `ApsidesWorkshopReport` | positions (T), shares (8), periapsis and apoapsis readings, largest residual, deviations per target, contact, first unmet target, outcome | exact; never decides by itself |
| `ApsidesWorkshopAction` | periapsis(k, d), size(a), play | tunings spend 1 action; play spends none and ends the level |
| `ApsidesWorkshopFailure` | contact(planet, tick), order(target, tick), share(target, tick, share), apsisSector(target, sector), apsisDistance(target, distance) | codes `contact`, `order`, `share`, `apsis-sector`, `apsis-distance` |
| `ApsidesWorkshopPlay` | stage, orbit, actions spent, report, failure, records, undo/redo stacks | records carry previous and next fingerprints |
| `ApsidesWorkshopRecord` | schema, level seed, index, kind (periapsis, size, play, undo, redo, begin, dismissTutorial, pause, resume), action, previous and next fingerprints | appended for every accepted action and event |
| `ApsidesWorkshopRules.Position` | orbit, actions spent | moves: every legal tuning; goal: the predicted play wins |
