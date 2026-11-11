---

description: "Task list for feature 034 — Particle Universe Phase 02 one emitter and one force in the render loop (ledger gate A04-P02)"
---

# Tasks: Particle Universe — Phase 02 One emitter and one force in the render loop

**Input**: `/specs/034-pu-p02-render-loop/` (spec, plan, research, data-model, contracts/visualcore-api.md,
contracts/app-ui.md, quickstart).

**Tests** are required by the spec: host tests for VisualCore (C1–C7) and the app domain; simulator pixel tests for
`ParticleLayerScene` (C8, SC-A04-205); UI tests and accessibility audits on iOS 27.2 and 26.5, enumeration-guarded; the
reference regression after the VisualCore change.

**Conventions**: IDs `T-A04-2##`, one commit and push per task (`scripts/tick_task.py`, evidence text only); every
command through `desktop_runbook.py run-check --stage A04-P02`. Review checkpoint after each phase: `validate_docs.py`
passes and the named tests are green.

## Phase 1: Setup

- [X] T-A04-201 Add the `VisualCoreDiagnostics` product to `Apps/ParticleUniverse/ParticleUniverseCore/Package.swift` (target and test target) and the `ParticleUniverse` target's dependencies in `project.yml` (`VisualCore` product `VisualCoreDiagnostics`, `VisualCoreRendering` product `VisualCoreRendering` for `RenderHost`/`ParticleLayerScene`; analyze U1); `swift build` the package and build the app for the generic iOS Simulator with the post-build dependency audit (plan "Dependency direction"). — Verified 2026-11-11: ParticleUniverseCore Package.swift gains VisualCoreDiagnostics (target and tests); project.yml ParticleUniverse target gains VisualCoreRendering and VisualCoreDiagnostics. run-check A04-P02/t201-package-build exit 0; t201-build BUILD SUCCEEDED for the generic iOS Simulator with the dependency audit

## Phase 2: Foundational — VisualCore gaps (blocking for all stories)

- [ ] T-A04-202 [P] Write `Packages/VisualCore/Tests/VisualCoreSimulationTests/ParticleForceFieldTests.swift` first, then add `Packages/VisualCore/Sources/VisualCoreSimulation/ParticleForceFields.swift` and extend `ParticleSystem.swift` (G-FIELDS, FR-A04-201, FR-A04-202, contract C1–C4): cases `.repulsor(point:strength:radius:)`, `.gravityWell(point:strength:softening:)`, `.wind(velocity:rate:)`, `.vortex(point:strength:radius:)` with research R2 formulas (0 at the exact center; vortex counter-clockwise for positive strength); `clamped()` — "strength: ±10,000, or 0…1e9 for the gravity well; radius: 1…2,000; softening: 1…500; rate: 0…10; wind speed: ≤ 2,000", non-finite → 0, old cases only non-finite → 0 and negative drag → 0 (research R1); public range constants; `bound(speed:)` (repulsor/vortex/attractor |s|, gravity well 2s/(3√3·ε²), wind rate·(|w|+speed), gravity |g|, drag k·speed); `acceleration(at:velocity:)`; `step` clamps the force list once per step and keeps the old cases' arithmetic. Tests: SC-A04-201 (each kind at the center, at 1e-12 from it and on a 101 × 101 grid over ±2·radius, random finite and extreme parameters: finite and ≤ bound·(1+1e-12)); SC-A04-202 (10,000 steps with bursts on the center for every kind: `nanRemoved == 0`); direction checks (attractor/gravity well inward, repulsor outward, wind along w, vortex CCW); clamping of non-finite and out-of-range values; existing `ParticleSystemTests` unchanged. `///` docs on every public symbol.
- [ ] T-A04-203 Write `Packages/VisualCore/Tests/VisualCoreSimulationTests/LiveLimitTests.swift` first, then (after T-A04-202, same file; analyze F1) add `ParticleSystem.liveLimit` (G-PQUALITY, FR-A04-203, C5): "a settable value clamped to 1…capacity, defaulting to capacity. Emission stops while `aliveCount ≥ liveLimit`, and every refused particle counts as dropped"; not in `checksum()`. Tests: SC-A04-203 (demand 10× the limit for 600 steps with the limit lowered and raised mid-run: live ≤ liveLimit ≤ capacity each step, dropped = demand − created); lowering the limit removes nobody; default limit gives an identical checksum to a run without touching it.
- [ ] T-A04-204 [P] Write `Packages/VisualCore/Tests/VisualCoreDiagnosticsTests/ParticleBudgetTests.swift` first, then add `Packages/VisualCore/Sources/VisualCoreDiagnostics/ParticleBudget.swift` and `DeviceConditions.swift` (G-PQUALITY, FR-A04-203, C6, C7): `ParticleBudget(shares:minimum:)`, `.standard` shares `[1, 0.6, 0.35, 0.2]` minimum 100, "limit(requested:tier:) = min(requested, max(minimum, ⌊requested × share⌋))", tier clamped, `requested ≤ 0` → 0, shares clamped 0…1 and non-empty; `DeviceConditions(thermal:lowPower:)`, `.nominal`, `current()` from `ProcessInfo` under `#if canImport(Darwin)` (research R5). Tests: the 4,000 table (4,000 / 2,400 / 1,400 / 800), minimum and requested < minimum, out-of-range tiers; SC-A04-204 with `QualityPolicy(tierCount: 4, lowPowerCeiling: 1)`: serious heat at t = 0 lowers the limit at the first decision, calm for 10 s raises it, Low Power holds at tier ≥ 1; `current()` returns a valid value.
- [ ] T-A04-205 Run `swift test --package-path Packages/VisualCore` (all suites, including baselines), A01's core tests and the ParticleUniverseCore tests (replay-v1.json bit-exact) to prove the existing forces are unchanged; update the public-API baseline (`check_public_api.py --update`, then the check) and the documented-API check.

