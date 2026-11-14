# Research: A05-P01 (feature 040)

## 0. Verified APIs (2026-11-13)

- VisualCoreMath: `Vec2`, `Vec3`, `Mat4`, `Camera2D`, `OrbitCamera`; VisualCoreSimulation `SeededRandom`;
  VisualCoreParameters `Palette.builtIns` (6); VisualCoreScenes `Mesh` + R02-F05 (`MeshBuilder`, `Mesh.revolution`,
  `validate`, `digest`), `SceneNode(id:position:rotation:scale:z:primitive:color:)`, `Primitive.polygon`, `ViewMetrics`;
  VisualCoreRendering `PrimitiveRenderer.draw(_:camera:metrics:)`, `MeshRenderer`; VisualCoreExperience `ExperienceCore`
  (migrations, controls, prepare, update, apply, reset, writeDigest, outcome), `ExperienceOutcome(code:)`,
  `ScenarioManifest`; host `ExperiencePresenter`, `ExperienceShell`.
- The worked example is Particle Universe (`ParticleUniverse/Experience/Adapter/ParticleCore.swift`,
  `ParticleManifest.swift`, `ParticlePresenter.swift`, `ParticleExperience.swift`).

## 1. Decisions

- **D1 Symmetry API** (contracts/api.md): `PointGroup` (cyclic/dihedral, order 1…24) and `WallpaperLattice`
  (square p4m, hexagonal p6m); images and folding; deterministic order of images.
- **D2 Fundamental regions:** cyclic n — wedge 0 ≤ θ < 2π/n; dihedral n — 0 ≤ θ ≤ π/n; square p4m — triangle
  0 ≤ y ≤ x ≤ ½ of the unit cell; hexagonal p6m — the 30°-60°-90° triangle of the hexagonal cell.
- **D3 3D depth:** the host framebuffer has no depth buffer (A05-P00 G-MESHSCENE); copies are separated so that back-face
  culling alone draws them correctly in Phase 01; depth arrives in Phase 03.
- **D4 Composition cache:** rebuilt only when the state digest changes, outside the render callback's hot path.
- **D5 Candidate:** registered under `ExperienceRegistry.candidates`, hidden from people until X-A05.

## 2. Analysis record (`/speckit-analyze`, 2026-11-13)

- I1 (HIGH) fixed: the Core target depends on VisualCoreScenes (Mesh, R02-F05), stated in T-A05-107; the package edit
  precedes the first build. Re-run: 0 critical, 0 high.
