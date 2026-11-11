---

description: "Task list for feature 010 — Phase 9 stabilization and release (ledger gate F09)"
---

# Tasks: Phase 9 — Stabilization, Documentation and Release

**Input**: `/specs/010-stabilization-release/` · **Tests**: required (script tests, simulator validation, automation runs,
Release symbol check). IDs `T-F9##`. One commit + push per task.

## Phase 1: US1 — public API (P1) 🎯

- [X] T-F901 [US1] `scripts/check_public_api.py` (+ tests in `scripts/test_scripts.py` with fixtures `scripts/fixtures/public_api/`): documentation comment on every public declaration, surface vs `docs/api/visualcore-public-api.txt`, `--update`; first run reports the undocumented declarations — Verified 2026-11-10: F09.t901-public-api-tests: 35 script tests OK (undocumented method named, baseline added/removed detection, usage error); first real run: 618 public declarations, 458 undocumented (fixed in T-F902)
- [ ] T-F902 [US1] Document every flagged public declaration in `Packages/*/Sources`, then generate and commit the baseline; check passes

## Phase 2: US4 — automation (P2)

- [ ] T-F903 [US4] `Packages/VisualCoreRendering/Sources/VisualCoreAutomation/{AutomationRunner,AutomationReport}.swift` (whole module under `DEBUG || VISUALCORE_AUTOMATION`; modes smoke/launch/lifecycle; JSON report; injectable terminator) with simulator tests `Packages/VisualCoreRendering/Tests/VisualCoreAutomationTests/` (each mode, unknown mode error, report fields)
- [ ] T-F904 [US4] Showcase integration (launch with `VISUALCORE_AUTORUN` runs the mode on a gradient scene and exits) + `scripts/run_automation_sim.py` (simctl launch with `SIMCTL_CHILD_*` env, copy report from the app container); Release build of the Showcase: `nm -U` shows 0 automation symbols

## Phase 3: US3 — verification (P1)

- [ ] T-F905 [US3] Shader validation: `ShaderValidationTests` in VisualCoreRendering/VisualCoreEffects (every built-in program) and in Showcase unit tests (every bundled shader; `broken.frag` must fail with file/line) on iOS 27.2 and 26.5
- [ ] T-F906 [US3] Cleanup sweep: a test that runs every Showcase scene, the InteractiveDemo scene and the Lumen Garden scene through setup → frames → context loss → frames → destroy and asserts 0 leaked
- [ ] T-F907 [US3] `scripts/check_licenses.py` (+ tests) and `docs/legal/{THIRD_PARTY_NOTICES.md,lgpl-analysis.md}`
- [ ] T-F908 [US3] `scripts/release_check.py` (+ tests for the runner logic): runs public API, licenses, docs, compliance, dependency rules, documented API (all consumers), script tests, host tests (VisualCore, GardenKit), rendering/effects sims both runtimes, Showcase/InteractiveDemo/SecondConsumer/ProjectMReference tests, reference regression + clean, Release symbol check; per-step summary and JSON

## Phase 4: US2 + US5 — documentation and release (P1/P2)

- [ ] T-F909 [US5] Performance baselines: `VisualCoreBaselines` executable → `docs/performance/baselines-host.json`; automation smoke/launch on both simulators → `docs/performance/baselines-simulator.json`; `docs/performance/README.md` (environment, not device evidence)
- [ ] T-F910 [US2] `docs/release/support-matrix.md` and `docs/release/known-limitations.md`
- [ ] T-F911 [US5] `docs/index.md`, `docs/getting-started.md` (module overview, samples: Showcase and Lumen Garden), links from README
- [ ] T-F912 [US5] `.github/workflows/ci.yml` (docs, compliance, dependencies, script tests, public API, licenses, host swift tests); push and confirm the run with `gh run list`/`gh run watch`
- [ ] T-F913 [US5] Version `1.0.0-rc.1` in every module's version constant and `docs/release/release-notes-1.0.0-rc.1.md`
- [ ] T-F914 Full release check run end to end; record the summary
- [ ] T-F915 {device} Device rows of the support matrix and device baselines — **deferred to campaign II** (constitution V)

## Dependencies

T-F901 → T-F902; T-F903 → T-F904; T-F905/T-F906/T-F907 → T-F908; T-F909 needs T-F904; T-F910–T-F913 after; T-F914 last.
