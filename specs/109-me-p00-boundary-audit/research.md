# Research: A15-P00 (feature 109)

## 0. Verified facts (2026-11-15)

- `scripts/check_app_contract.py` verifies cited files, declared symbols (public when required), products, gap coverage
  and renders the Markdown view; contracts exist for A01–A14 under `docs/apps/<slug>/`.
- `scripts/check_experience_packages.py` forbids unregistered experience targets (`EXTRA_TARGET`).
- Constitution 2.11.0 commit `aaeeb3a7`; specify commit `fc60a33d`; reference pin `d93edd1`.
- Framework products with tests (clarification facts): `VisualCoreMath` (`Vec3`, `Mat4`, `Quat`, `OrbitCamera`,
  `OrbitBounds`, `FramingFlight`, `Ray3`, `RayHit3`, ray–sphere, box and triangle casts, `NumericHygiene`),
  `VisualCoreScenes` (`MeshGenerators` `plane`, `cube`, `uvSphere`; `MeshBuilder`; `MeshBudget`; gesture recognizers
  and `GestureArbiter`), `VisualCoreRendering` (`MeshRenderer` with Lambert lighting and `MeshFog`, `DepthMeshPass`,
  `PrimitiveRenderer`, `RenderTarget`, `ResourceRegistry`; instanced drawing inside `ParticleRenderer` only),
  `VisualCoreExperience` (`ExperienceStorage`, `ScenarioManifest`), `VisualCorePersistence` (`DocumentStore`,
  `DocumentEnvelope`, `MigrationChain`).
- No cylinder or capsule mesh generator, no instanced lit-mesh drawing, no ray–cylinder test, no element catalog and
  no text-record parser exist in any framework product.
- Fourteen experiences are registered (`Catalog/registrations.json`, A01–A14); A15 is absent.

## 1. Decisions

- **D1 Shell:** the one app is the shell (clarification 1); targets arrive in A15-P01. Alternative rejected: an empty
  registered experience (a placeholder).
- **D2 Matrix scope:** five brainstorm capabilities (instanced geometry, materials, camera controls, lighting,
  structured scientific data visualization) and the six version 0.1 features, plus the cross-cutting rows (strict
  bounded parsing, inferred-bond labelling, determinism, persistence with migration, quality tiers, accessibility with
  Reduce Motion, lifecycle and context loss, data provenance and licenses, file import without permissions, truthful
  claims); availability rule of clarification 2.
- **D3 Regression:** two chunks as for every VisualCore-adjacent gate.
- **D4 Gap owners (clarification 5):** element catalog, domain, XYZ parser and bond inference → app-local (A15-P01);
  cylinder mesh → `VisualCoreScenes` if reusable, atoms and bonds batched over `MeshRenderer` (instanced lit meshes
  assessed for `VisualCoreRendering`), camera framing → app-local (A15-P02); picking, display modes, labels and the
  metadata panel → app-local (A15-P03); curated library, recent molecules and settings → app-local (A15-P04); import
  through the document picker, fuzz and data review → app-local (A15-P05).
