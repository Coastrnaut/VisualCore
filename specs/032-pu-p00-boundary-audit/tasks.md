---

description: "Task list for feature 032 — Particle Universe Phase 00 boundary audit (ledger gate A04-P00)"
---

# Tasks: Particle Universe — Phase 00 boundary audit

**Input**: `/specs/032-pu-p00-boundary-audit/`.

**Tests** are required: the shared contract check; the shell smoke test on both simulators, enumeration-guarded; the
reference regression.

**Conventions**: IDs `T-A04-0##`, one commit and push per task (`scripts/tick_task.py`); commands through
`run-check --stage A04-P00`. Review checkpoint after each phase: `validate_docs.py` and
`check_app_contract.py --app particle-universe` pass.

## Phase 1: Setup

- [X] T-A04-001 Create `docs/apps/particle-universe/regression-baseline.md` with the phase-start commit (the A04 `speckit-constitution` commit `d425f7d`, before any A04 file) and the reference pin `d93edd1`, the base of the no-change diff for `Packages/` and `External/` (FR-A04-007). — Verified 2026-11-11: — Verified 2026-11-11: docs/apps/particle-universe/regression-baseline.md with phase-start commit d425f7d (the A04 speckit-constitution commit, before any A04 file) and the reference pin d93edd1 (git -C External/projectm-ios rev-parse: d93edd1)

## Phase 2: US1 — Evidence-backed integration matrix (P1) 🎯

