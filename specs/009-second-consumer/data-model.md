# Data model: Phase 8

- **Garden** (GardenKit): `capacity` 24, `minSpacing` 40, `harvestRadius` 30, `growthDuration` 4 s, `flowers: [Flower]`,
  `score`, `breeze: Vec2` (decays e^(−t/1 s)), `time`; `plant(at:) -> PlantResult (.planted(id) | .tooClose | .full)`,
  `tap(at:) -> TapResult (.harvested(id) | .notReady | .nothing)`, `drag(velocity:)`, `step(dt)`, counts.
- **Flower**: `id`, `position: Vec2`, `plantedAt`, `stage` (seed → growing → bloom → harvested), `growth` 0…1.
- Capacity rule: planting when 24 non-harvested flowers exist → `.full`; harvested slots are reused (oldest first).
- **Diagnostics label** (`garden.diagnostics`): `planted=<n> blooming=<n> score=<n> particles=<n>`.
- **DocumentedAPI report**: `used`, `undocumented` (names), exit code.
