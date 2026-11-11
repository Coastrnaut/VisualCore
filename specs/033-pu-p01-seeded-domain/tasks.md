---

description: "Task list for feature 033 — Particle Universe Phase 01 seeded particle domain (ledger gate A04-P01)"
---

# Tasks: Particle Universe — Phase 01 Seeded particle domain model

**Input**: `/specs/033-pu-p01-seeded-domain/` (spec, plan, research, data-model, contracts/simulation-api.md,
quickstart).

**Tests** are required by the spec: host tests for VisualCore (C1–C7) and the app domain (replay fixture); UI tests and
accessibility audits on iOS 27.2 and 26.5, enumeration-guarded; the reference regression after the VisualCore change.

**Conventions**: IDs `T-A04-1##`, one commit and push per task (`scripts/tick_task.py`); every command through
`desktop_runbook.py run-check --stage A04-P01`. Review checkpoint after each phase: `validate_docs.py` passes and the
named tests are green.

## Phase 1: Setup

- [X] T-A04-101 Create the app domain package `Apps/ParticleUniverse/ParticleUniverseCore/Package.swift` (swift-tools 6.0, iOS 26 / macOS 15, depends on VisualCore products VisualCoreSimulation and VisualCoreMath; test target `ParticleUniverseCoreTests`), a placeholder source `Sources/ParticleUniverseCore/Module.swift`, the `project.yml` package entry `ParticleUniverseCore` and its dependency on the `ParticleUniverse` target; `swift build` the package and build the app for the generic simulator (FR-A04-105). — Verified 2026-11-11: Apps/ParticleUniverse/ParticleUniverseCore (Package.swift on VisualCoreSimulation and VisualCoreMath, Module.swift, ModuleTests, Fixtures folder); project.yml package ParticleUniverseCore linked by the ParticleUniverse target. run-check A04-P01/t101-package-test swift test exit 0 (1 test); t101-build BUILD SUCCEEDED for the generic iOS Simulator with the post-build dependency audit

## Phase 2: Foundational — VisualCore gaps (blocking for all stories)

- [X] T-A04-102 [P] Write `Packages/VisualCore/Tests/VisualCoreSimulationTests/EmitterShapeTests.swift` first, then implement `Packages/VisualCore/Sources/VisualCoreSimulation/EmitterShape.swift` and extend `ParticleSystem.swift` (G-EMITTERS, FR-A04-101, FR-A04-102): `EmitterShape` `.point` / `.line(halfLength:angle:)` / `.ring(radius:)` (Codable); `EmitterBurst(count 1…5,000, interval 1/60…60 s)`; `Emitter.shape` (default `.point`), `Emitter.burst` (default nil), `Emitter.clamped()` (non-finite → default; rate 0…20,000; lifetime 0.01…3,600; speed 0…10,000; sizes 0…512; spread 0…2π; half length and radius 0…10,000); point draws no extra random number, line and ring draw one after angle and speed (research R2); per-emitter burst clock with at most one burst per step and leftover capped below one interval (research R3); the system emits from `clamped()` emitters. Tests: C2 (10,000 spawns per shape on the shape within 1e-9), C3 (demand 10× capacity: live ≤ capacity each step, dropped = demand − created), C4 (fuzzed inputs give finite in-range values), degenerate shapes behave as a point, burst cadence, and C1 (existing `ParticleSystemTests` unchanged). `///` docs on every public symbol. — Verified 2026-11-11: Packages/VisualCore/Sources/VisualCoreSimulation/EmitterShape.swift (EmitterShape point/line/ring, EmitterBurst, Emitter.clamped() and its ranges) and ParticleSystem.swift (shape and burst fields, clamped emission, per-emitter burst clock with at most one burst per step, point spawns unchanged); EmitterShapeTests 13 tests (C2 10,000 spawns on ring and line within 1e-9, C3 60 bursts of 1,000 into 100 = 59,900 dropped, C4 2,000 fuzzed emitters, cadence, long step, degenerate shapes, Codable). run-check A04-P01/t102-emitters exit 0 (20 tests incl. ParticleSystemTests), t102-visualcore-all exit 0 (whole VisualCore suite incl. baselines, C1), t102-a01-core exit 0 (A01 ParticleReplay unchanged). The lifetime clamp is 0.01-3,600 s, not 60 s: the VisualCore baselines use 100 s (recorded in spec and data model)
- [X] T-A04-103 [P] Write `Packages/VisualCore/Tests/VisualCoreSimulationTests/FixedStepRunnerTests.swift` first, then implement `Packages/VisualCore/Sources/VisualCoreSimulation/FixedStepRunner.swift` (G-SIMSTEP, FR-A04-103): `FixedStepSimulation` protocol (`step(_:)`, `checksum()`), `ParticleSystem` conformance, `ControlStream<Command>` (stable sort by step, negative steps dropped), `FixedStepRunner<Simulation, Command>` with `advance(frame:)`, `stepOnce()`, `run(steps:)`, `pause()`, `resume()` (discards accumulated time), `mutate(_:)`, `stepIndex`, `isPaused`, `clock`. Tests: C5 (paused → 0 steps; resume discards time), C6 (a 10 s frame runs ≤ 8 steps, rest in `droppedTime`), invalid frame times counted, C7 (commands apply before their step; 1/60 versus 1/30 s frame splits give the same checksum). — Verified 2026-11-11: Packages/VisualCore/Sources/VisualCoreSimulation/FixedStepRunner.swift (FixedStepSimulation protocol, ParticleSystem conformance, ControlStream with stable step order and dropped negative steps, FixedStepRunner advance(frame:)/stepOnce/run(steps:)/pause/resume/mutate, stepIndex, isPaused, clock); FixedStepRunnerTests 6 tests: C5 paused 30 s runs 0 steps and resume discards time, C6 a 10 s frame runs 8 steps with the rest dropped, invalid frames counted, C7 commands before their step, 1/60 vs 1/30 s frames vs run(steps:) give the same particle checksum and another seed differs. run-check A04-P01/t103-runner exit 0
- [X] T-A04-104 Run `swift test --package-path Packages/VisualCore` (all suites, including baselines) and A01's core tests `swift test --package-path Apps/GenerativeArtStudio/Core` to prove C1 (unchanged checksums); update the public-API baseline (`check_public_api.py --update`, then the check) and the documented-API check. — Verified 2026-11-11: public-API baseline updated (docs/api/visualcore-public-api.txt +39 lines; 1,159 declarations, 0 undocumented); run-check A04-P01/t104-api PASS (public-api, documented-api-particle-universe); t104-a01-core exit 0 (A01 ParticleReplay checksums unchanged, C1); t104-visualcore-2 exit 0 with 0 failures (whole VisualCore suite incl. baselines). The first full run t104-visualcore failed only in PlaneViewportTests.resizeKeepsCenterAndSquarePixels, a flaky A03-P01 test (unseeded random sizes, absolute 1e-15 tolerance below the ~1.8e-15 spacing at plane coordinates near 12); fixed with a seeded generator and a relative 1e-12 bound, passing 3 of 3 repeats

