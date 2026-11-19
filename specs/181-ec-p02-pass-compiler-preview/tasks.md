# Tasks: Effects Composer — Phase 02 Linear pass compiler and preview

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/experience.md](contracts/experience.md), [quickstart.md](quickstart.md). Gate A25-P02 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A25-P02 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** no VisualCore change; the experience is a candidate only.
- **Precedent:** `specs/174-gbl-p02-workload-renderers/tasks.md`.
- **Rollback:** revert the commits.

## Phase 1: Setup

- [X] T-A25-201 Baseline: cite the A25-P01 evidence (`.autonomy/checks/A25-P01.{ec-core-ios27,app-build,experience-packages}.json`) — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P01.{ec-core-ios27,app-build,experience-packages}.json exit 0
- [X] T-A25-202 In `Packages/ExperiencesCreative/Package.swift` (lead): the targets `EffectsComposerExperience` (path — Verified 2026-11-19: 2026-11-19 EffectsComposerExperience(+Tests) and product; .autonomy/checks/A25-P02.experience-packages-2.json exit 0 (after registration)
  `EffectsComposer/Experience`; the core, VisualCoreExperience, VisualCorePersistence, VisualCoreRendering,
  VisualCoreExperienceHost, VisualCoreUI) and `EffectsComposerExperienceTests`, and the library product
  `EffectsComposerExperience`

## Phase 2: Story 1 — a chain becomes an ordered set of passes (P1) 🎯

- [X] T-A25-203 [P] [US1] Create `Packages/ExperiencesCreative/EffectsComposer/Core/PassPlan.swift` per clarification Q1 and add `TestImage.make(size:)` (`make()` — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P02.ec-ios27.json exit 0 (42 core and 27 experience tests on sim-27.2); PassPlan per clarification Q1, TestImage.make(size:)
  stays 64 × 64) to `Packages/ExperiencesCreative/EffectsComposer/Core/TestImage.swift`
- [X] T-A25-204 [US1] Write `Packages/ExperiencesCreative/EffectsComposer/CoreTests/PassPlanTests.swift`: empty, single, all-disabled, mixed and full chains; no pass — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P02.ec-ios27.json exit 0 (42 core and 27 experience tests on sim-27.2); PassPlanTests 7: every chain shape, no pass reads its output, at most two live slots
  reads its output; each slot ends at its single reader; at most two slots; the 256 × 256 test image keeps the pattern
  (SC-A25-201)

## Phase 3: Stories 2 and 3 — the preview follows every edit; disabled is identity (P1)

- [X] T-A25-205 [US2] Create `Packages/ExperiencesCreative/EffectsComposer/Experience/Adapter/ComposerCore.swift` per clarification Q3 (snapshot schema 1, digest — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P02.ec-ios27.json exit 0 (42 core and 27 experience tests on sim-27.2); ComposerCore schema 1, seven actions, rule ids
  `a25.effects-composer.v1`, the seven actions, rule ids)
- [X] T-A25-206 [US2] [US3] Create `Packages/ExperiencesCreative/EffectsComposer/Experience/{PreviewRenderer,ComposerPresenter,ECControls,EffectsComposerExperience}.swift` — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P02.ec-ios27.json exit 0 (42 core and 27 experience tests on sim-27.2); preview renderer, presenter, inline controls with spoken labels
  per clarifications Q2, Q4 and Q5 (programs built in setup, pooled targets, plan recompiled on a fingerprint change,
  present pass, diagnostics, the test seams `programOverride` and `lastResult`, the inline controls with spoken labels)
- [X] T-A25-207 [US2] [US3] Write `Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/{ComposerTestSupport,ComposerCoreTests,PreviewDrawTests,IdentityTests}.swift`: — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P02.ec-ios27.json exit 0 (42 core and 27 experience tests on sim-27.2); every edit kind matches the reference (max 0/255, 1/255 with distort), undo byte-identical, disabled effect identical (0/255)
  every action and refusal; the snapshot round-trips the chain and a restored core starts with an empty history; the
  spoken labels of a node row and a value control name the effect, its position and the value; after each edit kind the next frame's result matches `EffectReference.apply(chain:)` within
  2/255 (4/255 with distort) and undo restores it byte for byte; a chain with one more disabled effect draws the same
  picture (SC-A25-202, 203)