**Checkpoint**: G-FIELDS and G-PQUALITY closed on the host.

## Phase 3: US1 — Place and move one force (P1) 🎯 MVP

- [ ] T-A04-206 [US1] Write `Apps/ParticleUniverse/ParticleUniverseCore/Tests/ParticleUniverseCoreTests/PlacedForceTests.swift` first, then add `Sources/ParticleUniverseCore/PlacedForce.swift` and extend `ParticleScene.swift` and `SceneSimulation.swift` (FR-A04-204): `PlacedForceKind` (attractor, repulsor, gravityWell, wind, vortex; `title`, `spokenName`); `PlacedForce(kind, position, strength)` — "position clamped to −500…500 per axis; non-finite rejected (keeps old)", "strength clamped 0.1…2, non-finite ignored, default 1"; `particleForce` with defaults "attractor 300/r300, repulsor 400/r250, gravity well 2,000,000/ε40, wind 120 u/s (center → position, +x at center)/rate 0.8, vortex 250/r300" × strength; `SceneForce` cases `repulsor`, `gravityWell`, `wind`, `vortex` with validation ranges equal to VisualCore's; `SceneSimulation.setPlacedForce(_:)` / `placedForce` (slot 0, scene forces offset, `moveAttractor` indices offset). Tests: defaults and multipliers per kind; world clamp; kind change keeps position; removing restores the family's forces only; an attractor placed next to particles pulls them in after N steps, a repulsor pushes them away; SceneForce round trip and invalid ranges; replay fixture unchanged.
- [ ] T-A04-207 [US1] Extend `Apps/ParticleUniverse/App/SceneModel.swift` and `SandboxView.swift` (FR-A04-204, contracts/app-ui.md): kind menu `pu.sandbox.forceKind` (None, Attractor, Repulsor, Gravity well, Wind, Vortex), force text `pu.sandbox.force` ("Force: none" / "Force: Attractor at (x, y), strength ×1.0"), `pu.sandbox.center`, nudges `pu.sandbox.nudgeLeft/Right/Up/Down` (50 units), strength slider `pu.sandbox.strength` 0.1…2 with value "×1.0", tap/drag overlay on the stage (`DragGesture(minimumDistance: 0)`, research R8) mapped through the world square; controls wrap at accessibility sizes; per-frame reads stay in leaf views. Build for the generic simulator.
- [ ] T-A04-208 [US1] Add `Apps/ParticleUniverse/Tests/UI/SandboxForceUITests.swift`: choose each kind; tap places the force (text shows the kind and a position matching the tapped quadrant); drag moves it; Center gives (0, 0); each nudge moves 50 units; strength slider changes the text; None removes it. Run on iOS 27.2 and 26.5 with the enumeration guard (SC-A04-206).

## Phase 4: US2 — Forces never break the simulation (P1)

- [ ] T-A04-209 [US2] Add `Tests/ParticleUniverseCoreTests/PlacedForceStabilityTests.swift`: for every placed kind at strength 2, a scene whose emitter sits exactly on the force, 10,000 fixed steps: 0 non-finite removals and every live position finite (SC-A04-202 at the app level, manual fixture 4).

## Phase 5: US3 — The particle count yields to the quality controller (P1)

- [ ] T-A04-210 [US3] Write `Tests/ParticleUniverseCoreTests/SceneQualityTests.swift` first, then add `Sources/ParticleUniverseCore/SceneQuality.swift` and `SceneSimulation.setLiveLimit(_:)` / `liveLimit` (FR-A04-205): `SceneQuality` wraps `QualityPolicy(tierCount: 4, lowPowerCeiling: 1)` and `ParticleBudget.standard`; `update(conditions:now:requested:) -> Int`. Tests: serious heat lowers the effective limit at the first decision and the simulation's live count never exceeds it; calm 10 s raises it; Low Power keeps tier ≥ 1; dropped particles counted.
- [ ] T-A04-211 [US3] Add `Apps/ParticleUniverse/App/DeviceConditionsSource.swift` (DEBUG-only `-uitestThermal` / `-uitestLowPower` over `DeviceConditions.current()`, research R9) and wire `SceneQuality` into `SceneModel` once per advanced frame, with `pu.sandbox.effective` "Effective limit: N of LIMIT (quality tier T of 4)". Add `Apps/ParticleUniverse/Tests/UI/SandboxQualityUITests.swift`: default launch shows tier 1 of 4 and 4,000; `-uitestThermal serious` lowers the effective limit below 4,000; `-uitestLowPower YES` shows at most 2,400. The displayed tier is `tier + 1` (analyze B1). Run on both simulators with the enumeration guard; the task evidence includes a source grep showing the launch-argument reads occur only inside `#if DEBUG` (analyze B2).

