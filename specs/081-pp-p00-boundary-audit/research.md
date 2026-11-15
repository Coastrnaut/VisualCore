# Research: A11-P00 (feature 081)

## 0. Verified facts (2026-11-15)

- `scripts/check_app_contract.py` verifies cited files, declared symbols (public when required), products, gap coverage
  and renders the Markdown view; contracts exist for A01–A10 under `docs/apps/<slug>/`.
- `scripts/check_experience_packages.py` forbids unregistered experience targets (`EXTRA_TARGET`).
- Constitution 2.7.0 commit `35c24d86`; specify commit `d3797d7c`; reference pin `d93edd1`.
- Framework products with tests: `VisualCoreSimulation` (`SeededRandom`, `FixedStepClock`, `FixedStepRunner`,
  `FixedStepSimulation`, `TimeStepPolicy`, `ParticleSystem`, `Collision2D`, `CollisionCircle`, `CollisionCapsule`),
  `VisualCoreRendering` (`PrimitiveRenderer`, `ParticleRenderer`), `VisualCoreScenes` (`SceneNode` in
  `SceneGraph.swift`, `Primitive` rect/circle/line/polygon/polyline, `TapRecognizer`, `DoubleTapRecognizer`,
  `LongPressRecognizer`, `DragRecognizer`, `PinchRecognizer`, `GestureArbiter`, `PointerTracker`,
  `PointerVelocityTracker`), `VisualCoreMath` (`Vec2`, `Camera2D`), `VisualCoreEffectsGraph` + `VisualCoreEffects`,
  `VisualCoreExperience` (`ExperienceStorage`, quality tiers), `VisualCoreDiagnostics` (`QualityGovernor`).
- No rigid-body dynamics in any framework product: no box or polygon contacts, no impulse or constraint solver, no
  spring constraint, no broad phase. Fluid Art Playground's `FluidSolver` is app-local and a grid fluid, not rigid
  bodies. No chart or plot component exists.
- Ten experiences are registered (`Catalog/registrations.json`, A01–A10); A11 is absent.

## 1. Decisions

- **D1 Shell:** the one app is the shell (clarification 1); targets arrive in A11-P01. Alternative rejected: an empty
  registered experience (a placeholder).
- **D2 Matrix scope:** five brainstorm capabilities (scene rendering, geometry, animation, shader-based effects, data
  visualization) and the six version 0.1 features, plus the cross-cutting rows (fixed step and step policy, stability
  and body budget, persistence, quality tiers and low power, accessibility and Reduce Motion, lifecycle, licenses);
  availability rule of clarification 2.
- **D3 Regression:** two chunks as for every VisualCore-adjacent gate (`reference-engine-xcframework
  reference-build-projectm-ios-sim reference-clean`; `reference-test-anglerendering-ios27
  reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`).
- **D4 Gap owners (clarification 5):** body and world model, units, static bodies, gravity, drag, integration, pause,
  single step, time scale and reset → app-local over `FixedStepRunner` (A11-P01); box contacts, impulse solver with
  restitution, friction and positional correction, spring constraints with bounded stiffness, broad phase →
  `VisualCoreSimulation` (A11-P02); spawn/grab/pin/delete gestures, vector arrows and the measured state panel →
  app-local (A11-P03); presets and saved experiments → app-local over `ExperienceStorage` (A11-P04); stability caps,
  body budget and sleeping bodies → app-local (A11-P05). Alternative rejected: an app-local solver (constitution A11
  reuse first: contacts and constraints are generic).