## Phase 4: Stories 4 and 5 — diagnostics and a bounded pool (P2)

- [X] T-A25-208 [US4] [US5] Write `Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/{DiagnosticTests,PoolTests}.swift`: a broken program for one effect — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P02.ec-ios27.json exit 0 (42 core and 27 experience tests on sim-27.2); a broken Blur gives 'Blur, line 8: ...' and keeps the last good picture; 50 cycles, 10 rebuilds and a resize leave 11 live objects and 1,048,576 bytes; a25.pool-cap refusals
  gives one diagnostic with the effect and a line and the result is unchanged; 50 edit-and-draw cycles and 10
  `recreateContext` calls and a resize leave `ResourceRegistry.stats` live counts and bytes equal to those after the
  first draw; a request above the pool cap is refused with `a25.pool-cap` (SC-A25-204, 205)

## Phase 5: Registration and verification

- [X] T-A25-209 Write `Packages/ExperiencesCreative/EffectsComposer/Experience/Adapter/ECManifest.swift` (the standard scenarios plus a fixture per effect) and — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P02.ec-ios27.json exit 0 (42 core and 27 experience tests on sim-27.2); ECManifest 9 standard scenarios and 5 fixtures; scenario-manifest.json generated and confirmed
  `Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/ECManifestTests.swift`; generate `Packages/ExperiencesCreative/EffectsComposer/scenario-manifest.json` with `UPDATE_SCENARIO_MANIFEST=1
  TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`
- [X] T-A25-210 Register the candidate (FR-A25-207): — Verified 2026-11-19: 2026-11-19 a25 registered as a candidate (5 capabilities, 253-character summary with 'shader', permissions photo-library-add); .autonomy/checks/A25-P02.{catalog-search-2,experience-packages-2,script-tests,app-unit}.json exit 0; synthetic candidate r02-g01.aurora-loom
  - a `Catalog/registrations.json` entry for a25 (capabilities of at most 40 characters, a summary of at most 300
    characters keeping the words CatalogSearchTests searches for, quality_tiers ["level-0"], a palette, the manifest,
    permissions ["photo-library-add"]); then `python3 scripts/build_catalog.py` and `swift test --package-path
    Packages/VisualCore --filter CatalogSearchTests`;
  - in `Apps/VisualCore/App/ExperienceRegistry.swift`, the candidate `effectsComposer`; the `project.yml` product;
  - in `Apps/VisualCore/Tests/Unit/AppModelTests.swift`, the synthetic candidate id moves to `r02-g01.aurora-loom`;
  - the candidate lists in the app and script tests.
- [ ] T-A25-211 Review checkpoint:
  - `--name ec-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme
    ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing EffectsComposerCoreTests
    EffectsComposerExperienceTests`, each test under 10 s (SC-A25-206);
  - the documented API, the isolation check and the core purity scan.
- [ ] T-A25-212 Contract: G-COMPILER, G-POOL and G-DIAG are closed by "A25-P02", and rows whose gaps are all closed
  become available with evidence (`--name contract`)
- [ ] T-A25-213 The catalog, app and runner checks, with the packages and script tests:
  - `--name catalog`; `--name experience-packages`; `--name script-tests`;
  - `xcodegen generate --spec project.yml`, then `--name app-unit -- python3 scripts/release_check.py --only
    app-build-for-testing-ios27 app-unit-ios27`;
  - `--name verify-27 -- python3 scripts/verify_experiences.py --only a25.effects-composer --runtime 27`.
- [ ] T-A25-214 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A25-P02; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

201 → 202 → {203, 205}; 203 → 204; {203, 205} → 206 → {207, 208, 209}; 209 → 210 → 211 → 212 → 213 → 214.

## Parallel examples

- **Agent C:** 203, 204.
- **Agent X:** 205–209.
- **Agent G:** 210 after 209.
- **Lead:** 201, 202, the runs, the contract and the commits.

## Implementation strategy

- **MVP:** the compiler (203, 204) and the preview with actions (205–207).
- **Then:** diagnostics and the pool (208), registration (209, 210).
- **Review checkpoint:** at 211.
- **Commits:** one per task.