- [X] T-A04-002 [US1] Write `docs/apps/particle-universe/visualcore-contract.json` (schema 1, app `particle-universe`, gate A04-P00): an `inventory` covering every area in FR-A04-001 with paths; `matrix` rows M01–M10 per research R1–R10 (five brainstorm rows: GPU-oriented simulation, buffer management, instanced rendering, blending and trails, interaction parameters; five v0.1 rows: emitter families with bounded counts, attractors/repulsors/gravity/wind, size/lifetime/gradient/trail strength, pause/reseed/save, device-adaptive quality and reduced flash). Each row cites only public non-test symbols with an example consumer. Run `check_app_contract.py --app particle-universe`; citation problems must be 0 (SC-A04-001, SC-A04-002). — Verified 2026-11-11: — Verified 2026-11-11: docs/apps/particle-universe/visualcore-contract.json (schema 1, gate A04-P00): 21 inventory areas (16 generic VisualCore areas from the A03 audit plus particle simulation, particle drawing, render targets for trails, quality tiers and accessibility, saved scenes); matrix M01-M10 per research R1-R10 (5 available, 5 requires adaptation), every row with public non-test evidence and an example consumer (A01 ParticleReplay/ParticlesArtScene, A02 FluidFieldsScene/PlaygroundModel, A03 Bookmark). run-check A04-P00/t002-contract: 0 citation problems; the only problems are the 5 gap entries T-A04-006 adds (as A03's T-A03-002)

## Phase 3: US2 — Host, thread, build and regression baseline (P1)

- [X] T-A04-003 [US2] Run the 7-step reference regression in two `run-check` chunks (A04-P00) and record the steps, commands and results in `docs/apps/particle-universe/regression-baseline.md` (FR-A04-004, SC-A04-004). — Verified 2026-11-11: — Verified 2026-11-11: run-check A04-P00/t003-reference-a 3/3 (engine xcframework, projectM-iOS simulator build BUILD SUCCEEDED, reference unmodified at d93edd1) and t003-reference-b 4/4 (ANGLERendering 14/14 and ProjectMReference 17/17 on iOS 27.2 and 26.5); recorded in docs/apps/particle-universe/regression-baseline.md

## Phase 4: US3 — Compilable empty app shell (P1)

- [X] T-A04-004 [US3] Add the shell: `Apps/ParticleUniverse/App/ParticleUniverseApp.swift` (@main SwiftUI app, `HomeView` with title "Particle Universe", identifier `pu.home.title`, accessibility label and header trait, container `pu.home`, accent tint via VisualCoreUI `AccessibleColors`); `project.yml` target `ParticleUniverse` (bundle `dev.visualcore.ParticleUniverse`, iOS 26.0, version 0.1.0 (1), `ITSAppUsesNonExemptEncryption` false, the dependency-audit post-build script, no usage descriptions), target `ParticleUniverseUITests` and the scheme; Info.plists generated under the gitignored `Apps/ParticleUniverse/Generated/`. Build for the generic iOS Simulator and run `check_dependencies.py` (FR-A04-005, FR-A04-006). — Verified 2026-11-11: — Verified 2026-11-11: Apps/ParticleUniverse/App/ParticleUniverseApp.swift (@main SwiftUI shell; HomeView title 'Particle Universe', header trait, accessibility label, identifier pu.home.title, container pu.home, accent tint from VisualCoreUI AccessibleColors); project.yml targets ParticleUniverse (dev.visualcore.ParticleUniverse, 0.1.0 (1), ITSAppUsesNonExemptEncryption false, no usage descriptions, dependency-audit post-build script) and ParticleUniverseUITests plus the scheme; Info.plists generated under the gitignored Apps/ParticleUniverse/Generated/. run-check A04-P00/t004-build BUILD SUCCEEDED (generic iOS Simulator, unsigned; post-build audit: no ProjectM engine/preset/bridge dependency); t004-dependencies R1-R5 hold
- [X] T-A04-005 [US3] Add `Apps/ParticleUniverse/Tests/UI/LaunchSmokeUITests.swift` (launch, `pu.home.title` exists with label "Particle Universe") and run it on iOS 27.2 and 26.5, enumeration-guarded (SC-A04-003). — Verified 2026-11-11: — Verified 2026-11-11: Apps/ParticleUniverse/Tests/UI/LaunchSmokeUITests.swift (launch, pu.home.title exists with label 'Particle Universe'); run-check A04-P00/t005-smoke-ios27 and t005-smoke-ios26 TEST SUCCEEDED, enumeration 1/1 each (the header comment was corrected afterwards; no code change)

## Phase 5: US4 — Gap register and stop/go decision (P2)

- [X] T-A04-006 [US4] Complete the contract JSON: `gaps` for every non-available row (G-EMITTERS VisualCoreSimulation phase 1; G-FIELDS VisualCoreSimulation phase 2; G-PQUALITY VisualCoreDiagnostics phase 2; G-BLENDTRAIL VisualCoreRendering phase 3; G-PSCENE app-local on NamedLibrary phase 4; G-GPUSIM later idea with the CPU decision) each with a test intent; `traceability` for v0.1 features 01–06 and journeys 1–3; `negative` rules (FR-A04-011); the go/stop `decision`. Render and check (FR-A04-008–011, SC-A04-005, SC-A04-007). — Verified 2026-11-11: — Verified 2026-11-11: visualcore-contract.json completed: 5 gaps (G-SIMSTEP VisualCoreSimulation phase 1 for M01 with the CPU decision; G-EMITTERS VisualCoreSimulation phase 1; G-FIELDS VisualCoreSimulation phase 2; G-PQUALITY VisualCoreDiagnostics phase 2; G-BLENDTRAIL VisualCoreRendering phase 3), each with a test intent and justification; traceability for the brainstorm, v0.1 features 01-06 and journeys 1-3; 5 negative rules with sources; decision go with 5 reasons and no blockers. visualcore-contract.md with generated markers rendered; run-check A04-P00/t006-contract-2 PASS (10 rows, 30 citations, 5 gaps, decision go). The first attempt t006-contract failed only on the missing .md markers

## Phase 6: Polish

- [X] T-A04-007 Confirm `git diff --stat d425f7d..HEAD -- Packages External` is empty (SC-A04-006); run the release-check fast steps (docs, app-contracts, compliance, dependencies, licenses, script-tests) and the documented-API check for `Apps/ParticleUniverse`. — Verified 2026-11-11: — Verified 2026-11-11: run-check A04-P00/t007-no-shared-changes: git diff --stat d425f7d..HEAD -- Packages External is empty (SC-A04-006); t007-fast-checks 8/8 (docs, app-contracts incl. particle-universe, compliance, dependencies, licenses, script-tests, documented-api-particle-universe, isolation-particle-universe)

## Dependencies

- 001 first; 002 and 003 independent; 004 → 005; 006 after 002; 007 last.

## Implementation strategy

Matrix first (the evidence every later phase relies on), then the baseline, shell, register and checks.

## Analyze remediation (2026-11-11, applied under CLAUDE.md §2)

- C1 (low): the shell's VisualCoreUI link (accent color only) is consistent with FR-A04-005/006; no change.
- 0 critical issues; coverage 18/18 requirements.

## Phase 7: Convergence

- [X] T-A04-008 Correct the contract inventory's "Build" entry: `release_check.py --list` gives 53 steps at A04-P00, not the 47 recorded at A03-P00; re-render and check the contract, per FR-A04-001 (partial) — Verified 2026-11-11: — Verified 2026-11-11: the Build inventory entry now gives 53 steps at A04-P00 (run-check A04-P00/t008-step-count: release_check.py --list = 53); contract re-rendered and checked in t008-contract PASS (10 rows, 30 citations, 5 gaps)
