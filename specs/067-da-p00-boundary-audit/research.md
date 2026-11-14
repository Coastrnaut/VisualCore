# Research: A09-P00 (feature 067)

## 0. Verified facts (2026-11-14)

- `scripts/check_app_contract.py` verifies cited files, declared symbols (public when required), products, gap coverage
  and renders the Markdown view; contracts exist for A01–A08 under `docs/apps/<slug>/`.
- `scripts/check_experience_packages.py` forbids unregistered experience targets (`EXTRA_TARGET`).
- Constitution 2.5.0 commit `af97f2b0`; specify commit `951802c1`; reference pin `d93edd1`.
- Framework products with tests: `VisualCoreSimulation` (`SeededRandom`, `FixedStepClock`, `FixedStepRunner`,
  `ParticleSystem`, `Emitter`), `VisualCoreRendering` (`ParticleRenderer`, `ParticleBlend`, `PrimitiveRenderer`),
  `VisualCoreScenes` (`SceneNode` in `SceneGraph.swift`, `Primitive` rect/circle/line/polygon/polyline, tap/double-tap/long-press/drag/pinch
  recognizers, `GestureArbiter`, `PointerTracker`), `VisualCoreMath` (`Camera2D`, `PlaneViewport`),
  `VisualCoreEffectsGraph` + `VisualCoreEffects` (passes copy, blur, bloom, distort, composite, feedback),
  `VisualCoreExperience` (`ExperienceStorage`, quality tiers), `VisualCoreDiagnostics` (`QualityGovernor`).
- No neighbour search (spatial hash or grid) and no steering or flocking exists in any framework product.

## 1. Decisions

- **D1 Shell:** the one app is the shell (clarification 1); targets arrive in A09-P01. Alternative rejected: an empty
  registered experience (a placeholder).
- **D2 Matrix scope:** six brainstorm capabilities and the six version 0.1 features, plus the cross-cutting rows
  (persistence, quality tiers and low power, accessibility and Reduce Motion, lifecycle, licenses); availability rule
  of clarification 2.
- **D3 Regression:** two chunks as for every VisualCore-adjacent gate (`reference-engine-xcframework
  reference-build-projectm-ios-sim reference-clean`; `reference-test-anglerendering-ios27
  reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`).
- **D4 Gap owners (clarification 5):** habitat document and species catalog → app-local (A09-P01); bounded steering
  and neighbour search → `VisualCoreSimulation`, fish shapes and swim animation → app-local (A09-P02); feeding and
  placement → app-local (A09-P03); depth layers, bubbles, caustics → app-local over particles and effect passes
  (A09-P04); ambient low-motion mode with dimming → app-local (A09-P05).
