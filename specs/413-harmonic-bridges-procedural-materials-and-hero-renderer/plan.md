# Implementation Plan: R02-G12-03 — Harmonic Bridges: procedural materials and hero renderer

**Branch**: `413-harmonic-bridges-procedural-materials-and-hero-renderer` (spec directory only; work on `main`) |
**Date**: 2026-11-23 | **Spec**: [spec.md](spec.md)

## Summary

Add Harmonic Bridges' hero renderer on the pattern of Echo Cartographer's (feature 403): an immutable scene snapshot
(islands with drawing positions, strings with their ends, lengths, current pegs and locks, the kernel's report, the
resonant modes per string and step, threshold, start, goal, stage, failure, actions left, budget, level number,
presentation time); the bridge geometry (mist ground, copper hexagonal island prisms with edge strips, the start ring
and goal star, swept string strips deflected by a presentation-only wave, cyan membranes under the strings that are
bridges in the shown step, the five sample marks per string — filled squares at or above the threshold, hollow rings
below — reached-island glow rings, the step pips and the moves gauge) with a fixed authored camera and a CPU reference
of the projection and palette; GLSL ES 3.00 bridge and glow programs with signed-distance shading of membranes, marks
and edges; three tiers (wave shells, string motion, glow); the adapter `HarmonicBridgesExperienceCore` (tune, test,
undo, redo, next level; digest = level number + play fingerprint; snapshot schema 1); the iOS experience (presenter
with tier log, fallback, Reduce Motion and Reduce Flashing, scene, minimal control panel with a chosen string and peg);
the scenario manifest with 80 acceptance scenarios; and the candidate registration in the one app. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00 (strings in Swift sources). **Primary dependencies**: VisualCoreSimulation,
VisualCoreMath, VisualCoreScenes (`MeshBuilder`), VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence in
the Core; VisualCoreRendering (`ShaderMeshRenderer`, `MeshRenderer`), VisualCoreExperienceHost and VisualCoreUI in the
Experience. No Objective-C++ bridge; no second renderer; no new VisualCore API.
**Package**: `Packages/ExperiencesRound02/Package.swift` has `HarmonicBridgesCore` and `HarmonicBridgesCoreTests`; it
gains `HarmonicBridgesExperience` (path `HarmonicBridges/Experience`), `HarmonicBridgesExperienceTests` and the product;
rendering dependencies carry `condition: .when(platforms: [.iOS])` and sources sit in `#if os(iOS)`, so the Cores still
run on the host.
**App**: `project.yml` adds the `HarmonicBridgesCore` and `HarmonicBridgesExperience` products; the registry registers
the candidate; `Catalog/registrations.json` gains the entry (content facts: 100 levels, digest
b832e7eef70880b12895f1e047d0baaf6a51fdd0a14ce9e655f02c022ab3c737), `build_catalog.py` regenerates `experiences.json` and
the fixtures; `AppModelTests` switches its unregistered example to `r02-g13.acoustic-constellator`;
`scripts/test_scripts.py` and the package count follow; `xcodegen generate` after `project.yml` changes.
**Seeds**: level (seed mod 100) + 1; tests use seed 2_413 and the catalog's levels 1, 21, 41, 61, 81.
**Exact to float**: the snapshot keeps the kernel's integer pegs and report; world positions are computed once from the
drawing grid (X = (gx − 7.5) · 0.12, Z = (gy − 4.5) · 0.12); the drawn wave is presentation only; no rule is evaluated on
Doubles.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator `xcodebuild_package.py …
--destination sim-27.2 --action test`; the app unit tests; regression; script tests alone; audits wait for devices.
**Performance**: at most 8 islands (a prism is 12 side and 12 cap triangles plus 6 edge strips), 12 strings of 24
segments with a membrane each, 60 sample marks, 4 pips and 19 gauge bars: the largest scene stays under 4,000 triangles
plus two glow shells and two wave shells; geometry is rebuilt only when the pegs, report, stage or tier change; the wave
and the shown step move by uniforms. Device budgets are `{device}` tasks after ImplementationLock-100.
**Shader limits**: one uniform block of at most 16 vec4s per program; no texture samplers; loops bounded by constants
(at most 3 resonant modes per string).
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
| X Licensing and provenance | PASS — original shaders and geometry; palette from the project's design (warm copper, cyan membranes, mist violet). |
| XI One app and stable identity | PASS — candidate `r02-g12.harmonic-bridges`; no app target. |
| XII One purchase, no advertising | PASS — free; no store code. |
| XIII Code-driven visuals | PASS — generated meshes and GLSL only. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                                   edit (lead)
Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesExperienceCore.swift       new  adapter (agent C)
Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesSceneSnapshot.swift        new  snapshot, palette, tiers (lead)
Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesSceneGeometry.swift        new  geometry, camera, CPU reference (agent B)
Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesShaders.swift              new  GLSL sources (agent A)
Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesScenarios.swift            new  scenario manifest source (lead)
Packages/ExperiencesRound02/HarmonicBridges/CoreTests/{…ExperienceCoreTests (C), …SceneGeometryTests (B), …ShaderSourceTests (A),
  …RendererPurityTests (C), …ScenariosTests (lead)}.swift                                       new
Packages/ExperiencesRound02/HarmonicBridges/Experience/{HarmonicBridgesExperience, …Presenter, …BridgeScene, …Controls}.swift   new (lead)
Packages/ExperiencesRound02/HarmonicBridges/ExperienceTests/{…TestSupport, …RenderTests, …TierTests, …FallbackTests, …ExperienceIdentityTests}.swift  new (agent D)
Packages/ExperiencesRound02/HarmonicBridges/scenario-manifest.json                                                  new (lead)
Catalog/registrations.json, Catalog/experiences.json, Apps/VisualCore/App/ExperienceRegistry.swift, project.yml,
  Apps/VisualCore/Tests/Unit/AppModelTests.swift, fixtures, scripts/test_scripts.py          edit (lead)
docs/architecture/harmonic-bridges.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: HarmonicBridgesCore (kernel and catalog, R02-G12-01/02) → snapshot → geometry, shaders, adapter →
scenarios → Experience (presenter, scene, controls) → app registry. **CI checks**: the host package job, the round-two
simulator suite, the catalog/registration checks of `build_catalog.py --check` and `test_scripts.py`. **Migration**:
none (snapshot schema 1 is new). **Rollback**: revert the commits; the catalog entry returns to its pre-registration
form; the Core kernel is untouched.

## Parallel work

Lead: package and snapshot first; then agents A (shader sources), B (geometry, camera, CPU reference) and C (adapter and
purity) in parallel; the lead writes the presenter, scene and controls; D (simulator tests) starts once the presenter
builds. Registration, app links and docs stay with the lead. Checks are recorded only after every agent has reported.
