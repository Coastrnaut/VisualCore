---

description: "Task list for feature 018 — Fluid Art Playground Phase 00 boundary audit (ledger gate A02-P00)"
---

# Tasks: Fluid Art Playground — Phase 00 boundary audit

**Input**: `/specs/018-fap-p00-boundary-audit/`. **Tests** are required: the shared contract check, the shell
smoke test on both simulators (enumeration-guarded) and the reference regression. IDs are `T-A02-0##`, with one
commit and push per task (`scripts/tick_task.py`). Review checkpoint: after each phase, `validate_docs.py` and
`check_app_contract.py --app fluid-art-playground` pass.

## Phase 1: Setup

- [X] T-A02-001 Create `docs/apps/fluid-art-playground/regression-baseline.md` with the phase-start commit — Verified 2026-11-11 (corrected): the first tick (commit faf1198) was recorded although the file had not been written (a failed shell step); the file now exists with phase-start commit 06091bb (git cat-file -t: commit) and the reference pin d93edd1 (git -C External/projectm-ios rev-parse --short HEAD); validate_docs PASS
  `06091bb` and the reference pin `d93edd1`, so the no-change diff for `Packages/` and `External/` (FR-A02-007) has
  a base.

## Phase 2: US1 — Evidence-backed integration matrix (P1) 🎯

- [ ] T-A02-002 [US1] Write `docs/apps/fluid-art-playground/visualcore-contract.json` (schema 1, app
  `fluid-art-playground`, gate A02-P00):
  - `inventory` covering every area in FR-A02-001, each with paths;
  - `matrix` rows M01–M10 per research R1–R10. Six brainstorm rows: ping-pong, feedback, GPU simulation,
    advection/diffusion, touch forces, blending/post. Four v0.1 rows: quality/thermal, pause/reset/seeded,
    still capture, float targets.

  Each row cites only public non-test symbols, with an example consumer. The shared checker requires one on every
  row, so upstream-gap rows cite the closest existing consumer (analyze I1). Render it to `visualcore-contract.md` with
  `--render`. Run `check_app_contract.py --app fluid-art-playground` (SC-A02-001, SC-A02-002).

## Phase 3: US2 — Host, thread, build and regression baseline (P1)

- [ ] T-A02-003 [US2] Run the 7-step reference regression in two `run-check` chunks (A02-P00), and record the steps,
  commands and results in `docs/apps/fluid-art-playground/regression-baseline.md` (FR-A02-004, SC-A02-004).

## Phase 4: US3 — Compilable empty app shell (P1)

- [ ] T-A02-004 [US3] Add the shell:
  - `Apps/FluidArtPlayground/App/FluidArtPlaygroundApp.swift`: an @main SwiftUI app with `HomeView`, title "Fluid
    Art Playground", identifier `fap.home.title`, accessibility label and header trait;
  - `Apps/FluidArtPlayground/Generated/{Info,UITests-Info}.plist`;
  - `project.yml` targets `FluidArtPlayground` (bundle `dev.visualcore.FluidArtPlayground`, iOS 26.0, version
    0.1.0, the dependency-audit post-build script for the new target, no VisualCore product yet, no usage
    descriptions) and `FluidArtPlaygroundUITests`, plus the scheme.
- [ ] T-A02-005 [US3] Add `Apps/FluidArtPlayground/Tests/UI/LaunchSmokeUITests.swift` (launch, title exists, label
  "Fluid Art Playground"). Run it on iOS 27.2 and 26.5, enumeration-guarded (SC-A02-003, FR-A02-006).

## Phase 5: US4 — Gap register and stop/go decision (P2)

- [ ] T-A02-006 [US4] Complete the contract JSON:
  - `gaps` for every non-available row, with an owner module, a phase and a test;
    the ping-pong gap's test MUST reject binding the read target as the write target (A02 rule; analyze C1);
  - `traceability` for v0.1 features 01–06 and journeys 1–3;
  - `negative` rules (FR-A02-011);
  - `decision` go/stop with reasons.

  Render it and run the check (FR-A02-008–011, SC-A02-005, SC-A02-007).

## Phase 6: Polish

- [ ] T-A02-007 Confirm that `git diff --stat 06091bb..HEAD -- Packages External` is empty (SC-A02-006). Run the
  release-check fast steps (docs, app-contracts, compliance, dependencies, licenses) and the documented-API check for
  `Apps/FluidArtPlayground`.

## Dependencies

T-A02-001 → T-A02-002 → T-A02-006; T-A02-003 is independent; T-A02-004 → T-A02-005; T-A02-007 runs last.

## Implementation strategy

The matrix first (US1), then the baseline, the shell and the decision, reusing the A01-P00 tooling unchanged.

## Analyze remediation (2026-11-11)

Applied autonomously (CLAUDE.md §2): I1 → T-A02-002 example on every row; C1 → T-A02-006 ping-pong test intent. 0
critical issues.
