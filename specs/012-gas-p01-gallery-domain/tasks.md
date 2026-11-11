---

description: "Task list for feature 012 — Generative Art Studio Phase 01 gallery and domain contract (ledger gate A01-P01)"
---

# Tasks: Generative Art Studio — Phase 01 gallery and domain contract

**Input**: `/specs/012-gas-p01-gallery-domain/`. **Tests** are required:
- host tests for VisualCoreParameters, TestSupport and GenerativeArtStudioCore;
- simulator tests for packages and the app (pixels);
- UI tests;
- the reference regression.

IDs are `T-A01-1##`, with one commit and push per task via `scripts/tick_task.py`. **Review checkpoints:** after each
phase, run `check_public_api.py`, `check_dependencies.py` and `validate_docs.py`. After Phase 2, run the reference
regression.

## Phase 1: Setup

- [X] T-A01-101 Add the `VisualCoreParameters` target, product and test target to `Packages/VisualCore/Package.swift` (Foundation only, rule R2). Add a package-map row for the new module in `specs/002-architecture-contracts/contracts/package-map.md` (pure, depends on Foundation only). Add `Apps/GenerativeArtStudio/Core/Package.swift` (`GenerativeArtStudioCore`, macOS 15 + iOS 26, depending on `../../../Packages/VisualCore` products Parameters, Simulation and Math) with an empty test target. — Verified 2026-11-10: Packages/VisualCore/Package.swift: VisualCoreParameters target/product + VisualCoreParametersTests + VisualCoreTestSupportTests; package-map row added (Foundation only); Apps/GenerativeArtStudio/Core/Package.swift (GenerativeArtStudioCore → VisualCore Parameters/Simulation/Math); run-check A01-P01/t101-visualcore-host and t101-core-host swift test pass; check_dependencies R1-R5 PASS; API baseline updated (+ParametersInfo)

## Phase 2: Foundational — VisualCore building blocks (US3; blocks US1 and US2)

- [X] T-A01-102 [P] [US3] Implement `Packages/VisualCore/Sources/VisualCoreParameters/{Module,ParameterSchema,Palette,Preset,ParameterHash}.swift` per data-model.md: — Verified 2026-11-10: VisualCoreParameters: ParameterDefinition/Schema/Transform/Error, ResolvedParameters, Palette (exact sRGB, linear-light sample, 6 built-ins), Preset (string seed), ParameterHash (FNV-1a 64, pinned 78a5b4bc32dcc753 computed in Python); run-check A01-P01/t102-parameters-tests-a2: whole VisualCore host suite green incl. 7 parameter tests (validation, resolve rules, linear/log sliders, palettes, Codable re-validation incl. seed 2^64-1, hash stability/sensitivity); API baseline +44 documented declarations; R1-R5 PASS
  - names `^[a-zA-Z][a-zA-Z0-9_]{0,31}$`; finite range with min < max; default within range;
  - ≤ 64 parameters with unique names; `logarithmic` requires minimum > 0;
  - resolve rules: non-finite throws, out-of-range clamps with a warning, missing takes the default, unknown is dropped with a warning;
  - palette ids `^[a-z0-9-]{1,40}$` with 2–8 sRGB stops in 0…1; exact sRGB↔linear; `sample` in linear light;
  - six `builtIns`;
  - `Preset` with the seed encoded as a decimal string;
  - FNV-1a 64 hash, 16 hex digits, over `scope|seed|palette|name=%.9g;…` with names sorted.

  Add `///` docs and tests in `Packages/VisualCore/Tests/VisualCoreParametersTests/` covering each rule, normalized
  slider mapping (linear and log), hash stability and sensitivity, and Codable round trips including seed 2^64−1.
