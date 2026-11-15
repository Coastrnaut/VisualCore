# Research: A14-P00 (feature 102)

## 0. Verified facts (2026-11-15)

- `scripts/check_app_contract.py` verifies cited files, declared symbols (public when required), products, gap coverage
  and renders the Markdown view; contracts exist for A01–A13 under `docs/apps/<slug>/`.
- `scripts/check_experience_packages.py` forbids unregistered experience targets (`EXTRA_TARGET`).
- Constitution 2.10.0 commit `462c0a1f`; specify commit `9335c07c`; reference pin `d93edd1`.
- Framework products with tests (clarification facts): `VisualCoreMath` (`Vec3`, `Mat4`, `Quat`, `OrbitCamera`,
  `CameraRail`, `FramingFlight`, `TourTimeline`, `OriginRebase`, `PrecisionAdvisor`, `Ray3`, ray–sphere casts),
  `VisualCoreScenes` (`MeshGenerators.uvSphere`, `MeshBuilder`, `GradientNoise2D`, `FractalNoise2D`, gesture
  recognizers, `GestureArbiter`), `VisualCoreRendering` (`MeshRenderer` with Lambert lighting and `MeshFog`,
  `DepthMeshPass`, `RenderTarget`, `PrimitiveRenderer`, `ResourceRegistry`), `VisualCoreSimulation` (`SceneClock`,
  `Timeline`, `FixedStepClock`, `FixedStepRunner`, accessibility planners), `VisualCoreExperience`
  (`ExperienceStorage`, `ScenarioManifest`), `VisualCorePersistence` (`DocumentStore`, `MigrationChain`).
- No orbit propagation, no simulated calendar date with a rate, no astronomical unit conversion and no body catalog
  exist in any framework product.
- Thirteen experiences are registered (`Catalog/registrations.json`, A01–A13); A14 is absent.

## 1. Decisions

- **D1 Shell:** the one app is the shell (clarification 1); targets arrive in A14-P01. Alternative rejected: an empty
  registered experience (a placeholder).
- **D2 Matrix scope:** five brainstorm capabilities (3D scenes, camera controls, materials and lighting, animation,
  time-based simulation) and the six version 0.1 features, plus the cross-cutting rows (double precision and
  camera-relative positions, determinism and replay, bounded content and date range, persistence, quality tiers and low
  power, accessibility with Reduce Motion, lifecycle and context loss, data provenance and licenses, truthful scale
  labelling, labelled simulated date and time zone); availability rule of clarification 2.
- **D3 Regression:** two chunks as for every VisualCore-adjacent gate.
- **D4 Gap owners (clarification 5):** catalog, units and citations → app-local (A14-P01); approximate Kepler
  propagation → `VisualCoreMath` if reusable (A14-P02); rendering, focus and scale modes → app-local (A14-P03); clock,
  tours, fact cards and saved state → app-local, scaled-date clock assessed for `VisualCoreSimulation` (A14-P04);
  provenance and tolerance review → app-local (A14-P05).
