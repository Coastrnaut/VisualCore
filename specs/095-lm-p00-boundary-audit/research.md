# Research: A13-P00 (feature 095)

## 0. Verified facts (2026-11-15)

- `scripts/check_app_contract.py` verifies cited files, declared symbols (public when required), products, gap coverage
  and renders the Markdown view; contracts exist for A01–A12 under `docs/apps/<slug>/`.
- `scripts/check_experience_packages.py` forbids unregistered experience targets (`EXTRA_TARGET`).
- Constitution 2.9.0 commit `d5d232b6`; specify commit `57a587f9`; reference pin `d93edd1`.
- Framework products with tests (clarification facts): `VisualCoreMath` (`Vec2`, `Mat3`, `Camera2D`, `Ray3`,
  `RayHit3`), `VisualCoreSimulation` (`AABB2D`, `BroadPhase2D`, `Shape2D`, `Pose2D`, `Contacts2D`, `FieldGrid`,
  `Timeline`, accessibility planners and preferences), `VisualCoreScenes` (`Primitive`, `SceneNode`, gesture
  recognizers, `GestureArbiter`), `VisualCoreRendering` (`PrimitiveRenderer`, `RenderTarget`, `ResourceRegistry`,
  `PingPongTarget`, `TrailLayer`), `VisualCoreEffects` (`EffectRenderer`), `VisualCoreEffectsGraph` (pass schemas incl.
  blur, bloom, composite, flashLimit; `EffectGraphValidator`), `VisualCoreShaderSource` (`RenderState`, additive
  blending), `VisualCoreUI` (`AnnouncementSink`, `HapticSink`), `VisualCoreExperience` (`ExperienceStorage`,
  `ScenarioManifest`), `VisualCorePersistence` (`DocumentStore`, `MigrationChain`), `VisualCoreAudioDSP`
  (`SoundEffectSynth`), `VisualCoreAudio` (`SoundEffectPlayer`), `VisualCoreDiagnostics` (`QualityProfile`).
- No 2D ray against segments, no reflection, no tile board, no undo history, no progression model and no graph search
  exist in any framework product.
- Twelve experiences are registered (`Catalog/registrations.json`, A01–A12); A13 is absent.

## 1. Decisions

- **D1 Shell:** the one app is the shell (clarification 1); targets arrive in A13-P01. Alternative rejected: an empty
  registered experience (a placeholder).
- **D2 Matrix scope:** five brainstorm capabilities (render targets, shaders, geometry and transformations, touch
  controls, compositing and visual feedback) and the six version 0.1 features, plus the cross-cutting rows (beam
  geometry single source of truth, determinism and replay, bounded content, persistence, quality tiers and low power,
  accessibility with Reduce Motion and Reduce Flashing, lifecycle and context loss, sound and haptic feedback,
  licenses); availability rule of clarification 2.
- **D3 Regression:** two chunks as for every VisualCore-adjacent gate (`reference-engine-xcframework
  reference-build-projectm-ios-sim reference-clean`; `reference-test-anglerendering-ios27
  reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`).
- **D4 Gap owners (clarification 5):** 2D ray cast against segments and reflection → `VisualCoreMath` (A13-P01); board,
  tiles, optical rules, bounce cap and cycle detection → app-local (A13-P01); beam rendering and snapped drag and
  rotate → app-local (A13-P02); levels, progression, undo, restart and saved progress → app-local (A13-P03); hints,
  spoken descriptions, legible cues and success feedback → app-local (A13-P04); solvability checker → app-local
  (A13-P05). Alternative rejected: app-local ray math (constitution A13 reuse first: 2D ray casting with reflection is
  generic).