**Checkpoint**: VisualCore gaps closed on the host.

## Phase 3: US1 — Emitter families with bounded counts (P1) 🎯 MVP

- [ ] T-A04-105 [US1] Implement `Apps/ParticleUniverse/ParticleUniverseCore/Sources/ParticleUniverseCore/EmitterFamily.swift` (`fountain`, `curtain`, `halo`, `firework`; titles, spoken descriptions, `emitter()` and `forces()` with the clarification-4 parameters: Fountain point at (0, −400), 600/s, upward cone 0.6 rad, life 2–4 s, gravity; Curtain line at (0, 450), half length 400, 800/s, downward, life 2–3 s; Halo ring radius 200 at origin, 700/s, outward; Firework point at origin, bursts of 400 every 1.5 s, full spread, drag 0.8) with `Tests/ParticleUniverseCoreTests/EmitterFamilyTests.swift` (each family spawns on its shape; Firework spawns only in bursts; all families' live count ≤ limit at the 20,000 limit and at 100).
- [ ] T-A04-106 [US1] Implement `Apps/ParticleUniverse/App/SceneModel.swift` (@Observable @MainActor over `SceneSimulation`; family, seed, playing state; rebuild on family/seed change; pause on background, resume only if playing; Reduce Motion starts paused) and `Apps/ParticleUniverse/App/SandboxView.swift` (segmented family picker `pu.sandbox.family`, description `pu.sandbox.description`, labels `pu.sandbox.live` "Live particles: N of LIMIT" and `pu.sandbox.dropped` "Dropped: N", Play/Pause `pu.sandbox.play`, Step `pu.sandbox.step` enabled while paused, New seed `pu.sandbox.reseed`, `Canvas` in `TimelineView` fitting [−500, 500]² with y up, labelled `pu.sandbox.canvas`); home link `pu.home.open` "Open sandbox" in `ParticleUniverseApp.swift`. Depends on T-A04-108 for `SceneSimulation`.
- [ ] T-A04-107 [US1] Add `Apps/ParticleUniverse/Tests/UI/SandboxUITests.swift`: open the sandbox; each family selectable with its description; live count text present and ≤ limit; pause then Step changes nothing but the step; New seed resets; accessibility audits at default size and XXXL. Run the ParticleUniverse scheme on iOS 27.2 and 26.5 with the enumeration guard (SC-A04-106).

## Phase 4: US2 — Deterministic replay (P1)

- [ ] T-A04-108 [US2] Implement `Sources/ParticleUniverseCore/SceneCommand.swift` (`moveAttractor(index:x:y:)`, `burst(emitter:count:)` count clamped 1…5,000, `setEmitting(emitter:on:)`; invalid indices ignored and counted) and `Sources/ParticleUniverseCore/SceneSimulation.swift` (`init(scene:) throws(SceneError)`; `ParticleSystem(capacity: particleLimit, seed:)`; families' emitters and forces plus scene forces; `FixedStepRunner` step 1/120 cap 8; `advance(frame:)` multiplies by `timeScale`; `liveCount`, `droppedCount`, `ignoredCommands`, `checksum()`, `instances()`, `positions(first:)`).
- [ ] T-A04-109 [US2] Add `Tests/ParticleUniverseCoreTests/ReplayFixtureTests.swift` and write `Tests/ParticleUniverseCoreTests/Fixtures/replay-v1.json` once with `PU_WRITE_FIXTURE=1` (seed 0x5EED; Fountain and Firework; 600 steps; controls: move the attractor at step 120, burst at step 240, stop Fountain emission at step 360; expected checksum, live count and first 8 positions as bit-pattern hex). Tests: bit-exact match; another seed differs; the same replay through `advance(frame:)` at 1/60 and 1/30 s frames gives the same checksum (SC-A04-103, FR-A04-104). Run on the host and as package tests in both simulators.

## Phase 5: US3 — Bounded time (P1)

- [ ] T-A04-110 [US3] Add `Tests/ParticleUniverseCoreTests/SceneTimeTests.swift`: a 10 s frame runs ≤ 8 steps; pause, advance 30 s, resume → 0 steps for the paused time; NaN/negative/infinite frames run 0 steps and are counted; time scale 0.25 and 2 change step counts only (SC-A04-104).

## Phase 6: US4 — Validated, versioned scene (P2)

- [ ] T-A04-111 [US4] Implement `Sources/ParticleUniverseCore/ParticleScene.swift` (version == 1; seed UInt64; `particleLimit` 100…20,000 default 4,000; `timeScale` finite 0.25…2 default 1; `emitters` 1…8 `SceneEmitter(family, position?)`; `forces` ≤ 8 `SceneForce` gravity/drag k ≥ 0/attractor radius > 0, all finite; `validate() throws(SceneError)` with `unsupportedVersion`, `nonFinite(field)`, `limitOutOfRange`, `timeScaleOutOfRange`, `emitterCount`, `forceCount`; decoding validates) with `Tests/ParticleUniverseCoreTests/ParticleSceneTests.swift` (round trip equal; every invalid case rejected with its reason) (SC-A04-105). Implemented before T-A04-108, which consumes it.

## Phase 7: Polish & cross-cutting

- [ ] T-A04-112 Update `docs/apps/particle-universe/visualcore-contract.json` (gate A04-P01; G-SIMSTEP and G-EMITTERS closed with the new public symbols as evidence and the tests; M01 and M06 rows updated) and re-render the `.md`; `check_app_contract.py --app particle-universe` passes (FR-A04-107).
- [ ] T-A04-113 Run the ProjectM reference regression in two chunks (3/3, 4/4), rebuild A01 and A02 for testing from clean derived data, run the VisualCore package tests on iOS 27.2 and 26.5, and record the rerun in `docs/apps/particle-universe/regression-baseline.md` (FR-A04-107).
- [ ] T-A04-114 Run the release-check fast steps (docs, app-contracts, compliance, dependencies, public-api, licenses, script-tests, host-visualcore, documented-api-particle-universe, isolation-particle-universe) and the ParticleUniverseCore host tests.

## Dependencies

- 101 first. 102 and 103 in parallel; 104 after both.
- 111 → 108 → 105, 109, 110. 108 → 106 → 107.
- 112 after 104 and 109; 113 after 104; 114 last.

## Parallel examples

- T-A04-102 (EmitterShape) and T-A04-103 (FixedStepRunner) touch different files.
- T-A04-109 and T-A04-110 are separate test files once 108 exists.

## Implementation strategy

VisualCore gaps first (they are the reusable value and everything depends on them), then the scene schema and
simulation, the replay fixture, the time tests, the UI (MVP: families with bounded counts), then contract, regression
and fast checks.

## Analyze remediation (2026-11-11, applied under CLAUDE.md §2)

- U1 (medium): the replay fixture scene includes the force `attractor(0, 0, strength 300, radius 300)`, so the step-120
  control `moveAttractor(index: 0, x: 150, y: 100)` has a target (T-A04-109).
- U2 (low): the step-240 control is `burst(emitter: 1, count: 200)` (Firework); the step-360 control is
  `setEmitting(emitter: 0, on: false)` (Fountain).
- I1 (low): execution order follows the Dependencies section (111 → 108 → 105/109/110 → 106 → 107).
- T1 (low): simulator package tests for the app core use `scripts/xcodebuild_package.py --package
  Apps/ParticleUniverse/ParticleUniverseCore --scheme ParticleUniverseCore --destination sim-27.2|sim-26.5 --action test`.
- 0 critical issues; coverage 13/13 requirements.
