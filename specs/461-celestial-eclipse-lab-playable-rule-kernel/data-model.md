# Data model: R02-G17-01

| Entity | Fields | Rules |
|---|---|---|
| `CelestialEclipseLabVector` | x, y, z (Int) | lattice positions, each coordinate −32 … 32 |
| `CelestialEclipseLabBody` | orbit (4 … 24 vectors), radius 1 … 8, fixed | position(at tick, phase) = orbit[(tick + phase) mod period] |
| `CelestialEclipseLabTarget` | front, back (body indices, different), open ≤ close | 0 ≤ open ≤ close ≤ horizon − 1 |
| `CelestialEclipseLabLevel` | id, seed, difficulty 1 … 5, bodies (2 … 6), horizon 8 … 96, target (1 … 6), phases (one per body, 0 … period − 1), budget 1 … 24, tutorial, fingerprint | at least one movable body; every pair depth-ordered; the starting phases do not win; schema 1; sorted-key JSON |
| `CelestialEclipseLabInterval` | front, back, first, last, class (partial, total, annular) | exact |
| `CelestialEclipseLabTimeline` | intervals (by first tick, then front, back), matched, offending, outcome (wins or failure) | exact; never decides by itself |
| `CelestialEclipseLabAction` | phase(body, offset), run | phase spends 1 action; run spends none and ends the level |
| `CelestialEclipseLabFailure` | unwanted(front, back, tick), window(front, back, tick, open, close), horizon(front, back, open, close) | codes `unwanted`, `window`, `horizon` |
| `CelestialEclipseLabPlay` | stage, phases, actions spent, timeline, failure, records, undo/redo stacks | records carry previous and next fingerprints |
| `CelestialEclipseLabRecord` | schema, level seed, index, kind (phase, run, undo, redo, begin, dismissTutorial, pause, resume), action, previous and next fingerprints | appended for every accepted action and event |
| `CelestialEclipseLabRules.Position` | phases, actions spent | moves: every legal phase change; goal: the predicted run wins |
