# Implementation Plan: Phase 8 — Reuse Validation with a Second Consumer

**Branch**: `009-second-consumer` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)

## Summary

"Lumen Garden", a small calm game in `Harnesses/SecondConsumer` (own `SecondConsumer.yml`). Domain logic lives in a
host-tested local package `GardenKit` (Garden, Flower, planting/spacing/capacity/growth/harvest/score/breeze on a
fixed step with a seeded RNG). The app renders it with only documented VisualCore APIs: `RenderHost` +
`pointerHandler`, `TapRecognizer`/`DragRecognizer`, `ViewMetrics`/`Camera2D`, a bundled background shader through
`ResourceRegistry.program(…library:)`, `PrimitiveRenderer`, `ParticleSystem` + `ParticleRenderer`, `EffectScene` with a
bloom glow, `FixedStepClock`. Two checks prove reuse: the four-layer dependency audit (now resolving package paths
relative to the spec, also a post-build phase) and a new documented-API check. An XCUITest smoke test runs the
gameplay scenario on iOS 27.2 and 26.5.

## Technical Context

**Language/Version**: Swift 6.4.2 (language mode 6), GLSL ES 3.00, Python 3 · **Primary Dependencies**: VisualCore
(Math, Simulation, Scenes, ShaderSource, EffectsGraph), VisualCoreRendering (VisualCoreRendering, VisualCoreEffects) —
local packages only · **Storage**: none (session only) · **Testing**: `swift test` for GardenKit (host); XCUITest smoke
test (iOS 27.2/26.5 simulators); script tests for the two checks (`scripts/test_scripts.py`) · **Target Platform**:
iOS 26.0+ · **Project Type**: harness app + local package (XcodeGen 2.46.0) · **Performance Goals**: functional only
(constitution V) · **Constraints**: no ProjectM (audit), documented APIs only, no network/permissions · **Scale/Scope**:
~5 app files, 2 GardenKit files, ~12 host tests, 1 UI test file, 1 new script + audit tweak.

## Constitution Check

I PASS (ANGLE path via RenderHost) · II PASS (pure consumer of public, documented API; audit) · II-a PASS (reference
untouched) · III PASS (scene teardown releases renderers; recreation handled by the host contract) · IV PASS
(GardenKit host-tested first) · V PASS (device deferred) · VI PASS (run-check evidence) · VII PASS (VoiceOver
labels, Reduce Motion) · VIII PASS (no permissions/network) · IX PASS (capacity 24, bounded particles) · X PASS
(original code/shader). Post-design: PASS.

## Project Structure

```text
specs/009-second-consumer/{plan,research,data-model,quickstart}.md, contracts/second-consumer.md, tasks.md
Harnesses/SecondConsumer/SecondConsumer.yml
Harnesses/SecondConsumer/GardenKit/{Package.swift,Sources/GardenKit/Garden.swift,Tests/GardenKitTests/GardenTests.swift}
Harnesses/SecondConsumer/Sources/{SecondConsumerApp,GardenScene}.swift
Harnesses/SecondConsumer/Shaders/field.frag (+ field.vert)
Harnesses/SecondConsumer/UITests/GardenSmokeUITests.swift
Harnesses/SecondConsumer/README.md
scripts/check_documented_api.py + scripts/fixtures/documented_api/{documented,undocumented}/
scripts/audit_showcase_dependencies.py   # package paths relative to the spec file
```

## Complexity Tracking

None.
