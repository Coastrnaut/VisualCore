# Implementation Plan: R02-G21-03 — Binary Gardens: procedural materials and hero renderer

**Branch**: `503-binary-gardens-procedural-materials-and-hero-renderer` (spec directory only; work on `main`) |
**Date**: 2026-11-27 | **Spec**: [spec.md](spec.md)

## Summary

Add Binary Gardens' hero renderer on the pattern of Mushroom Weather's (feature 493, itself modelled on feature 483):
an immutable scene snapshot (the level's ring radii, luminosity levels, maximum tilt, phase step and worlds with their
four flux bounds, window, bloom band and lethal tolerance; the arrangement; from the kernel's report the star and world
positions at ticks 1 … 48, every world's flux and per-star shares, bands, longest lethal run, window and its start,
integral and bloom result; the shown tick, the fit scale k = 0.95 / R, stage, failure, actions left, budget, level
number, presentation time); the system geometry (the still space backdrop with a hashed starfield, the tilt dial, the
dashed star rings and the world orbits as 48-gons through the kernel's own cosine-table points, the trails of the 8 or 4
ticks before the shown tick at the richer tiers, the cube-sphere worlds with their pips, the star discs with white-hot
cores, coronas at the richer tiers and luminosity pips, the gauge rows with 48 tick cells, guide lines, window bracket,
tick marker and bloom meter, and the actions bars) mapped by k · (x, y, z) / 2²⁰ about the barycentre, a fixed authored
camera, painter's order with depth testing off and no face culling (bodies sorted back to front by eye distance), and a
CPU reference of the projection and palette; GLSL ES 3.00 system and glow programs (each world lit by both stars in
their own colours with a brightened sunrise band along each terminator, shader-only seasonal banding by the world's band
at the shown tick: frost caps, scorched belts, procedural flowers); three tiers (cube-sphere tessellation, corona rays,
trails, pollen motes, glow); the adapter `BinaryGardensExperienceCore` (star ring, phase and luminosity, tilt, run,
undo, redo, next level, show tick; digest = level number + play fingerprint; snapshot schema 1); the iOS experience
(presenter with tier log, fallback, frame probes, Reduce Motion and Reduce Flashing, scene, minimal control panel); the
scenario manifest with 80 acceptance scenarios; and the candidate registration in the one app. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00 (strings in Swift sources). **Primary dependencies**: VisualCoreSimulation,
VisualCoreMath, VisualCoreScenes (`MeshBuilder`, `Mesh`), VisualCoreExperience, VisualCoreDiagnostics,
VisualCorePersistence in the Core; VisualCoreRendering (`ShaderMeshRenderer`, `MeshRenderer`),
VisualCoreExperienceHost and VisualCoreUI in the Experience (as `MushroomWeatherCore` and `MushroomWeatherExperience`
link them in `Packages/ExperiencesRound02/Package.swift`). No Objective-C++ bridge; no second renderer; no new
VisualCore API (the cube-sphere is generated in the game's Core, since the shared packages have only a UV sphere, so no
API baseline changes). **Package**: the `BinaryGardensCore` target gains VisualCoreScenes, VisualCoreExperience,
VisualCoreDiagnostics and VisualCorePersistence (as `MushroomWeatherCore` did at 493); `BinaryGardensCoreTests` gains
VisualCoreScenes, VisualCoreExperience and VisualCoreDiagnostics; the package gains `BinaryGardensExperience` (path
`BinaryGardens/Experience`), `BinaryGardensExperienceTests` (path `BinaryGardens/ExperienceTests`) and the
`BinaryGardensExperience` library product; rendering dependencies carry `condition: .when(platforms: [.iOS])` and
experience sources sit in `#if os(iOS)`, so the Cores still run on the host. The kernel scans of
`BinaryGardensInvariantTests` (no clock, floating point or run-time trigonometry; allowed imports) read a fixed list of
the kernel's files (feature 501's five and feature 502's five), as 493 did for Mushroom Weather, so the presentation
sources (snapshot, shaders with `sin(`/`cos(`, geometry, adapter with `clock.show`, scenarios) stay outside them.
**App**: `project.yml` adds the `BinaryGardensCore` and `BinaryGardensExperience` products; the registry registers the
candidate (`ExperienceRegistry.candidates`, opening seed 0); `Catalog/registrations.json` gains the entry (content facts:
100 levels and the catalog digest pinned at R02-G21-02); `build_catalog.py` regenerates `Catalog/experiences.json` and
the VisualCore test fixtures; `RealCatalogTests` lists the new registration; `AppModelTests` switches its synthetic
unregistered candidate to `r02-g22.mycelium-architect`; `scripts/test_scripts.py` lists the two products;
`xcodegen generate` after the `project.yml` change. CI's round02 host filter already names `BinaryGardens`; no workflow
change. **Seeds**: level (seed mod 100) + 1; tests use seed 2_503 and the catalog's levels 1, 21, 41, 61, 81.
**Exact to float**: the snapshot keeps the kernel's integer positions, fluxes, shares, bands, windows and integrals;
drawn positions are k · (kernel point) / 2²⁰ at the shown tick; orbit vertices are the table points C[i]/1024, S[i]/1024
(tilted by C[τ]/1024, S[τ]/1024), so every body is exactly a vertex of its orbit; lighting reads each star's share over
64 000 and the band at the shown tick; cell heights are 0.01 + 0.06 · min(1, F/λ_hi); trails, coronas and motes are
decoration only; no rule is evaluated on Doubles. **Testing**: host `swift test --package-path
Packages/ExperiencesRound02 --filter BinaryGardens`; simulator `xcodebuild_package.py … --destination sim-27.2 --action
test --only-testing BinaryGardensExperienceTests`; the app unit tests; regression; script tests alone; audits wait for
devices. **Performance**: at most 5 worlds (catalog at most 3) of 6 · 8² quads (768 triangles) each, 2 star discs with
12 rays, 8 rings of 48 dashes, 5 orbits of 48 segments, trails of 8 ticks × 7 bodies, 8 motes per comfortable world, 5
gauge rows of 48 cells with brackets and meters, 24 bars, at most 7 tilt pips: under 12,000 triangles plus two glow
shells; geometry is rebuilt only when the arrangement, the shown tick, the stage, the failure, the actions left, the tier,
the aspect or the fallback change; the coronas and motes move by a uniform time only. Device budgets are `{device}`
tasks after ImplementationLock-100. **Shader limits**: at most 16 vec4 uniforms per program (system: `u_mvp`, `u_time`,
`u_motion`, `u_won`, `u_star1`, `u_star2` = 9 slots; glow: `u_mvp`, `u_glowGain`, `u_glowLimit`, `u_won` = 7); no
texture samplers; only constant-bounded loops; the starfield and flowers come from a fixed hash. **Constraints**:
additive; denylisted names (ProjectM, PresetLibrary, MilkDrop …) avoided; no `import MetalKit` text in any file
(compliance scan); scenarios only under `#if DEBUG || VISUALCORE_AUTOMATION`; the presenter declares frame probes
(round-two X gate rule) and quality levels equal to the Core's `qualityTiers` (X gate rule); snapshot schema 1, so no
registered schema example. **Prerequisite**: R02-G21-02 recorded (its certified catalog, witnesses' `skipped` and
pinned digest feed the adapter's candidate table and the registration).

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — existing OpenGL ES → ANGLE → Metal path and `ShaderMeshRenderer`; fallback through the shared `MeshRenderer`; no second renderer. |
| II App-neutral API | PASS — game code in the experience package; VisualCore public API unchanged (no API baseline update needed). |
| II-a Preserve the reference | PASS — the seven-step ProjectM reference regression runs in two chunks (`reference-1`, `reference-2`); no ProjectM type enters the game. |
| III GPU lifecycle and threads | PASS — GL objects owned by the scene on the main actor; released on a memory warning and rebuilt on the next frame. |
| IV Host-testable, test-first | PASS — adapter, snapshot, geometry, shader CPU twins and CPU reference in the Core with host tests; GL code tested on the simulator. |
| V Implementation before devices | PASS — no device run; frame-time budgets are `{device}` tasks after ImplementationLock-100. |
| VI Evidence over assertion | PASS — every task's check recorded with `migration_ledger.py run-check`; simulator frames are not device evidence. |
| VII Native, accessible UI | PASS — labelled controls; no information by hue alone (shape twins); Reduce Motion and Reduce Flashing honoured; full accessibility at R02-G21-06. |
| VIII Public APIs, privacy, truthful capabilities | PASS — public Apple APIs only; no network, telemetry or permissions; no physical-accuracy claim. |
| IX Bounded input | PASS — snapshot values bounded; actions validated by declared controls, the adapter (`r02-g21.not-whole`, `r02-g21.tick`) and the kernel; restore refuses damaged payloads. |
| X Licensing and provenance | PASS — original shaders and geometry; palette from the project's archived design (warm vermilion, ice blue, mint world). |
| XI One app and stable identity | PASS — candidate `r02-g21.binary-gardens` inside the one app; no app target, bundle id or scheme; unavailable until X-R02-G21. |
| XII One purchase, no advertising | PASS — free tier under the shared purchase controller; no store or ad code. |
| XIII Code-driven visuals | PASS — generated meshes (cube-spheres, 48-gons, quads) and GLSL only; no image assets. |

Post-design re-check: PASS (no violation; Complexity Tracking empty).

## Project Structure

### Documentation (this feature)

```text
specs/503-binary-gardens-procedural-materials-and-hero-renderer/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, contracts/api.md
├── checklists/
└── tasks.md            (/speckit-tasks)
```

### Source code (repository root)

```text
Packages/ExperiencesRound02/Package.swift                                                  edit (lead)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensSceneSnapshot.swift            new  snapshot, palette, tiers (lead)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensShaders.swift                  new  GLSL sources, materials, CPU twins (agent A)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensSceneGeometry.swift            new  fit, cube-sphere, geometry, camera, CPU reference (agent B)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensExperienceCore.swift           new  adapter (agent C)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensScenarios.swift                new  scenario manifest source (lead)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensInvariantTests.swift      edit kernel scans read the kernel files only (lead)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/{BinaryGardensSceneSnapshotTests (lead),
  BinaryGardensShaderSourceTests (A), BinaryGardensSceneGeometryTests (B), BinaryGardensExperienceCoreTests (C),
  BinaryGardensRendererPurityTests (C), BinaryGardensScenariosTests (lead)}.swift          new
Packages/ExperiencesRound02/BinaryGardens/Experience/{BinaryGardensExperience, BinaryGardensPresenter,
  BinaryGardensSystemScene, BinaryGardensControls}.swift                                    new (lead)
Packages/ExperiencesRound02/BinaryGardens/ExperienceTests/{BinaryGardensTestSupport, BinaryGardensRenderTests,
  BinaryGardensTierTests, BinaryGardensFallbackTests, BinaryGardensExperienceIdentityTests}.swift   new (agent D)
Packages/ExperiencesRound02/BinaryGardens/scenario-manifest.json                           new (lead; generated)
Catalog/registrations.json, Catalog/experiences.json (build_catalog.py),
  Packages/VisualCore/Tests/VisualCoreExperienceTests/Fixtures/Catalog/{registrations,experiences}.json (build_catalog.py),
  Packages/VisualCore/Tests/VisualCoreExperienceTests/RealCatalogTests.swift,
  Apps/VisualCore/App/ExperienceRegistry.swift, Apps/VisualCore/Tests/Unit/AppModelTests.swift, project.yml,
  scripts/test_scripts.py                                                                   edit (lead)
docs/architecture/binary-gardens.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md, README.md   edit (lead)
```

**Structure Decision**: the experience module `Packages/ExperiencesRound02/BinaryGardens` of ADR-0009 (the source's
`Apps/BinaryGardens` becomes the experience target `BinaryGardensExperience`; `Packages/GameModules/BinaryGardensCore`
is the existing `BinaryGardensCore`). Presentation logic that is pure (snapshot, fit, cube-sphere, orbits, camera,
projection, palette, shader sources and CPU twins, adapter, scenarios) lives in the Core and is host-tested; only the GL
scene, presenter and controls live in the iOS-only Experience target. The scene file is named
`BinaryGardensSystemScene` (the spec's "system geometry"; `BinaryGardensSky` is the kernel's name).

**Dependency graph**: BinaryGardensCore kernel (R02-G21-01) and catalog (R02-G21-02) → snapshot → {shaders, geometry,
adapter} → scenarios → Experience (presenter, scene, controls) → app registry. **CI checks**: the host package job (the
round02 host filter already names BinaryGardens), the round-two simulator suite, the catalog and registration checks of
`build_catalog.py --check`, `check_experience_packages.py` and `test_scripts.py`. **Migration**: none (snapshot schema 1
is new; the kernel's stored forms are untouched). **Rollback**: revert the commits; the catalog entry returns to its
pre-registration form (`available: false`, empty palette, capabilities, tiers and content), the registry and
`project.yml` lose the candidate, and the Core kernel and catalog of R02-G21-01/02 are untouched.

## Parallel work

Lead: package, invariant-scan file list and snapshot first; then agents A (shader sources and CPU twins), B (geometry,
cube-sphere, camera, CPU reference) and C (adapter and purity) in parallel, each modelled on Mushroom Weather's files as
recorded at R02-G20-03 (`git show a3269b5cc:<path>`, the R02-G20-03 record commit), handing over separate files; the lead writes the presenter, scene,
controls and scenarios; D (simulator tests) starts once the presenter builds. Registration, app links and docs stay
with the lead (shared files). Agents do not commit, push or run heavy builds; checks are recorded only after every
agent has reported and the lead has retested its result.

## Complexity Tracking

None.
