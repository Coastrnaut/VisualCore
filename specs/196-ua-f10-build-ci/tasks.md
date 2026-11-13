# Tasks: UA-F10 — Build, project and CI consolidation

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/tools.md](contracts/tools.md), [quickstart.md](quickstart.md)

Evidence: `python3 scripts/migration_ledger.py run-check --gate UA-F10 --name <check> -- <command>`. Commit after each
task (`scripts/tick_task.py`), push through `prepush_scan.py --push`, check CI with `gh run list` between tasks, never
wait. No VisualCore framework change is planned; if one happens, T-U10-030 applies. Device-only items: none.
Owner-only items: none.

## Phase 1: Setup

- [X] T-U10-001 Record the read-only audit and decisions as research.md sections 1–3 (done in `/speckit-plan`); re-run — Verified 2026-11-13: research.md sections 1-3 written in /speckit-plan; release_check.py --only dependencies script-tests PASS (baseline-tools); release_check.py --list read
  `python3 scripts/check_dependencies.py`, `python3 scripts/test_scripts.py` and `python3 scripts/release_check.py --list`
  as the starting point (check `baseline-tools`).

## Phase 2: Foundational

- [X] T-U10-002 Add `--parallel N` to `scripts/xcodebuild_app.py` (adds `-parallel-testing-enabled YES — Verified 2026-11-13: xcodebuild_app.py --parallel N adds -parallel-testing-enabled YES -parallel-testing-worker-count N (script tests 322 OK); the guard reads the clone log format (Test case 'C.m()' passed on 'Clone …'); real run of chunk d on the iOS 27.2 phone with --parallel 2 and test-without-building: 15/15 passed on clones (parallel-chunk-d-r2)
  -parallel-testing-worker-count N` for N > 1; N ≥ 1) with script tests first in `scripts/test_scripts.py`
  (FR-U10-040; owner ruling of 2026-11-13).

## Phase 3: User Story 1 — Every push proves the one app builds (P1)

Independent test: a clean commit passes the CI job `app-build`; a scratch commit breaking only Release fails it.

- [ ] T-U10-003 [US1] Script tests first for `make_ci_angle_standins.py` in `scripts/test_scripts.py`: the 16
  prototypes of `CVisualCoreEGL.h` (line 71 `eglGetPlatformDisplay` … line 87 `eglGetProcAddress`) are parsed; the
  generated C defines each with `abort()` and `vc_ci_angle_standin`; an output folder holding a framework without the
  marker is refused (exit 2).
- [ ] T-U10-004 [US1] Write `scripts/make_ci_angle_standins.py --out DIR`: generate the C file, compile
  `arm64` and `x86_64` simulator slices with `xcrun clang -target <arch>-apple-ios26.0-simulator -dynamiclib`, set
  the install name `@rpath/libEGL.framework/libEGL`, build `libEGL.framework` and an empty `libGLESv2.framework`, and
  wrap each with `xcodebuild -create-xcframework` (FR-U10-002; research R1). Prove locally that the app compiles
  against them: copy the tracked files (`git archive HEAD`) into `Build/standin-check/` (no submodule there),
  generate the stand-ins into its `External/projectm-ios/Build/ANGLEFrameworks`, and build with
  `-derivedDataPath Build/DerivedData/ua-f10-standin`; the real submodule is never touched (check
  `standin-local-build`).
- [ ] T-U10-005 [US1] Add the CI job `app-build` to `.github/workflows/ci.yml`: timeout 45 min, the `ci` concurrency
  group, no submodule checkout (the read-only submodule stays uninitialized; its path is an empty folder), generate
  the stand-ins into `External/projectm-ios/Build/ANGLEFrameworks` inside that empty folder, install XcodeGen 2.46.0, `xcodegen generate`, then
  `xcodebuild build-for-testing` (Debug, scheme `VisualCore`, `generic/platform=iOS Simulator`,
  `CODE_SIGNING_ALLOWED=NO`) and `xcodebuild build -configuration Release` (FR-U10-001, FR-U10-004).
