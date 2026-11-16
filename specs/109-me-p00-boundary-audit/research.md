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

## 2. As found by the audit (2026-11-15)

- **Cylinder corrected:** clarification 5 expected a cylinder generator to be missing. `Mesh.tube(path:radius:sides:
  caps:closed:)` (`MeshShapes.swift`) with a two-point path and caps is a tested capped cylinder
  (`MeshShapeTests.straightCappedTubeAtThreeResolutions`), built directly between two atom centres, so row M22 is
  available and no new generator is needed; a named cylinder generator for `VisualCoreScenes` only if reuse calls for
  it (G-RENDER).
- **Instancing:** only `ParticleRenderer` draws instanced (`vcglDrawArraysInstanced`, divisor in the internal
  `DynamicVertexBuffer`); `MeshRenderer` and `DepthMeshPass` draw one item per call, so many atoms and bonds are
  batched app-locally (G-RENDER, A15-P02); instanced lit meshes are assessed there for `VisualCoreRendering`.
- **Picking:** `Ray3` ray–sphere casts, `Ray3.nearest` and `OrbitCamera.ray(ndc:aspect:)` exist; no ray–cylinder or
  ray–capsule cast; bond picking is not in version 0.1 (G-PICK).
- **Parsing:** no text-record parser exists in a framework product (`ShaderLibrary`'s line splitting is private and
  unbounded); the strict XYZ parser is app-local and a bounded line reader is assessed for VisualCore in A15-P01.
- **Persistence:** `DocumentStore`, `MigrationChain`, `NamedLibrary` and `ExperienceStorage` serve the library,
  recent molecules and settings (G-LIBRARY).
- **Import:** `fileImporter` appears only in the controls of A06–A08, for audio (G-IMPORT, app-local).
- **Lighting:** one directional Lambert light with ambient and no specular term; judged sufficient for readable atom
  and bond shading (row M04 available); a specular term would be an additive VisualCoreRendering change if a later
  phase needs it.
- **Inventory:** `python3 scripts/release_check.py --list` gives 128 lines.
- The contract (`docs/apps/molecular-explorer/visualcore-contract.json`) holds 23 rows (9 available, 14 requires
  adaptation, 0 upstream gap) and 11 app-local gaps (G-ELEMENTS, G-DOMAIN, G-PARSER in A15-P01; G-RENDER, G-CAMERA in
  A15-P02; G-PICK, G-DISPLAY, G-PANEL in A15-P03; G-LIBRARY in A15-P04; G-IMPORT, G-REVIEW in A15-P05); decision go.
