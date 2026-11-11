# Implementation Plan: Fluid Art Playground — Phase 05 Numerical fixtures and device stress tests

**Branch**: `023-fap-p05-fixtures-stress` (spec directory only; work stays on `main`) | **Date**: 2026-11-11 |
**Spec**: [spec.md](spec.md) | **Ledger gate**: A02-P05

## Summary

This phase completes MVP-05 and MVP-06:
- **Pause, Step, Resume and Reset**: the scene gets a step request and an in-place reset (no renderer rebuild).
- **Deterministic seeded test mode**: a fixed 1/60 s step and a seeded synthetic gesture script.
- **Simulation detail picker**: Low, Medium and High square grids, applied by rebuilding the field targets only.

It also adds:
- one named fixture suite for the manual's §11 fixtures 1–5, with fixture 5 the new bounded catch-up check;
- a 600-frame stress fixture in both storages;
- automation for the device campaign, rehearsed on simulators only.

VisualCore gains two generic pieces:
- `SyntheticGestureScript` in VisualCoreScenes;
- in VisualCoreAutomation, the `VISUALCORE_AUTORUN_SEED` key and an app-supplied post-run check.

## Technical Context

**Language/Version**: Swift 6.4.2, GLSL ES 3.00.

**Primary Dependencies** (each checked in code during this plan's audit):
- **VisualCoreScenes**: `PointerEvent(id:phase:location:timestamp:)`, `PointerPhase`, `PointerVelocityTracker`,
  `PointerTracker`.
- **VisualCoreSimulation**: `SeededRandom(seed:)`, `TimeStepPolicy.clamp` (1/240…1/30 s; invalid deltas give
  1/240 s), `FieldGrid`.
- **VisualCoreDiagnostics**: `FramePacing.clampedDelta` (≤ 0.1 s).
- **VisualCoreRendering**:
  - `RenderHost`: `renderOneFrame(present:)` uses a 1/60 s delta; `pause()` and `resume()`; nothing renders unless
    active; `readPixels()`; `resources.stats.leaked`; `recreateContext()`.
  - `RenderTarget.readFloatPixels()`.
  - `PingPongTarget`, `FieldPass`.
- **VisualCoreAutomation**: `AutomationView(mode:bundleID:makeScene:configure:outputDirectory:terminate:)`,
  `AutomationRunner` (modes smoke, launch, lifecycle; `requestedMode`, `requestedFrames`; report write and exit), and
  `AutomationReport.message`.
- **Scripts**: `scripts/check_release_symbols.py` (`--app`, `--expect-present`), `scripts/check_app_isolation.py`,
  `release_check.py`.
- **System**: CryptoKit `SHA256` (public) for the picture digest in test builds only.

**Storage**: None (test-mode settings come only from the launch environment in automation builds).

**Testing**:
- host `swift test` for VisualCore (gesture script, seed key parsing) and FluidArtPlaygroundCore (detail levels,
  control state);
- app unit and UI tests on iOS 27.2 and 26.5 with the enumeration guard;
- simulator automation rehearsal with `simctl launch`, with the environment set;
- a Release generic-iOS build and the symbol check;
- the ProjectM regression after the VisualCore changes.

**Target Platform**: iOS/iPadOS 26.0+.

**Performance Goals**: no invented thresholds (manual §12). Reports record frame-time statistics for the device
campaign.

**Constraints**:
- no catch-up loop;
- no EGL in the app;
- automation only under `DEBUG || VISUALCORE_AUTOMATION`;
- no physical device.

**Scale/Scope**:
- VisualCore: 1 new type plus 2 small additions to VisualCoreAutomation.
- App Core: 2 new files.
- App: scene control and reset, the Adjust detail picker, the playground controls, and `AppAutomation.swift`.
- About 7 new test classes.

## Constitution Check

| Principle / rule | Compliance | Status |
|---|---|---|
| I. Proven renderer only | All GPU work stays in `FieldPass` and `RenderHost`; automation uses `AutomationView`'s host. | PASS |
| II. Reuse first, app-neutral API | The gesture script and post-run check are generic and documented, with a baseline update. The fluid-specific check stays in the app. VisualCoreScenes → VisualCoreSimulation is a new pure, acyclic edge (ADR-0003 R2/R3; research R1). | PASS |
| II-a. Preserve reference | ProjectM regression (7/7) after the VisualCore changes. | PASS (planned) |
| III. GPU lifecycle | A detail change releases and re-creates only field targets inside the scene's own render call, with the context current. Reset uploads through existing targets. The lifecycle mode covers pause, resume and context recreation. | PASS |
| IV. Host-testable, test first | Script, detail levels and control state get host tests first. | PASS |
| V. Implementation before devices | Simulator rehearsal only; device runs are marked pending the lock. | PASS |
| VI. Evidence | run-check for every command; reports are not claimed as device evidence. | PASS |
| VII. Accessible UI | Native buttons and a picker with labels, values and hints; the audit at default size and XXXL. | PASS |
| VIII. Public APIs, privacy | CryptoKit and ProcessInfo only; no new permission or networking. | PASS |
| IX. Bounded input | Seed parsed to UInt64 (fallback 1), frames clamped 1…10,000, pointer count 1…10, detail an enum. | PASS |
| A02 bounded GPU | No out-of-grid reads; per-frame splat cap; quality tiers unchanged. | PASS |

## Project Structure

```text
Packages/VisualCore/Package.swift                                               # EDIT VisualCoreScenes depends on VisualCoreSimulation
Packages/VisualCore/Sources/VisualCoreScenes/SyntheticGestureScript.swift        # NEW
Packages/VisualCore/Tests/VisualCoreScenesTests/SyntheticGestureScriptTests.swift # NEW
Packages/VisualCoreRendering/Sources/VisualCoreAutomation/AutomationRunner.swift  # EDIT seedKey, requestedSeed, postRunCheck
Packages/VisualCoreRendering/Sources/VisualCoreAutomation/AutomationView.swift    # EDIT postRunCheck parameter
Packages/VisualCoreRendering/Tests/VisualCoreAutomationTests/…                   # EDIT seed and check tests
docs/api/public-api-baseline.*                                                   # EDIT (check_public_api.py --update)
Apps/FluidArtPlayground/FluidArtPlaygroundCore/Sources/FluidArtPlaygroundCore/
├── FluidDetail.swift            # NEW Low/Medium/High → grid edge
└── SimulationControl.swift      # NEW running/paused, step request, accessibility strings
Apps/FluidArtPlayground/FluidArtPlaygroundCore/Tests/FluidArtPlaygroundCoreTests/
└── FluidDetailTests.swift, SimulationControlTests.swift   # NEW
Apps/FluidArtPlayground/App/
├── FluidFieldsScene.swift       # EDIT requestStep(), resetFields(), rebuildFields(configuration:), fieldCheck()
├── PlaygroundView.swift         # EDIT Pause/Step/Reset toolbar controls, detail wiring, reset of strokes
├── AdjustPanel.swift            # EDIT Simulation detail picker
├── TestMode.swift               # NEW deterministic test-mode configuration + script-driven splat source (DEBUG||AUTOMATION)
├── AppAutomation.swift          # NEW AutomationView root with post-run check (DEBUG||AUTOMATION)
└── FluidArtPlaygroundApp.swift  # EDIT route to AppAutomation when VISUALCORE_AUTORUN is set
Apps/FluidArtPlayground/Tests/Unit/
├── ControlTests.swift           # NEW pause/step/resume/reset
├── DeterminismTests.swift       # NEW test mode same/different seed
├── FixtureSuiteTests.swift      # NEW fixtures 1–5 named (fixture 5 new; 1–4 call the existing fixtures' helpers)
├── StressTests.swift            # NEW 600 frames per storage, finiteness, cap
├── DetailTests.swift            # NEW grid per level, 10 switches, no leaks
└── AutomationTests.swift        # NEW AppAutomation check with a fake terminate, report fields
Apps/FluidArtPlayground/Tests/UI/ControlsUITests.swift   # NEW; the audit test gains the controls
project.yml                       # EDIT FAP depends on VisualCoreAutomation (empty unless DEBUG||AUTOMATION)
docs/apps/fluid-art-playground/visualcore-contract.{json,md}, device-campaign.md, regression-baseline.md  # EDIT/NEW
```

Dependency direction: app → VisualCoreAutomation (test builds) → VisualCoreRendering → VisualCore. VisualCoreScenes
→ VisualCoreSimulation → VisualCoreMath. Nothing in VisualCore imports the app.

## Lifecycle contracts

- **Step**: `scene.requestStep()` sets a one-shot flag. In `render`, if the scene is paused and the flag is set, one
  step runs: drain, splats, advect, solve, advect dye. Then the flag clears. While running, the flag is ignored and
  cleared.
- **Reset**: `scene.resetFields()` sets a flag. The next `render` (with the context current):
  1. uploads the seed dye (current palette's colors) and zero velocity (encoded) to the read targets;
  2. fills pressure and divergence with zero;
  3. sets the step count to 0.

  The model empties the splat queue, cancels active tracker strokes and keeps `paused`. A frame is rendered after
  Reset so a paused canvas shows the seed.
- **Detail change**: `scene.rebuildFields(configuration:)` stores the new requested grid. The next `render`:
  1. releases the field targets and passes (`releaseAll`);
  2. runs `setup(context)` with the new request (the device cap applies);
  3. on failure, falls back to the previous grid once and records `lastError`.

  The model then rebuilds the `SplatQueue` for the validated grid.
- **Suspend/resume (fixture 5)**: unchanged host behavior. A paused host renders nothing, and `resume()` clears the
  last timestamp. The scene runs at most one step per rendered frame.
- **Test mode**: `TestMode.configure(model:seed:)` sets `scene.fixedDelta = 1/60` and replaces the model's splat
  source with a drain of `SyntheticGestureScript` events. The events go through the same `handle(_:)` path as real
  touches, mapped to frames at 60 Hz.
- **Automation**: `AppAutomation.root(mode:)` builds `PlaygroundModel` in the test mode and hands its effect scene to
  `AutomationView`. The post-run check reads the fields back (`fieldCheck()`) and returns nil, or a failure with the
  first bad value. The digest is reported in the message on pass.

## Migration and rollback

- **Migration**: none is persisted. Default grid 128×128 and every earlier fixture are unchanged.
  `AutomationView`'s new parameter has a default, so A01 and Showcase compile unchanged. Its init is source-compatible
  and the baseline is updated.
- **Rollback**: revert the feature-023 commits. VisualCore additions are additive.

## Complexity Tracking

None.