- [ ] T-U10-006 [US1] Acceptance: push; `gh run list --workflow ci` shows `app-build` success for a clean commit; push
  a scratch commit that adds a debug-only call into a Release path of an experience file, observe `app-build` failing
  with the compile error, then `git revert` it and observe success (SC-U10-001). Record the two run ids in research.md
  section 4 (no `gh run watch` on a queued run).

## Phase 4: User Story 2 — One shippable application, checked (P1)

Independent test: planted second shippable target, undeclared target and reused bundle id each fail.

- [ ] T-U10-007 [P] [US2] Script tests first for `check_app_targets.py` (three planted defects, a gate in
  `until_gate` that is pass, a damaged and a newer-schema list).
- [ ] T-U10-008 [US2] Write `Configs/app-targets.json` (schema 1, data-model.md: "exactly one `ships: true`; names
  unique; bundles unique; every application target of `project.yml` listed and nothing else; `until_gate` pass in the
  migration ledger → failure") and `scripts/check_app_targets.py`; add it to the `checks` job of `ci.yml` and to
  `release_check.py` as step `app-targets` (FR-U10-010, FR-U10-011).
- [ ] T-U10-009 [US2] Acceptance: `python3 scripts/check_app_targets.py` passes with 1 shippable app (check
  `app-targets`); the three planted defects fail in the script tests (SC-U10-002).

## Phase 5: User Story 3 — Experience packages match the catalog (P2)

- [ ] T-U10-010 [P] [US3] Script tests first for `check_experience_packages.py`: missing target, extra target,
  unknown id, a registered experience whose product the app does not link, a linked product without registration,
  damaged or newer-schema catalog.
- [ ] T-U10-011 [US3] Write `scripts/check_experience_packages.py` (research R3: code prefix → package, catalog name in
  upper camel case, four targets, product linked by `VisualCore` in `project.yml`, registrations as the implemented
  set); add it to `ci.yml` `checks` and `release_check.py` as `experience-packages` (FR-U10-020 to FR-U10-022).
- [ ] T-U10-012 [US3] Acceptance: passes on the tree with 4 of 4 experiences (check `experience-packages`); the planted
  defects fail (SC-U10-003).

## Phase 6: User Story 4 — Experiences stay independent (P2)

- [ ] T-U10-013 [P] [US4] Script tests first for rules R6, R7, R8 of `check_dependencies.py` in a temporary tree.
- [ ] T-U10-014 [US4] Add R6–R8 to `scripts/check_dependencies.py` (research R4) and its docstring (FR-U10-030).
- [ ] T-U10-015 [US4] Acceptance: `python3 scripts/check_dependencies.py` passes (check `dependencies`); 3 of 3 planted
  defects fail (SC-U10-004).

## Phase 7: User Story 5 — Local checks of the one app in short chunks (P2)

- [ ] T-U10-016 [US5] Script tests first for the new `release_check.py` steps: names, limits below 600 s, one
  `verify-<id>-ios27/26` per registration, no audit class in any interface chunk, `app-release-symbols` forbids
  `vc_ci_angle_standin`.
- [ ] T-U10-017 [US5] Add the unified-app steps to `scripts/release_check.py` (research R5): `app-build-for-testing-ios27`,
  `app-unit-ios27`, `app-ui-ios27-<chunk>` (the UA-F07 chunk table without the four audit classes),
  `verify-<id>-ios27/26` from `Catalog/registrations.json`, `app-release-build`, `app-release-symbols`,
  `app-privacy-manifest`, `measure-build`; replace the whole-scheme `app-visual-core-ios27/26` steps (FR-U10-040 to
  FR-U10-042).
- [ ] T-U10-018 [US5] Acceptance: `release_check.py --only app-release-build app-release-symbols app-privacy-manifest`
  (check `release-app`) and `--only app-build-for-testing-ios27 app-unit-ios27` (check `release-unit`), each step under
  600 s; one interface chunk through the new step (check `release-ui-a`) (SC-U10-005).

## Phase 8: User Story 6 — Build time and size at milestones (P3)

- [ ] T-U10-019 [P] [US6] Script tests first for `measure_build.py` with a fake runner: one record appended, a second
  run for the same commit skipped, a damaged or newer-schema file refused without a write.
- [ ] T-U10-020 [US6] Write `scripts/measure_build.py` (research R6; data-model.md "Append only; one record per commit;
  damaged or newer schema → refusal and no write") and `docs/performance/build-measurements.json`; point the
  budgets.md row to it (FR-U10-050, FR-U10-051).
- [ ] T-U10-021 [US6] Acceptance: `python3 scripts/measure_build.py --milestone UA-F10` appends one record (check
  `measure-build`); `--check` passes (SC-U10-006).

## Phase 9: Polish and cross-cutting

- [ ] T-U10-022 Auto-Creator.md sections 16 and 24.1 as built, edited in place; `render_autocreator.py --check` and
  `validate_autocreator.py` (check `steering`).
- [ ] T-U10-023 Leak check: `check_release_symbols.py` on the local Release app forbids `vc_ci_angle_standin`
  (check `standin-leak`, SC-U10-007).
- [ ] T-U10-024 Evidence `quickstart-fast`: `check_app_targets.py`, `check_experience_packages.py`,
  `check_dependencies.py`, `measure_build.py --check`, `test_scripts.py`.
- [ ] T-U10-025 Evidence `core-a01` … `core-a04`: the Core test targets on sim-27.2 with `xcodebuild_package.py
  --only-testing <Name>CoreTests` (the quickstart's equivalent of `swift test --package-path <Core>`).
- [ ] T-U10-026 Evidence `verify-a01-a03`: `verify_experiences.py --only a01.generative-art-studio
  a02.fluid-art-playground a03.fractal-explorer --runtime 27 26`.
- [ ] T-U10-027 Evidence `reference-a` and `reference-b`: the two chunks of the reference regression.
- [ ] T-U10-028 Evidence `docs`, `steering`, `script-tests`, `legacy-ledger` (`migration_baseline.py verify`), and a
  finished `ci` run with success for a commit containing all UA-F10 changes.
- [ ] T-U10-029 Run `/speckit-converge` and `/speckit-implement` for what it appends; repeat until it appends nothing;
  then `migration_ledger.py seal --gate UA-F10` and `record --gate UA-F10`.

Conditional:
- [ ] T-U10-030 Only if a VisualCore framework source changes: `check_public_api.py --update`,
  `check_documented_api.py --sources Apps/VisualCore`, and the reference regression after the change.

## Dependencies

Setup → Foundational → US1 and US2 (P1, independent) → US3, US4, US5 (independent; US5 uses T-U10-002) → US6 →
Polish. US1's CI acceptance (T-U10-006) runs whenever a hosted runner is free; nothing waits for it.

## Parallel opportunities

The script-test tasks marked [P] (T-U10-007, T-U10-010, T-U10-013, T-U10-019) touch different test classes of
`scripts/test_scripts.py` and are written one at a time by the lead (one writer per file); their tool files are
independent and may be drafted by agents in parallel.

## Implementation strategy

MVP is US1 and US2: a push proves the app builds, and the project keeps one shippable app. The rest lands as
separate commits.

## Analysis

- **Run 1 (2026-11-13)**: D1 CRITICAL, the CI job wrote into the read-only submodule; fixed: the submodule stays
  uninitialized in the app-build job and the stand-ins go into its empty folder. C1 HIGH, the local stand-in proof
  was unclear; fixed: a copy of the tracked files under `Build/standin-check/`. F1 MEDIUM, the numbering gap; fixed.
  U1 LOW (FR-U10-051 is a review rule) accepted.
- **Run 2 (2026-11-13)**: 21 of 21 requirements and 7 of 7 criteria covered; no critical or high finding.
