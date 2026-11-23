# Implementation Plan: R02-G13-03 — Acoustic Constellator: procedural materials and hero renderer

**Branch**: `423-acoustic-constellator-procedural-materials-and-hero-renderer` (spec directory only; work on `main`) |
**Date**: 2026-11-23 | **Spec**: [spec.md](spec.md)

## Summary

Add Acoustic Constellator's hero renderer on the pattern of Harmonic Bridges's (feature 413): an immutable scene
snapshot (stars with drawing positions, rates and starting phases, the links, the symbol, the kernel's listen report of
the current state, threshold, hold, window, stage, failure, actions left, budget, level number, presentation time); the
constellation geometry (dark sky, dashed plum guides for unlinked symbol pairs, silver spline links that turn teal when
their phase gap at the shown tick is at most 1, broken strips for snapped links, star-white ellipsoid stars with phase
hands, the coherence gauge with its threshold mark, the hold pips and the moves gauge) with a fixed authored camera and
a CPU reference of the projection and palette; GLSL ES 3.00 constellation and glow programs with signed-distance
shading of stars, hands and filaments; three tiers (wave shells, star pulse, glow); the adapter
`AcousticConstellatorExperienceCore` (link, unlink, nudge, listen, undo, redo, next level; digest = level number + play
fingerprint; snapshot schema 1); the iOS experience (presenter with tier log, fallback, Reduce Motion and Reduce
Flashing, scene, minimal control panel with a chosen star and partner); the scenario manifest with 80 acceptance
scenarios; and the candidate registration in the one app. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00 (strings in Swift sources). **Primary dependencies**: VisualCoreSimulation,
VisualCoreMath, VisualCoreScenes (`MeshBuilder`), VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence in
the Core; VisualCoreRendering (`ShaderMeshRenderer`, `MeshRenderer`), VisualCoreExperienceHost and VisualCoreUI in the
Experience. No Objective-C++ bridge; no second renderer; no new VisualCore API.
**Package**: `Packages/ExperiencesRound02/Package.swift` has `AcousticConstellatorCore` and `AcousticConstellatorCoreTests`; it
gains `AcousticConstellatorExperience` (path `AcousticConstellator/Experience`), `AcousticConstellatorExperienceTests` and the product;
rendering dependencies carry `condition: .when(platforms: [.iOS])` and sources sit in `#if os(iOS)`, so the Cores still
run on the host.
**App**: `project.yml` adds the `AcousticConstellatorCore` and `AcousticConstellatorExperience` products; the registry registers
the candidate; `Catalog/registrations.json` gains the entry (content facts: 100 levels and the
catalog digest pinned at R02-G13-02), `build_catalog.py` regenerates `experiences.json` and
the fixtures; `AppModelTests` switches its synthetic unregistered candidate to `r02-g14.moonlit-mechanism`;
`scripts/test_scripts.py` and the package count follow; `xcodegen generate` after `project.yml` changes.
**Seeds**: level (seed mod 100) + 1; tests use seed 2_423 and the catalog's levels 1, 21, 41, 61, 81.
**Exact to float**: the snapshot keeps the kernel's integer phases, links and listen report; world positions are
computed once from the drawing grid (X = (gx − 5.5) · 0.14, Z = (gy − 5.5) · 0.11, Y = 0.15 + (gz − 5.5) · 0.02); the
pulse and the gauge fill are presentation only; no rule is evaluated on Doubles.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator `xcodebuild_package.py …
--destination sim-27.2 --action test`; the app unit tests; regression; script tests alone; audits wait for devices.
**Performance**: at most 8 stars (an ellipsoid is 12 × 8 segments, 192 triangles, plus a hand), 16 links of 16
segments, 10 guides of 8 dashes, 12 coherence bars, 12 hold pips and 19 moves bars: the largest scene stays under 3,000
triangles plus two glow shells and two wave shells; geometry is rebuilt only when the links, phases, stage, shown tick or
tier change; the pulse moves by uniforms. Device budgets are `{device}` tasks after ImplementationLock-100.
**Shader limits**: one uniform block of at most 16 vec4s per program; no texture samplers; loops bounded by constants
(at most 8 stars per draw).
**Constraints**: additive; denylisted names (ProjectM, PresetLibrary, MilkDrop …) avoided; no `import MetalKit` text in
any file (compliance scan); scenarios only under `#if DEBUG || VISUALCORE_AUTOMATION`; the presenter declares frame
probes (round-two X gate rule); the Core declares its quality tiers (X gate rule).

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — existing GL path and `ShaderMeshRenderer`; no second renderer. |
| II App-neutral API | PASS — game code in the experience package; VisualCore API unchanged. |
| IV Host-testable | PASS — adapter, geometry and CPU reference in the Core; GL code tested on the simulator. |
| V Implementation before devices | PASS — device budgets are `{device}` tasks. |
| IX Bounded input | PASS — snapshot values bounded; actions validated by declared controls and the kernel. |
| X Licensing and provenance | PASS — original shaders and geometry; palette from the project's design (star white, teal resonance, plum). |
| XI One app and stable identity | PASS — candidate `r02-g13.acoustic-constellator`; no app target. |
| XII One purchase, no advertising | PASS — free; no store code. |
| XIII Code-driven visuals | PASS — generated meshes and GLSL only. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                                   edit (lead)
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorExperienceCore.swift       new  adapter (agent C)
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorSceneSnapshot.swift        new  snapshot, palette, tiers (lead)
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorSceneGeometry.swift        new  geometry, camera, CPU reference (agent B)
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorShaders.swift              new  GLSL sources (agent A)
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorScenarios.swift            new  scenario manifest source (lead)
Packages/ExperiencesRound02/AcousticConstellator/CoreTests/{…ExperienceCoreTests (C), …SceneGeometryTests (B), …ShaderSourceTests (A),
  …RendererPurityTests (C), …ScenariosTests (lead)}.swift                                       new
Packages/ExperiencesRound02/AcousticConstellator/Experience/{AcousticConstellatorExperience, …Presenter, …ConstellationScene, …Controls}.swift   new (lead)
Packages/ExperiencesRound02/AcousticConstellator/ExperienceTests/{…TestSupport, …RenderTests, …TierTests, …FallbackTests, …ExperienceIdentityTests}.swift  new (agent D)
Packages/ExperiencesRound02/AcousticConstellator/scenario-manifest.json                                                  new (lead)
Catalog/registrations.json, Catalog/experiences.json, Apps/VisualCore/App/ExperienceRegistry.swift, project.yml,
  Apps/VisualCore/Tests/Unit/AppModelTests.swift, fixtures, scripts/test_scripts.py          edit (lead)
docs/architecture/acoustic-constellator.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: AcousticConstellatorCore (kernel and catalog, R02-G13-01/02) → snapshot → geometry, shaders, adapter →
scenarios → Experience (presenter, scene, controls) → app registry. **CI checks**: the host package job, the round-two
simulator suite, the catalog/registration checks of `build_catalog.py --check` and `test_scripts.py`. **Migration**:
none (snapshot schema 1 is new). **Rollback**: revert the commits; the catalog entry returns to its pre-registration
form; the Core kernel is untouched.

## Parallel work

Lead: package and snapshot first; then agents A (shader sources), B (geometry, camera, CPU reference) and C (adapter and
purity) in parallel; the lead writes the presenter, scene and controls; D (simulator tests) starts once the presenter
builds. Registration, app links and docs stay with the lead. Checks are recorded only after every agent has reported.
