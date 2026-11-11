---

description: "Task list for feature 007 — Phase 6 standalone Showcase (ledger gate F06)"
---

# Tasks: Phase 6 — Standalone VisualCore Showcase Application

**Input**: `/specs/007-showcase-app/` · **Tests**: required (smoke test FR-F611, audit fixtures FR-F610, simulator
tests); written with or before each piece. IDs `T-F6##`. One commit + push per task. Scenes implemented one at a time.

## Phase 1: Setup

- [X] T-F601 Root `project.yml` (XcodeGen 2.46.0) with targets `Showcase` (application, sources `Showcase/App`, resources `Showcase/Resources`, `Showcase/Shaders`), `ShowcaseTests` (`Showcase/Tests/Unit`), `ShowcaseUITests` (`Showcase/Tests/UI`), local packages `Packages/VisualCore` and `Packages/VisualCoreRendering`, bundle id `dev.visualcore.Showcase`, `Configs/Signing.xcconfig`; a minimal app shell that builds unsigned for the simulator — Verified 2026-11-10: F06.t601-shell-build TEST BUILD SUCCEEDED (XcodeGen 2.46.0 root project.yml, unsigned) + F06.t601-shell-test TEST EXECUTE SUCCEEDED on iOS 27.2: hosted unit test (bundle id dev.visualcore.Showcase) and launch UI test pass

## Phase 2: Foundational — independence (US5, P1) and shared infrastructure

