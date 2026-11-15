# Data Model: A10-P01

- **Field**: width 9, height 16 game units (y up); player line y 1.5; player x 0.5…8.5; spawn y 16.5; removal y < −1.
- **ContentItem** (catalog): `id` (kebab-case), `name`, `role` ∈ {player, hazard, orb}, `shape` ∈ {chevron, spike-ball
  (circle), bar (capsule), glow-orb (circle)}, `color`, `glowColor` (RGBA 0…1), `radiusRange` (min ≤ max, 0.1…1.0),
  `halfLengthRange` (bar only, 0.3…1.5), `value` (orb ≥ 1), `author`, `license` ∈ {"MIT"}.
- **PlayerState**: `x` 0.5…8.5, `velocity` |v| ≤ 9, `hitRadius` 0.4, `invulnerableSteps` 0…90.
- **FallingObject**: `id` (increasing), `contentId`, `kind` ∈ {hazard, orb}, `position` Vec2, `velocity` (0, −3…−5),
  `radius`, `halfLength` (0 for circles), `value`.
- **CollisionEvent**: `step`, `objectId`, `kind` ∈ {hit, pickup}.
- **GameRun** (schema 1): `step`, `score` 0…9,999,999, `lives` 0…3, `paused`, `over`, `steering` −1…1, `player`,
  `objects` (≤ 24), `nextObjectId`, `events` (≤ 256), `eventCount`.
- **ArcadeState** (snapshot schema 1): `run`, `random` (SeededRandom.State).
- **CatalogError**: `missing-license`, `unsupported-license`, `unknown-shape`, `invalid-number` with the item id.
