# Data Model: A09-P01

- **SwimBounds**: `minX` 0.5, `maxX` 15.5, `minY` 1.5, `maxY` 8.5 (habitat units; finite, min < max, inside the 16 × 9 tank).
- **FishSpecies**: `id` (kebab-case), `name` (descriptive), `shape` ∈ {teardrop, slender}, `bodyColor`, `finColor`
  (RGBA 0…1), `length` 0.3…1.5 units, `cruiseSpeed` > 0, `maxSpeed` ≥ cruise, ≤ 4 units/s, `turnRate` rad/s > 0,
  `author`, `license` ∈ {"MIT"}.
- **PlantKind**: `id`, `name`, `shape` ∈ {ribbon, fan}, `color`, `height` 0.5…6 units, `author`, `license`.
- **StarterHabitat**: `id`, `name`, `waterColor`, `species` [(speciesId, count)], `plants` [(plantId, x)], `author`,
  `license`; total fish 1…24, plants 0…12.
- **FishAgent**: `speciesId`, `position` Vec2 (inside bounds), `velocity` Vec2 (|v| ≤ maxSpeed), `heading` rad,
  `animationPhase` 0…2π.
- **HabitatDocument** (schema 1): `habitatIndex`, `waterColor`, `bounds`, `plants` [PlantPlacement(kindId, x)],
  `fish` [FishAgent], `decor` [] (empty in this phase), `lighting` ∈ {0, 1, 2}.
- **AquariumState** (snapshot schema 1): `document`, `step`, `paused`, `random` (SeededRandom.State).
- **CatalogError**: `missing-license`, `unsupported-license`, `unknown-shape`, `unknown-reference`, `invalid-number`,
  `too-many-fish` with the item id.
