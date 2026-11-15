# Research: A10-P00 (feature 074)

## 0. Verified facts (2026-11-14)

- `scripts/check_app_contract.py` verifies cited files, declared symbols (public when required), products, gap coverage
  and renders the Markdown view; contracts exist for A01–A09 under `docs/apps/<slug>/`.
- `scripts/check_experience_packages.py` forbids unregistered experience targets (`EXTRA_TARGET`).
- Constitution 2.6.0 commit `1d922dd7`; specify commit `8e4fcdbe`; reference pin `d93edd1`.
- Framework products with tests: `VisualCoreSimulation` (`SeededRandom`, `FixedStepClock`, `FixedStepRunner`,
  `ParticleSystem`, `Emitter`), `VisualCoreRendering` (`ParticleRenderer`, `ParticleBlend`, `PrimitiveRenderer`),
  `VisualCoreScenes` (`SceneNode` in `SceneGraph.swift`, `Primitive` rect/circle/line/polygon/polyline, tap/double-tap/long-press/drag/pinch
  recognizers, `GestureArbiter`, `PointerTracker`), `VisualCoreMath` (`Camera2D`, `PlaneViewport`),
  `VisualCoreEffectsGraph` + `VisualCoreEffects` (passes copy, blur, bloom, distort, composite, feedback),
  `VisualCoreExperience` (`ExperienceStorage`, quality tiers), `VisualCoreDiagnostics` (`QualityGovernor`).
- Also present: `HapticPlanner` and `AnnouncementPlanner` (`AccessibilityPlans.swift`), `SceneNode.hitTest`,
  `TapRecognizer`, `DragRecognizer`, `ExperienceFeedback` (`VisualCoreExperienceHost`).
- No 2D collision (shape-against-shape overlap or swept tests) exists in any framework product — the "intersect"
  matches are mesh and camera-bound helpers; `VisualCoreAudio` holds input sources only (demo, file, microphone,
  test signal), so no sound playback exists; no transition component exists beyond the experience lifecycle states.
- Nine experiences are registered (`Catalog/registrations.json`, A01–A09); A10 is absent.

## 1. Decisions

- **D1 Shell:** the one app is the shell (clarification 1); targets arrive in A10-P01. Alternative rejected: an empty
  registered experience (a placeholder).
- **D2 Matrix scope:** six brainstorm capabilities and the six version 0.1 features, plus the cross-cutting rows
  (persistence, quality tiers and low power, accessibility and Reduce Motion, lifecycle, licenses); availability rule
  of clarification 2.
- **D3 Regression:** two chunks as for every VisualCore-adjacent gate (`reference-engine-xcframework
  reference-build-projectm-ios-sim reference-clean`; `reference-test-anglerendering-ios27
  reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`).
- **D4 Gap owners (clarification 5):** 2D collision (circle and capsule overlap, swept tests for fast hazards) →
  `VisualCoreSimulation` (A10-P01; swept case proved by A10-P03's fixture); game rules, input replay and lanes →
  app-local (A10-P01/P02); synthesized sound-effect playback → `VisualCoreAudio` (A10-P03); title, pause and
  game-over transitions → app-local over the presenter (A10-P03); touch-steering sensitivity → app-local over
  `DragRecognizer` (A10-P04); crash-safe local high scores → app-local over `ExperienceStorage` (A10-P04); glow
  readability caps over bloom quality → app-local (A10-P05).
