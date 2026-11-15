# Data Model: A10-P02

- **Lanes**: count 5; centre(i) = 0.9 + 1.8 i.
- **SpawnPattern**: `id` ∈ {rain, wall, zigzag, orb-trail}, `name`, `rule` (same set), `rowEvery` (wall 120),
  `author` "VisualCore project", `license` "MIT".
- **Difficulty(wave)**: `level` = min(wave − 1, 8); `fallSpeed` (3 + 0.2 L)…min(5, 3.6 + 0.2 L); `spawnGap`
  max(20, 40 − 2.5 L); `orbMultiplier` 1 + L / 2.
- **GameRun** (schema 2): Phase 01 fields + `wave` ≥ 1, `waveStep` 0…599, `patternId` (a table id), `freeLane` −1…4,
  `patternCursor` 0…7.
- **ArcadeState** (snapshot schema 2): `run` (schema 2), `random`.
- **Score**: + 1 per 60 steps of play; orb value × multiplier; cap 9,999,999.