- [X] T-A01-103 [P] [US3] Implement `Packages/VisualCore/Sources/VisualCoreTestSupport/ImageComparison.swift` (`ImageDifference`, `ImageComparison.compare`, `ImageStatistics.meanLuminance/distinctColors`, RGB channels only; mismatched lengths give an infinite difference). Add tests in a new `VisualCoreTestSupportTests` target. — Verified 2026-11-10: VisualCoreTestSupport/ImageComparison.swift: ImageDifference (meanAbsolute, maxAbsolute, fractionWithin), ImageComparison.compare (RGB only; mismatch → infinite), ImageStatistics.meanLuminance (Rec.709) / distinctColors (5-bit); run-check A01-P01/t103-testsupport-tests: 5/5 pass; API baseline +9 documented
- [X] T-A01-104 [US3] In VisualCoreRendering: — Verified 2026-11-10: VisualCoreRendering: ShaderProgram.set(_:vec3Array:), ShaderBundle (bundle/in-memory, preloads vc/*.glsl from Bundle.module), GLSL library vc/{hash,noise,palette,sdf,color}.glsl with include guards, FullScreenShaderScene (u_time/fixedTime/timeScale, u_resolution, u_seed, u_palette[8]/count, u_<param>; errorMessage file:line); Package.swift resources; no Parameters dependency (analyze D1). run-check A01-P01/t104-rendering-ios27-a3 + ios26-a3: whole package green incl. ShaderBundleTests 2/2 (every include alone and all together compile) and FullScreenShaderSceneTests 4/4 (determinism max diff 0, seed/palette sensitivity, broken.frag:4, context loss identical + 0 leaks, array clamp with 0 warnings); API baseline updated; R1-R5 and compliance PASS
  - add `ShaderProgram.set(_:vec3Array:)`;
  - add `ShaderBundle` (loads `*.vert`, `*.frag` and `*.glsl` from a bundle subdirectory into `ShaderLibrary`, and preloads `vc/*.glsl` from `Bundle.module`);
  - add the GLSL library `Sources/VisualCoreRendering/GLSL/vc/{hash,noise,palette,sdf,color}.glsl` (package resources);
  - add `FullScreenShaderScene` (built-in vertex shader; binds `u_time`/`fixedTime`, `u_resolution`, `u_seed`, `u_palette[8]`/`u_paletteCount` and `u_<param>`; `errorMessage` = `file:line: message`);
  - add Package.swift resources (no dependency on VisualCoreParameters; analyze D1).

  Tests in `Tests/VisualCoreRenderingTests/{ShaderBundleTests,FullScreenShaderSceneTests}.swift`: every `vc/*.glsl`
  include compiles in a fragment; uniforms bind; a fixed time is deterministic (two renders match exactly); a broken
  fragment reports file and line; context loss followed by destroy leaks 0. Run on iOS 27.2 and 26.5.
- [X] T-A01-105 [US3] Implement `Packages/VisualCoreRendering/Sources/VisualCoreUI/RenderSurface.swift` (embeds a caller-owned `RenderHost.view` with an accessibility label and hint; sets `isAccessibilityElement` on the container) with a simulator test, and add VisualCoreUI dependencies in Package.swift. — Verified 2026-11-10: VisualCoreUI/RenderSurface.swift (UIViewRepresentable embedding a caller-owned RenderHost.view with edge constraints; container is one accessibility element with label, hint and image trait; never creates/destroys hosts) + VisualCoreUITests target; run-check A01-P01/t105-ui-ios27 + ios26: RenderSurfaceTests passed (embedded, 120×80 fill, label/hint, renders, 0 leaks after destroy), whole package green; API baseline updated
- [X] T-A01-106 [US3] Migrate `Showcase/App/BundleShaders.swift` to `ShaderBundle` (same names and behavior). Update `docs/api/visualcore-public-api.txt` (`check_public_api.py --update`, all documented) and the package READMEs (Parameters, ShaderBundle, GLSL library, FullScreenShaderScene, RenderSurface, ImageComparison). Run Showcase tests on both runtimes, then the reference regression (7 steps, as in A01-P00) (FR-A01-109). — Verified 2026-11-10: Showcase/App/BundleShaders.swift now delegates to VisualCoreRendering.ShaderBundle (same API); READMEs document VisualCoreParameters, TestSupport ImageComparison, ShaderBundle, vc/*.glsl, FullScreenShaderScene, set(_:vec3Array:), RenderSurface; check_documented_api Showcase PASS; API baseline matches; run-check A01-P01/t106-showcase-ios27 + ios26: Showcase unit 20/20 + UI 8/8 TEST SUCCEEDED; t106-reference-regression 7/7 pass (FR-A01-109)

## Phase 3: US2 — Deterministic, versioned domain contract (P1)

- [X] T-A01-107 [US2] Implement `Apps/GenerativeArtStudio/Core/Sources/GenerativeArtStudioCore/{SceneFamily,FamilyCatalog,ArtDocument,SeedOffsets,ParticleReplay}.swift` per data-model.md: — Verified 2026-11-10: GenerativeArtStudioCore: SceneFamilyID/SceneKind/SceneFamily, FamilyCatalog (4 families, schemas, 2 presets each, VisualCore palettes), ArtDocument v1 (validated(): newer/zero version, unknown family, non-finite → errors; resolve; palette fallback; previewTime 0…120; canonicalJSON sorted with string seed; hash; decode+migrate hook), SeedOffsets (SeededRandom), ParticleReplay (≤10,000, 1/60 steps to min(t,120)); swift build OK, exercised by run-check A01-P01/t108-core-tests; R1-R5 PASS
  - four families with schemas, default palettes and ≥ 1 preset each;
  - `ArtDocument` v1 with validation (unknown family or newer schema throws; non-finite throws; resolve through the schema; unknown palette falls back with a warning; previewTime clamped to 0…120), canonical JSON (sorted keys, seed as a string), `hash`, and a migrate hook;
  - `SeedOffsets` (first four `SeededRandom` outputs);
  - `ParticleReplay` (capacity ≤ 10,000, fixed 1/60 steps to min(t, 120)).
- [X] T-A01-108 [US2] Add tests in `Apps/GenerativeArtStudio/Core/Tests/GenerativeArtStudioCoreTests/`: — Verified 2026-11-10: run-check A01-P01/t108-core-tests: 8/8 pass — catalog (4 families, presets in range, unique ids), 60 generated documents incl. seeds 0 and 2^64-1 round-trip equal with equal hash and byte-stable canonical JSON (SC-A01-102), every validation outcome, corrupt/negative-seed/future-version decode rejection, hash sensitivity (5 distinct) and id/time independence, seed offsets, particle replay determinism, seed sensitivity, 120 s cap, capacity
  - ≥ 50 generated documents round-trip equal with an equal hash, including seeds 0 and 2^64−1 (SC-A01-102);
  - each invalid case gets its documented outcome;
  - the hash changes when any field changes;
  - particle replay is deterministic, and different seeds differ;
  - the time cap applies.

## Phase 4: US1 — Gallery and live scenes (P1)

- [X] T-A01-109 [US1] Add the app shaders `Apps/GenerativeArtStudio/Shaders/{gradient-noise,raymarched-shapes,geometric-tiling,particles-background}.frag` (using `vc/*.glsl`), plus `Apps/GenerativeArtStudio/App/{ArtSceneFactory,ParticlesArtScene}.swift` (a family's document → RenderScene: FullScreenShaderScene for three families, background + ParticleRenderer for particles). Update `project.yml` with the Core package, the VisualCore products (Parameters, Simulation, Math, Scenes, Rendering, UI) and the Shaders resources folder. — Verified 2026-11-10: Apps/GenerativeArtStudio/Shaders/{gradient-noise,raymarched-shapes,geometric-tiling,particles-background}.frag on vc/*.glsl; App/ArtSceneFactory.swift (ArtScene protocol, FullScreenShaderScene configured with values, linear palette stops, seed offsets) and ParticlesArtScene.swift (background + ParticleRenderer via ParticleReplayCursor); Core ParticleReplayCursor (+ test: matches full replay forward/backward/capped); project.yml Core package, VisualCore products, Shaders resources; run-check A01-P01/t109-app-build BUILD SUCCEEDED + ProjectM audit PASS; t109-core-tests pass; documented API, R1-R5, compliance PASS. Rendering verified by T-A01-111
- [X] T-A01-110 [US1] Add `Apps/GenerativeArtStudio/App/{GalleryView,SceneScreen}.swift` and update `GenerativeArtStudioApp.swift`: — Verified 2026-11-10: App/GalleryView.swift (gas.gallery; rows gas.family.<id> with symbol, palette swatch, title, summary, preset count; combined label + hint; header gas.home.title), SceneScreen.swift (SceneModel owns one RenderHost, RenderSurface gas.scene.canvas with family description, gas.scene.error from scene errorMessage, host destroyed on disappear, Reduce Motion time scale 0.5); run-check A01-P01/t110-app-build BUILD SUCCEEDED; simulator screenshot of the gallery shows the 4 families with swatches; documented API PASS. Behavior tests in T-A01-111
  - gallery list `gas.gallery` with rows `gas.family.<id>` (symbol, palette swatch, title, summary, preset count, label and hint);
  - `SceneScreen` owns one RenderHost via RenderSurface (`gas.scene.canvas`, the family's accessibility description), shows `gas.scene.error` on shader errors, and destroys the host on disappear. Under Reduce Motion the animation
    time scale is 0.5 (an injectable flag; edge case).
- [X] T-A01-111 [US1] Add an app unit-test target `GenerativeArtStudioTests` (hosted) with `Apps/GenerativeArtStudio/Tests/Unit/{RenderDeterminismTests,FamilyDistinctnessTests,SceneCleanupTests}.swift`, using `VisualCoreTestSupport`: — Verified 2026-11-10: GenerativeArtStudioTests (hosted) RenderDeterminism/FamilyDistinctness/SceneCleanup + GalleryUITests; run-check A01-P01/t111-app-tests-ios27-a2 + ios26-a2 TEST SUCCEEDED: SC-A01-101 4/4 non-blank (colors 48–584, luminance 0.153–0.535); SC-A01-103 rerender and round trip max diff 0 for all 4 families; SC-A01-104 6 pairs mean 75–115/255, seeds 1 vs 2 mean 13.6–57.5; SC-A01-105 context loss rebuilds identically, 0 leaks; broken shader → gradient-noise.frag:3; Reduce Motion time scale 0.5; UI: 4 labelled rows, each opens a described canvas with no error (screenshots in xcresult; raymarch framing fixed after visual review of the a1 run)
  - non-blank: ≥ 2 distinct colors and mean luminance 0.02–0.98 (SC-A01-101);
  - determinism, including after a round trip: ≥ 99% within 2/255 and mean ≤ 0.5/255 (SC-A01-103);
  - distinctness: 6 pairs with mean ≥ 20/255, and seeds of the same family with mean ≥ 2/255 (SC-A01-104);
  - context loss and destroy leak 0 (SC-A01-105);
  - a family with a broken fragment exposes `file:line` via the scene's error message (FR-A01-110);
  - the time scale is 0.5 under Reduce Motion (edge case).

  Add `Apps/GenerativeArtStudio/Tests/UI/GalleryUITests.swift`: four rows with their labels and hints, and opening each
  shows the canvas with no error (FR-A01-112). Run unit and UI tests on iOS 27.2 and 26.5.

## Phase 5: Polish and cross-cutting

- [X] T-A01-112 Update `docs/apps/generative-art-studio/visualcore-contract.json`: — Verified 2026-11-10: docs/apps/generative-art-studio/visualcore-contract.json (gate A01-P01): M01 and M05 now available with ShaderBundle/FullScreenShaderScene/ShaderLibrary and VisualCoreParameters evidence; G-SHADERLOAD, G-GLSLLIB, G-PARAMS closed in A01-P01; G-UI narrowed to the accessibility settings model; Test support inventory row; checker supports optional gap 'closed' (closed gaps do not cover open rows; test added; 011 data model documented); check_app_contract PASS 10 rows, 39 citations, 7 gaps; run-check A01-P01/t112-release-fast 9/9 (docs, app-contracts, compliance, dependencies, public API, documented API Showcase, licenses, script tests, host VisualCore); t112-documented-api-app PASS
  - M01 and M05 become `available` with the new evidence;
  - G-SHADERLOAD, G-GLSLLIB and G-PARAMS are closed (phase 1);
  - G-UI keeps only the accessibility-settings part (phase 2);
  - TestSupport image comparison is recorded.

  Re-render it; run `check_app_contract.py` and `check_documented_api.py --sources Apps/GenerativeArtStudio`; run
  `release_check.py --only docs app-contracts compliance dependencies public-api documented-api-showcase licenses script-tests host-visualcore`
  (FR-A01-113, SC-A01-106).

## Dependencies

T-A01-101 → T-A01-102, T-A01-103 (parallel) → T-A01-104 → T-A01-105 → T-A01-106. T-A01-102 → T-A01-107 → T-A01-108.
T-A01-104, T-A01-105 and T-A01-107 → T-A01-109 → T-A01-110 → T-A01-111. T-A01-112 runs last.

## Parallel opportunities

T-A01-102 and T-A01-103 touch different modules. T-A01-107 and T-A01-108 can proceed while the T-A01-104 to
T-A01-106 simulator runs complete (one Xcode lane).

## Implementation strategy

Build the VisualCore blocks first (the reuse rule), then the pure domain, then the gallery slice. Each checkpoint is
green before moving on.
