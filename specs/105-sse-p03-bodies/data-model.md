# Data model: A14-P03 (feature 105)

| Entity | Fields | Rules |
|---|---|---|
| `SphereNoise` | seed (UInt64), octaves 4, lacunarity 2, gain 0.5 | `value(at: Vec3) -> Double` in [0, 1]; deterministic; the same direction gives the same value |
| `SurfaceRecipe` | bodyID, seed (0xA14_0000 + index), base colours, style (`emissive`, `terrain`, `banded`), bands, thresholds | `colors(for: [Vec3]) -> [SurfaceColor]` (vertex positions, so the core needs no scene module; one per vertex, each channel 0…1); `digest` = stable hash of the colours |
| `RingRecord` | bodyID `saturn`, innerKm 74,500, outerKm 136,775, cassiniInnerKm 117,580, cassiniOuterKm 122,170 | inner < cassini inner < cassini outer < outer; each value has one source record (`ring-inner-radius`, `ring-outer-radius`, `cassini-division`) |
| `ScaleMode` | `enhanced` (0), `trueRelative` (1) | `scenePosition(_ au: Vec3)`, `drawnRadius(index:)`, `label`, near/far for a camera distance |
| `SolarState` (schema 3) | schema 2 fields + `scaleMode` 0…1 | migrates schema 2 (mode 0) and schema 1; damaged or newer refused |
| `Starfield` (Experience) | seed 0xA14_57A5, 400 unit directions, star size 0.004 × radius | drawn centred on the eye at radius 0.9 × far; directions identical on every run |
| `FocusFlight` (Experience) | from view (target, distance), to view, frame 0…30, reduceMotion | `view(at frame:)`; eye outside every clearance sphere at every frame |