- [X] T-F602 [US5] Dependency audit first: fixtures `scripts/fixtures/showcase_audit/{clean,import,package,framework,symbols}/` and tests in `scripts/test_scripts.py` (each contaminated fixture fails naming the item; clean passes), then `scripts/audit_showcase_dependencies.py` (layers spec / packages / imports / binary; deny-list from rule R1; ANGLE frameworks allowed; exit 0/1/2; `--json`) — Verified 2026-11-10: F06.t602-audit-tests exit 0: 7 audit tests (clean passes; import, package, framework, symbol fixtures each fail naming the item; ANGLE paths allowed; exit 2 on bad target; real repo spec/packages/imports clean); F06.t602-audit-showcase exit 0: spec 3, packages 2, imports 3, binary 6 Mach-O checked, 0 findings
- [X] T-F603 Framework addition `Texture.upload(rgba:)` in `Packages/VisualCoreRendering/Sources/VisualCoreRendering/GPUObjects.swift` with simulator test `TextureUploadTests.swift` (uploaded pixels sampled back; size mismatch and stale texture rejected) — Verified 2026-11-10: F06.t603-texture-upload-ios27 exit 0: 2 sim tests — 2×2 RGBA upload sampled back exactly at all four texels (rows bottom-up); wrong size and rgba16f rejected; texture from the old context rejected after recreation; 48 rendering tests pass
- [X] T-F604 Shared app infrastructure: `SceneCatalog` (descriptors with unique ids, titles, summaries, accessibility description/hint), `ShowcaseRenderScene` protocol, `ShowcaseSettings` (Reduce Motion/Flashing, launch arguments), `BundleShaders` (Shaders/*.glsl → ShaderLibrary), `SceneHostView` (one `RenderHost` per open scene, destroyed on close, pointer forwarding, error view), `DiagnosticsOverlay` (label format per contract, 4 Hz, "Simulate context loss"), navigation split view; unit tests `Showcase/Tests/Unit/{SceneCatalogTests,BundleShaderTests}.swift` — Verified 2026-11-10: F06.t604-infrastructure TEST SUCCEEDED (iOS 27.2): 6 hosted unit tests — catalog validation (duplicates, kebab ids, empty text), bundled common.glsl include expands with origin map, SceneHost diagnostics label format, simulated context loss gen+1 with scene rebuilt and leaked 0, close → destroyed leaked 0; launch UI test shows the split view

## Phase 3: US1–US3 — scenes one at a time (P1) 🎯

- [X] T-F605 [US2] Scene 1 gradient + texture: `Showcase/Shaders/{common.glsl,gradient.vert,gradient.frag,broken.frag}`, generated `Showcase/Resources/checker.png`, `GradientTextureScene.swift`; `-showcaseInjectShaderError YES` shows the parsed error with file and line and a Retry button; hosted pixel test `Showcase/Tests/Unit/SceneRenderTests.swift` samples the checker texture (alternating light/dark cells) and the gradient — Verified 2026-11-10: F06.t605-gradient-texture TEST SUCCEEDED (iOS 27.2, 8 hosted tests): gradient.vert/.frag via ShaderLibrary with common.glsl include; generated 64×64 checker.png uploaded with Texture.upload; pixel test: saturated left half, light >200 and dark <70 cells on the right; injected error reports 'broken.frag:5:' and Retry recovers; leaked 0. ResourceRegistry.program gains vertexName/fragmentName (defaults unchanged)
- [X] T-F606 [US1] Scene 2 animated geometry: `AnimatedGeometryScene.swift` (MeshRenderer cube + sphere on an OrbitCamera, Timeline spin, drag orbits; Reduce Motion stops spin) — Verified 2026-11-10: F06.t606-animated-geometry TEST SUCCEEDED (iOS 27.2): pixel test — blue cube and orange sphere at their projected centers; timeline spin advances over 10 frames; Reduce Motion freezes spin (status spin=off); drag orbits the camera (status changes); leaked 0
- [ ] T-F607 [US3] Scene 3 touch-interactive distortion: `DistortionScene.swift` + `Showcase/Shaders/ripple.frag` (content rendered to a target, ripple pass centered on the drag; status `touch=x,y`)
- [ ] T-F608 [US3] Scene 4 particles: `ParticleShowcaseScene.swift` (ParticleSystem + Primitive/ParticleRenderer, drag spawns, pinch zooms; status `particles=n zoom=z`)
- [ ] T-F609 [US2] Scene 5 multi-pass post-processing: `PostProcessingScene.swift` (EffectScene over animated content, graph colorMatrix → bloom → distort, Reduce Flashing appends flashLimit, toggle, status `passes=a>b>c` or `passes=off`); `SceneRenderTests` shows effect-on output differs from effect-off and effect-off equals the content

## Phase 4: US1/US3/US4 — smoke test (P1/P2)

- [ ] T-F610 [US1] [US3] [US4] XCUITest `Showcase/Tests/UI/ShowcaseSmokeUITests.swift`: every scene opens and frames advance with `error=none` within 2 s; drag/pinch on particles; drag on distortion; effect toggle; context loss (gen +1, frames resume ≤ 1 s, leaked=0); background/foreground; rotation to landscape keeps rendering and drag mapping; largest accessibility text size keeps the list usable; injected shader error shows file and line — on iOS 27.2 and 26.5

## Phase 5: Polish & Cross-Cutting

- [ ] T-F611 `Showcase/README.md` (scenes, build, smoke test, audit, placeholders awaiting owner branding)
- [ ] T-F612 Full verification: audit on the built Showcase (0 findings), script tests, Showcase unit + UI tests on iOS 27.2 and 26.5, generic-iOS Showcase build, VisualCoreRendering sim tests, host tests, R1–R5, compliance, docs, reference regression
- [ ] T-F613 {device} Showcase frame pacing, thermal and memory per scene on D1/D2/D3 — **deferred to campaign II** (constitution V)

## Dependencies

T-F601 → T-F602 (needs project.yml) and T-F603 (independent) → T-F604 → T-F605…T-F609 (one at a time; T-F605 needs T-F603) → T-F610 → T-F611/T-F612.

## Implementation Strategy

MVP = shell + audit + scene 1. Each scene lands with its own build and simulator screenshot check; the smoke test then covers all of them together.