## Phase 6: US4 — The GPU render loop draws what the simulation computes (P1)

- [ ] T-A04-212 [US4] Write `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/ParticleLayerSceneTests.swift` first, then add `Packages/VisualCoreRendering/Sources/VisualCoreRendering/ParticleLayerScene.swift` (C8, FR-A04-206): `WorldRect`, `init(world:background:source:)`, `fitCamera(world:viewSize:)`, setup/resize/render/teardown with `ParticleRenderer`, `lastInstanceCount`, `lastError`. Tests: SC-A04-205 on the three spec states (center burst, attractor, vortex) rendered with `RenderHost.renderOffscreen`: every projected center pixel lit (dominant channel ≥ 128), sampled pixels more than 3 radii from every particle are background; aspect fit on a non-square target; `recreateContext()` then a frame gives the same pixels; `fitCamera` round trip with `ViewMetrics.toWorld`. Run the rendering package tests on sim-27.2 and sim-26.5 (enumeration guard). `///` docs; API baseline update.
- [ ] T-A04-213 [US4] Add `Apps/ParticleUniverse/App/ParticleStage.swift` and wire it in `SandboxView.swift`/`SceneModel.swift` (FR-A04-206, plan "Lifecycle contracts"): one `RenderHost` with `ParticleLayerScene` (world −500…500, black) in `RenderSurface`; source closure calls `model.gpuFrame(_:)` (advance by `frame.delta` while playing, quality decision with `frame.time`, return the copy); host paused/resumed with the scene phase; init failure or non-`contextLost` error → CPU preview with `pu.sandbox.renderer` "Renderer: CPU preview (<reason>)", else "Renderer: GPU"; Reduce Motion starts paused on both paths; the app imports no CVisualCoreGL. Isolation check (`release_check.py --only isolation-particle-universe`).
- [ ] T-A04-214 [US4] Extend `Apps/ParticleUniverse/Tests/UI/SandboxUITests.swift` and `AccessibilityAuditUITests.swift`: renderer text says GPU; live count advances while playing and holds while paused on the GPU path; tap placement works over the GPU stage; audits at the default size and XXXL. Context recreation is covered by T-A04-212's package test (`recreateContext()`); the app exposes no public trigger for it (analyze E1). Run the whole ParticleUniverse scheme on iOS 27.2 and 26.5 with the enumeration guard (SC-A04-206).

## Phase 7: Polish & cross-cutting

- [ ] T-A04-215 Update `docs/apps/particle-universe/visualcore-contract.json` (gate A04-P02; G-FIELDS and G-PQUALITY closed with the new public symbols and tests as evidence; M07 and M10 rows updated; `ParticleLayerScene` cited for M02/M03) and re-render the `.md`; `check_app_contract.py --app particle-universe` passes (FR-A04-207).
- [ ] T-A04-216 Run the ProjectM reference regression in two chunks (`release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean` → 3/3; `--only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26` → 4/4; SC-F702 may be rerun unchanged once), rebuild A01 and A02 for testing from clean derived data, run the VisualCore package tests on iOS 27.2 and 26.5 (if not already after the last VisualCore change), and record the rerun in `docs/apps/particle-universe/regression-baseline.md` (FR-A04-207).
- [ ] T-A04-217 Run the release-check fast steps (docs, app-contracts, compliance, dependencies, public-api, licenses, script-tests, host-visualcore, documented-api-particle-universe, isolation-particle-universe, host-particle-universe-core).

## Dependencies

- 201 first. 202 and 204 in parallel; 203 after 202; 205 after 202–204.
- 206 after 205; 207 after 206; 208 after 207 and 213 (UI tests target the final stage).
- 209 after 206. 210 after 204 and 206; 211 after 210 and 207.
- 212 after 205; 213 after 212 and 207; 214 after 213 and 211.
- 215 after 205 and 212; 216 after the last VisualCore change (212); 217 last.

## Parallel examples

- Phase 2: T-A04-202 (Simulation forces) and T-A04-204 (Diagnostics) in parallel; T-A04-203 after 202 (same file).
- After 205: T-A04-206 (app core) and T-A04-212 (rendering package) touch disjoint files.

## Implementation strategy

MVP = Phase 2 + US1 on the GPU stage (T-A04-201…208, 212, 213). Then US2, US3, US4's UI tests, the contract and the
regression. The gate is sealed only after converge appends nothing.

## Analyze fixes (2026-11-11, owner delegation)

U1 app target also needs `VisualCoreRendering`; F1 T-A04-203 no longer [P]; B1 tier shown 1-based; B2 DEBUG seam evidence by source grep; E1 context recreation evidenced at package level. No critical issues; no speculative dependencies.
