# Data Model: A05-P01

- **PointGroup**: `.cyclic(n)` | `.dihedral(n)`, n ∈ 1…24; `imageCount` = n or 2n.
- **WallpaperLattice**: `.square` (p4m, 8 images per cell) | `.hexagonal` (p6m, 12 images per cell).
- **GeometryPreset** (Codable, schema 1): `kind` ∈ {squareTiling, hexTiling, kaleidoscope, solid}; `order` Int 1…24
  (tilings use their lattice's order and ignore it); `repeats` Int 1…12; `scale` Double 0.25…4 (finite); `palette` Int
  0…5; `seed` UInt64; `schemaVersion` = 1. Curated presets: 4 (one per kind).
- **Motif**: 3–7 points, convex, inside the group's fundamental region, from `SeededRandom(seed)`.
- **Composition2D**: polygons (points, colour index), count ≤ 2,048. **Solid**: one closed `Mesh` of `order` revolved
  copies at radius 1.5, within `MeshBudget.default`.
- **GeometryCore** (ExperienceCore, Codable): `preset`, `seed`; actions `preset.select [index]`, `symmetry.order [n]`,
  `repeats.set [n]`, `scale.set [x]`, `palette.set [i]`, `reseed []`; outcome `composition-built`.
