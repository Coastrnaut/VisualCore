# Research: A12-P00 (feature 088)

## 0. Verified facts (2026-11-15)

- `scripts/check_app_contract.py` verifies cited files, declared symbols (public when required), products, gap coverage
  and renders the Markdown view; contracts exist for A01–A11 under `docs/apps/<slug>/`.
- `scripts/check_experience_packages.py` forbids unregistered experience targets (`EXTRA_TARGET`).
- Constitution 2.8.0 commit `dbc35ba4`; specify commit `9315c27e`; reference pin `d93edd1`.
- Framework products with tests: `VisualCoreMath` (`OrbitCamera` with pitch and distance clamps, view, projection,
  `project`, `ray`; `CameraRail`; `Mat4`, `Vec3`), `VisualCoreScenes` (`Mesh`, `MeshBuilder`, `MeshGenerators`
  plane/cube/uvSphere, `MeshShapes` surface/revolution/extrusion/tube/bevelledBox, `MeshNormals`, `MeshBounds`,
  `MeshValidation` with `MeshBudget`, `MeshDigest`, `MeshCache`, `StreamingBudget`/`StreamingLevel`, gesture
  recognizers including `PinchRecognizer` and `DragRecognizer`), `VisualCoreSimulation` (`SeededRandom`,
  `FixedStepClock`, `FixedStepRunner`), `VisualCoreRendering` (`MeshRenderer` with Lambert lighting from one direction
  and an ambient fraction, `MeshFog`, `DepthMeshPass`, `ParticleRenderer`, render-target `readPixels`, `StillCapture`),
  `VisualCoreExperience` (`ExperienceStorage`, quality tiers), `VisualCoreDiagnostics` (`QualityGovernor`).
- No seeded noise or height-field generator, no instanced mesh drawing, no per-vertex colour or material model beyond
  one colour per draw, and no mesh level-of-detail selection exists in any framework product.
- Eleven experiences are registered (`Catalog/registrations.json`, A01–A11); A12 is absent.

## 1. Decisions

- **D1 Shell:** the one app is the shell (clarification 1); targets arrive in A12-P01. Alternative rejected: an empty
  registered experience (a placeholder).
- **D2 Matrix scope:** five brainstorm capabilities (3D scenes, camera and navigation, procedural meshes, lighting,
  materials and assets) and the six version 0.1 features, plus the cross-cutting rows (depth, picking, seeded
  determinism, geometry budget and detail tier, persistence, quality tiers and low power, accessibility and Reduce
  Motion, lifecycle and context loss, licenses); availability rule of clarification 2.
- **D3 Regression:** two chunks as for every VisualCore-adjacent gate (`reference-engine-xcframework
  reference-build-projectm-ios-sim reference-clean`; `reference-test-anglerendering-ios27
  reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`).
- **D4 Gap owners (clarification 5):** seeded noise and a height-field terrain generator with seam-free normals →
  `VisualCoreScenes` (A12-P01); constrained orbit and zoom, a lit multi-mesh scene with depth and separate picking
  geometry → VisualCore where generic, app-local otherwise (A12-P02); prop placement, light adjustment, the world
  document and thumbnails → app-local (A12-P03); the three environment packs → app-local (A12-P04); the detail tier
  over `StreamingBudget` and `MeshBudget` with memory and thermal limits → app-local (A12-P05). Alternative rejected:
  app-local noise (constitution A12 reuse first: seeded noise and height fields are generic).
