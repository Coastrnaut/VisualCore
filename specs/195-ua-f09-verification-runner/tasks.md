# Tasks: UA-F09 — Experience verification runner and evidence schema

**Input**: Design documents from `specs/195-ua-f09-verification-runner/` (spec.md, plan.md, research.md,
data-model.md, contracts/verification-api.md, quickstart.md)

**Base commit**: `7bc756b` (the API baseline and the boundaries are compared with it).

**Tests**: required by the specification and constitution IV: every test task comes before the code it proves.

**Evidence**: `python3 scripts/migration_ledger.py run-check --gate UA-F09 --name <check-name> -- <command>`.
A task is ticked as `- [X] <id> … — Verified YYYY-MM-DD: <command and result>` after its proof was reproduced.
Commit after every task (`python3 scripts/tick_task.py`), and push with `python3 scripts/prepush_scan.py --push`.

**Device-only and owner-only items**: none (the specification lists none), so no `{device}` or `{owner}` task.

## Phase 1: Setup

- [X] T-U09-001 [P] Add `--result-name NAME` to `scripts/xcodebuild_app.py`, which writes `-resultBundlePath .autonomy/xcresults/NAME.xcresult` and removes an older bundle of that name first. Script tests in `scripts/test_scripts.py`: the command line carries the path; without the option, nothing changes (FR-U09-023). — Verified 2026-11-12: python3 scripts/test_scripts.py: Ran 243 tests, OK (test_result_name_adds_the_result_bundle_path); one ledger-dependent prompt-coverage test now uses UA-F13, which stays open

## Phase 2: Foundational (pure types; blocking every story)

- [X] T-U09-002 [P] Tests first: `Packages/VisualCore/Tests/VisualCoreExperienceTests/OutcomeTests.swift`. Cover: — Verified 2026-11-12: swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests: 379 tests in 35 suites passed (OutcomeTests)
  - `ExperienceOutcome(code:)` accepts 1 to 64 characters of `a-z 0-9 -` and refuses others.
  - A core without `outcome` gives nil.
  - The sample reports `target-reached` only after moves bring the marker onto the target, and nil before.
  - Neither the sample's golden digests nor `scenarioDigest` change.
  - `ExperienceDiagnostics` encodes `outcome` only when present and decodes an older encoding without it.
- [X] T-U09-003 Implement `Packages/VisualCore/Sources/VisualCoreExperience/ExperienceOutcome.swift` (release). Add `outcome` to `ExperienceCore` (default nil, computed, never stored), to `ExperienceEngine` and to `ExperienceDiagnostics`. In `Packages/VisualCore/Sources/VisualCoreTestSupport/SampleExperienceCore.swift`, the sample reports `target-reached` while marker equals target. T-U09-002 passes (FR-U09-004). — Verified 2026-11-12: swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests: 379 tests in 35 suites passed; the sample's golden digests unchanged
- [X] T-U09-004 [P] Tests first: `Packages/VisualCore/Tests/VisualCoreExperienceTests/ScenarioManifestTests.swift`. Cover: — Verified 2026-11-12: swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests: 379 tests in 35 suites passed (ScenarioManifestTests)
  - Loading of schema 1.
  - Refusal of schema 2 (`newerSchema`), of more than 4 MiB and of damaged JSON.
  - The validator finds each problem: a missing standard scenario (names it), a duplicate name, a name outside 1–64 `a-z 0-9 -`, more than 1,000 scenarios, more than 10,000 entries, an unknown control, a wrong value count, and an expected outcome or digest with no action before it.
  - A creative experience needs `content.fixtures` scenarios named `fixture-…`.
  - A Round 2 game needs `full-playthrough`, `hero` and 80 `acceptance-…` scenarios. Rounds 3 and 4 also need 50 `fault-…` scenarios. Fixture manifests pass with 80 or 50 and fail with 79 or 49.
- [X] T-U09-005 Implement `ScenarioManifest.swift` and `ScenarioManifestValidator.swift` in `Packages/VisualCore/Sources/VisualCoreExperience/` (inside `#if DEBUG || VISUALCORE_AUTOMATION`), as data-model section 2 gives them. Entries convert to the existing `ExperienceScenario`. T-U09-004 passes (FR-U09-001, FR-U09-002, FR-U09-003, FR-U09-005). — Verified 2026-11-12: swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests: 379 tests in 35 suites passed
- [X] T-U09-006 [P] Tests first: `ScenarioEvaluatorTests.swift`. Cover: — Verified 2026-11-12: swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests: 379 tests in 35 suites passed (ScenarioEvaluatorTests)
  - Each expectation kind passes and fails with a named message: a step result, a step digest, the initial, final, after-restore and after-reset digests, the outcome, and a probe.
  - `actionsHandled != actionsSent` fails as "bypass".
  - An observation with failures cannot pass.
- [X] T-U09-007 Implement `ScenarioObservation.swift` (observation and `ScenarioEvaluator`, `#if`). T-U09-006 passes (FR-U09-003, FR-U09-010, FR-U09-052). — Verified 2026-11-12: swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests: 379 tests in 35 suites passed
- [X] T-U09-008 [P] Tests first: `FrameChecksTests.swift`. Cover: — Verified 2026-11-12: swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests: 379 tests in 35 suites passed (FrameChecksTests; pure blue (0,0,255) classifies dark by luma, recorded)
  - `isNonBlank` is false for one colour or a spread below 8 of 255, and true for a gradient.
  - `isBlack` treats at most 4 of 255 as black.
  - The histogram has 16 bins summing to the pixel count.
  - `hasNonFinite` finds NaN and infinity.
  - `silhouette` gives the bounding box and nil for an empty frame.
  - `classify` gives `dark`, `light`, `red`, `green`, `blue` or `other`.
  - `FrameProbe` x and y lie in 0…1.
- [X] T-U09-009 Implement `FrameChecks.swift`. `FrameProbe` is release; the checks are inside `#if`. T-U09-008 passes (FR-U09-040, FR-U09-042). — Verified 2026-11-12: swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests: 379 tests in 35 suites passed
- [X] T-U09-010 [P] Tests first: `ScenarioRequestTests.swift`. Cover: — Verified 2026-11-12: swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests: 379 tests in 35 suites passed (ScenarioRequestTests, EvidenceRecordTests)
  - No `VISUALCORE_AUTORUN`, or another value, is no request.
  - `scenario` with experience, scenario, seed, run, phase and expected digest parses.
  - A missing experience, a bad seed, a run id outside 1–64 `A-Za-z0-9-`, an unknown phase or a bad digest each give a typed error.
  - Values over 256 characters are refused.
  - `EvidenceRecord` encodes the field names of data-model section 4 with sorted keys and decodes them.
- [X] T-U09-011 Implement `ScenarioRequest.swift` and `EvidenceRecord.swift` (`#if`). T-U09-010 passes (FR-U09-011, FR-U09-030). — Verified 2026-11-12: swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests: 379 tests in 35 suites passed
- [X] T-U09-012 Record the API of Phase 2 with `python3 scripts/check_public_api.py --update`: 0 undocumented and no baseline line lost since `7bc756b`. Proof: `swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests` passes. — Verified 2026-11-12: check_public_api.py --update then check: PASS, 0 undocumented, 0 baseline lines removed since 7bc756b; swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests: 379 tests in 35 suites passed

**Checkpoint**: the pure layer is complete and host-tested.

## Phase 3: User Story 2 - Every experience carries its scenarios as domain actions (Priority: P1)

**Goal**: a runner plays a manifest's scenarios through a real session; the sample's nine pass and its faults fail.

**Independent test**: `ScenarioRunnerTests` on both simulator runtimes.

- [X] T-U09-013 [US2] Tests first: `Packages/VisualCoreRendering/Tests/VisualCoreExperienceHostTests/ScenarioRunnerTests.swift` with the fixture `Fixtures/sample-manifest.json` (nine scenarios; seeds and digests from the sample's committed goldens). Cover: — Verified 2026-11-12: xcodebuild_package.py VisualCoreRendering --only-testing VisualCoreExperienceHostTests on sim-27.2 and sim-26.5: 144 tests, 0 failures each (ScenarioRunnerTests 15: nine standard scenarios pass; LossySnapshot fails save-restore, WrongReset fails reset, a blank frame and a wrong probe fail; endurance 3,600 frames flat)
  - Each of the nine passes with `SamplePresenter<NoFault>`.
  - `LossySnapshot` fails save-restore and `MutatingRejection` fails rejection, each with the named expectation.
  - A presenter that draws black fails launch-first-frame with "blank", and a probe expecting `red` on a blue frame fails.
  - teardown-reentry runs 5 cycles with zero live and leaked objects. cancel-prepare uses `SlowPreparation` and the result is `.cancelled`. suspend-resume uses a scripted time source, with no step for the time away.
  - An `endurance` scenario (the manifest names its seconds, 1 to 600) runs in the same class, outside the default run, and passes by the UA-F06 growth rule. A presenter that declares no probe fails launch-first-frame with "no probe declared". Each test attaches its record as `evidence-a99.contract-sample-<scenario>.json`.
  - The test-target manifest must be added to the package resources.
- [X] T-U09-014 [US2] Add `probes(_:)` (default empty) to `ExperiencePresenter` and `frameProbes` to `Experience`, forwarded by `ExperienceShell`. Implement `Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost/ScenarioRunner.swift` (`#if`), using the session calls of research R3. The sample presenter declares one probe. Update the API baseline. The runner fails launch-first-frame when the experience declares no probe. It runs `endurance` by the UA-F06 growth rule. T-U09-013 passes on the iOS 27.2 and 26.5 simulators (FR-U09-005, FR-U09-010, FR-U09-013, FR-U09-014, FR-U09-040, FR-U09-060; SC-U09-002). — Verified 2026-11-12: xcodebuild_package.py VisualCoreRendering --only-testing VisualCoreExperienceHostTests on sim-27.2 and sim-26.5: 144 tests, 0 failures each (ScenarioRunnerTests 15: nine standard scenarios pass; LossySnapshot fails save-restore, WrongReset fails reset, a blank frame and a wrong probe fail; endurance 3,600 frames flat); check_public_api.py --update: 2174 lines, 0 undocumented, 0 lines lost since 7bc756b

## Phase 4: User Story 4 - Evidence records are complete, versioned and checked (Priority: P1)

- [X] T-U09-015 [P] [US4] Tests first in `scripts/test_scripts.py` (class `EvidenceValidatorTests`). Cover: — Verified 2026-11-12: python3 scripts/test_scripts.py: Ran 243 tests, OK (EvidenceValidatorTests)
  - A valid simulator record passes.
  - Each of these is rejected by name: each field group missing (14), a wrong type, schema 0 or 2, a bad hash, a `result` outside three values, a pass with failures, a pass without steps or digests, a drawing pass without a frame, a UDID-shaped value, an ECID-shaped value, and `environment.kind` other than simulator or device.
  - A device record without identifiers passes, so the format stays usable on devices (FR-U09-062).
- [X] T-U09-016 [US4] Implement `scripts/check_evidence.py` (validator; `--self-test`; exit 0 or 1). T-U09-015 passes (FR-U09-030 to FR-U09-032; SC-U09-003). — Verified 2026-11-12: python3 scripts/test_scripts.py: Ran 243 tests, OK; python3 scripts/check_evidence.py --self-test: PASS (43 cases)

## Phase 5: User Story 3 - The app runs one scenario and exits (Priority: P1)

- [X] T-U09-017 [US3] Tests first: `Apps/VisualCore/Tests/Unit/ScenarioLaunchTests.swift`. Cover: — Verified 2026-11-12: xcodebuild_app.py 27.2 phone: chunk c + ScenarioLaunchTests 69/69 (all nine debug scenarios through the app's run path, two-launch save-restore, error records with exit 2); interface chunks a, b, d, e, f pass. Correction recorded: the debug experience runs under its own non-catalog id a98.debug-experience (not under a fixture id), so the driver alias does not depend on the fixture order
  - The request is read from an environment dictionary.
  - The registry for a run holds the real registry plus, in debug builds, the debug experience under its first fixture id with its manifest.
  - A run of `input-response` for the debug experience writes a valid record to a temporary `Documents/visualcore-evidence/<run>/` and reports exit code 0. The exit is injected, so the test process stays alive.
  - An unknown id writes a record with result `error` and code 2.
  - The debug core reports `taps-counted` after three taps.
  - The inventory rule lists the evidence folder.
- [X] T-U09-018 [US3] Implement the app side: — Verified 2026-11-12: xcodebuild_app.py 27.2 phone: chunk c + ScenarioLaunchTests 69/69 (all nine debug scenarios through the app's run path, two-launch save-restore, error records with exit 2); interface chunks a, b, d, e, f pass; the debug experience draws through a shader with a state-dependent corner mark (non-blank frames), reports taps-counted after three taps, declares a corner probe
  - `Apps/VisualCore/App/Automation/ScenarioLaunch.swift` and `ScenarioHostView.swift` (`#if DEBUG || VISUALCORE_AUTOMATION`).
  - The request check in `VisualCoreApp.swift` before the model.
  - In `DebugExperience.swift`: the outcome `taps-counted`, one probe, and its manifest of nine scenarios.
  - The rule `Documents/visualcore-evidence/…` in `DebugInventory.swift`.
  - Add `project.yml` sources if needed.
  - T-U09-017 passes. The app chunks a to f still pass on the iOS 27.2 phone (FR-U09-011, FR-U09-015, FR-U09-034).
- [X] T-U09-019 [US3] Release absence: — Verified 2026-11-12: Release build: check_release_symbols.py 0 automation symbols, 0 trigger strings; check_experience_symbols.py --module pure and host: 0 symbols in release, and with VISUALCORE_AUTOMATION --require-each 2853 and 556 symbols; script tests OK
  - Add `ScenarioRunner ScenarioLaunch ScenarioManifest VISUALCORE_AUTORUN_EXPERIENCE` to `scripts/check_release_symbols.py`'s lists.
  - Add the new type names to `scripts/check_experience_symbols.py` for `--module pure` and `--module host`, with script tests.
  - Proof: a Release build shows 0 found, and `check_experience_symbols.py --with-flag` shows them present (FR-U09-012; SC-U09-004).

## Phase 6: User Story 1 - One command proves an experience on both runtimes (Priority: P1)

- [X] T-U09-020 [US1] Tests first in `scripts/test_scripts.py` (class `VerifyDriverTests`). Use fixtures and injected command runners, with no simulator. Cover: — Verified 2026-11-12: python3 scripts/test_scripts.py: Ran 286 tests, OK (VerifyDriverTests 28)
  - Planning per id: the sample takes the package path, `debug` and registered ids the app path.
  - `--only`, `--skip` and `--scenario` select correctly.
  - State and resume: passed items are skipped, and `--fresh` reruns them.
  - The environment and source fields are completed from command outputs.
  - The limits: 120 s per scenario, endurance time plus 120 s, 300 s boot. A scenario without a record, or a process that does not exit, fails by name.
  - "Busy" is retried once after 20 s.
  - The record is removed from the container after copying.
  - Summaries carry no identifier.
  - The exit code is non-zero on any failure.
  - A lock file refuses a second concurrent run.
  - `--self-test` exits non-zero when a planted failure is not found.
  - A summary is written under `docs/verification/<id>/`.
  - `debug` and several ids are planned in one run.
- [X] T-U09-021 [US1] Implement `scripts/verify_experiences.py` (research R6). It has the options of FR-U09-021, takes several ids and the id `debug`, and writes the tracked summaries `docs/verification/<id>/summary-<runtime>.json`. Its `--self-test` runs the validator and audit self-tests without a simulator; with `--runtime`, it also runs the sample path with the `LossySnapshot` variant, which must fail save-restore by name while the self-test itself exits 0. T-U09-020 passes (FR-U09-020 to FR-U09-022, FR-U09-024, FR-U09-025, FR-U09-033, FR-U09-061; SC-U09-002, SC-U09-009, SC-U09-010). — Verified 2026-11-12: python3 scripts/test_scripts.py: Ran 286 tests, OK; verify_experiences.py --self-test (offline): PASS (43 validator cases, 10 planted audit defects found); --dry-run plans both paths on both runtimes
- [X] T-U09-022 [US1] Acceptance: — Verified 2026-11-12: verify_experiences.py --only a99.contract-sample debug --runtime 27 --fresh: 18 of 18 pass (sample through package tests with the bundle Passed 9/9; debug in the app with two-launch save-restore); the same command again skipped all 18 (resume repeats nothing). Fixed on the way: the second launch's record now carries the restored digest as its initial digest; summaries keep every scenario's latest result with its commit
  - `python3 scripts/verify_experiences.py --only a99.contract-sample --runtime 27` passes 9 of 9.
  - `--only debug --runtime 27` passes 9 of 9 in the app, with save-restore over two launches.
  - An interrupted run resumed with `--only` repeats nothing (SC-U09-001, SC-U09-005).

## Phase 7: User Story 6 - Result bundles count only when checked independently (Priority: P2)

- [X] T-U09-023 [US6] Tests first, then the code in `verify_experiences.py`: — Verified 2026-11-12: verify_experiences.py --self-test --runtime 27: the bundle with the LossySnapshot test is checked with xcresulttool and the -lossy record is judged a failure naming save-restore (open failed: snapshot.state-mismatch at restore); bundle counts come from xcresulttool, never from the printed summary; VerifyDriverTests cover passed / one failed / missing bundle
  - Read `xcresulttool get test-results summary` and `tests` output from fixture JSON: passed, one failed, and missing.
  - Export the attachments.
  - Acceptance: the self-test path with the `LossySnapshot` variant produces a real bundle with one failed test. The driver fails that step, even though xcodebuild's printed summary is not trusted (FR-U09-023; SC-U09-008).

## Phase 8: User Story 5 - Rendered frames prove that something real was drawn (Priority: P2)

- [X] T-U09-024 [US5] Acceptance on both runtimes (package tests of T-U09-013): — Verified 2026-11-12: xcodebuild_package.py VisualCoreRendering --only-testing VisualCoreExperienceHostTests on sim-27.2 and sim-26.5: 144 tests, 0 failures each (ScenarioRunnerTests 15: nine standard scenarios pass; LossySnapshot fails save-restore, WrongReset fails reset, a blank frame and a wrong probe fail; endurance 3,600 frames flat) (testABlankFrameFailsLaunchFirstFrame, testAProbeThatDoesNotMatchFails; launch-first-frame records carry the frame hash and probe outcomes; no golden image decides a result)
  - The blank and wrong-probe cases fail.
  - The launch-first-frame records of the sample and the debug experience carry a frame hash and probe outcomes.
  - A golden image, when one exists, is recorded as `supporting` and changes no result (FR-U09-040, FR-U09-041; SC-U09-007).

## Phase 9: User Story 7 - Audits (Priority: P2)

- [X] T-U09-025 [US7] Tests first in `scripts/test_scripts.py` (class `AuditTests`), on temporary copies. Each of these is found: — Verified 2026-11-12: python3 scripts/test_scripts.py: Ran 286 tests, OK (AuditTests 11)
  - A TODO in a comment, and a FIXME in a string.
  - "coming soon" in the string catalog, and "placeholder" in a `Text("…")`.
  - The word "placeholder" as a variable name is not a finding.
  - A stray PNG; a listed generated PNG with the right hash passes, and the wrong hash fails.
  - A completion expected without actions.
  - A record whose handled count is lower than the sent count.
  - A game manifest short by one acceptance scenario.
  - The audits ignore untracked build products.
- [X] T-U09-026 [US7] Implement `--audits` in `verify_experiences.py` (research R8): — Verified 2026-11-12: verify_experiences.py --audits: 6 PASS lines on today's tree, entitlement named not yet provided (UA-F08); release_check steps evidence-self-test and verify-audits; Catalog/generated-art.json empty; python3 scripts/test_scripts.py: Ran 286 tests, OK
  - Create `Catalog/generated-art.json` (`{"schema": 1, "files": []}`).
  - Run the direct-GL check (`check_app_isolation.py`) and the network check (`check_compliance.py`).
  - Name the entitlement audit "not yet provided (UA-F08)".
  - Add the release-check steps `evidence-self-test` and `verify-audits` to `scripts/release_check.py`.
  - Today's sources pass. T-U09-025 passes (FR-U09-050 to FR-U09-055; SC-U09-006).

## Phase 10: User Story 8 - Games run their extra scenarios (Priority: P3)

- [X] T-U09-027 [US8] Acceptance: — Verified 2026-11-12: No game exists yet, so the requirement is enforced and proven by fixtures: ScenarioManifestTests (Round 2 complete passes, 79 acceptance -> 'too few acceptance scenarios: 79 of 80', Round 3 with 49 faults -> 'too few fault scenarios: 49 of 50', missing full-playthrough/hero, game without a round) in swift test 380 passed; FrameChecksTests (histogram, black frame, non-finite values, silhouette bounds); AuditTests.test_a_game_manifest_short_by_one_acceptance_scenario reads the catalog rows (100 levels, 80 acceptance) in test_scripts.py 287 OK
  - The validator tests of T-U09-004 with fixture game manifests (Round 2 complete, 79 acceptance, Round 3 without fault cases).
  - The frame-check tests of T-U09-008 for the hero checks.
  - The content counts in the audit read the planning catalog rows: 100 levels, 80 acceptance, 50 faults.
  - Since no game exists, record in the task that the requirement is enforced and proven by fixtures (FR-U09-005, FR-U09-042, FR-U09-053).

## Phase 11: Framework obligations, documents and the audit before evidence

- [X] T-U09-028 API baseline, rules and boundaries: — Verified 2026-11-12: check_public_api.py: 2174 lines, 0 undocumented, 0 lines lost since 7bc756b; boundary diff since 7bc756b empty; dependencies, compliance, three documented-api checks, storage-rule, stored-data-rule and app isolation (18 files) pass
  - `check_public_api.py --update` leaves no difference: 0 undocumented and no line lost since `7bc756b`.
  - `git diff --stat 7bc756b -- External Vendor Showcase Harnesses Apps/GenerativeArtStudio Apps/FluidArtPlayground Apps/FractalExplorer Apps/ParticleUniverse` is empty.
  - `check_dependencies.py`, `check_compliance.py`, the three documented-API checks and the storage rules pass (FR-U09-063, FR-U09-064).
- [X] T-U09-029 Documents as built, edited in place: — Verified 2026-11-12: Auto-Creator.md 11.4, 16, 22.1 and 22.2 edited in place as built; docs/verification/README.md new; render_autocreator.py 18 blocks, validate_autocreator.py 16 checks 0 problems, validate_docs.py PASS
  - Auto-Creator.md sections 6 (outcome), 11.4 (runner), 16 (new files) and 22 (driver, options, record location, audits).
  - `docs/verification/README.md` (new: record layout).
  - `render_autocreator.py` and `validate_autocreator.py` pass.
  - specs/192-ua-f06-quality-performance/quickstart.md gets no edit; its obligation is met by the `sample-endurance` check.
- [X] T-U09-030 Run a read-only audit of the implementation against the specification before the evidence round (`/speckit-converge`); implement what it appends. — Verified 2026-11-12: read-only audit by an agent against 36 requirements and 10 success criteria (report in the session scratchpad): 22 findings, 13 tasks appended as Phase 13 (all implemented and verified), 4 accepted with reasons; /speckit-converge run 1
- [X] T-U09-031 Consumers: after `release_check.py --only xcodegen`, build for testing `Showcase`, `GenerativeArtStudio`, `FluidArtPlayground`, `FractalExplorer`, `ParticleUniverse`, `InteractiveDemo` and `SecondConsumer` into `Build/DerivedData/ua-f09-<Scheme>`, recorded as `build-<Scheme>`: exit 0 seven times. — Verified 2026-11-12: run-check build-<Scheme>-r2 for Showcase, GenerativeArtStudio, FluidArtPlayground, FractalExplorer, ParticleUniverse, InteractiveDemo, SecondConsumer: exit 0 seven times on the final sources

## Phase 12: Evidence and convergence

- [X] T-U09-032 Evidence `script-tests` (`python3 scripts/test_scripts.py`), `self-test` (`python3 scripts/verify_experiences.py --self-test`), `audits` (`python3 scripts/verify_experiences.py --audits`). — Verified 2026-11-12: run-check script-tests (307 OK), self-test (43 validator cases, 12 planted audit defects), audits (PASS, SKIP for bypass and content with 0 registered, entitlement not yet provided): exit 0
- [ ] T-U09-033 Evidence `sample-sim` (`python3 scripts/verify_experiences.py --only a99.contract-sample --runtime 27 26`), `sample-endurance` (`--only a99.contract-sample --scenario endurance --runtime 27`), `self-test-sim` (`--self-test --runtime 27`).
- [ ] T-U09-034 Evidence `debug-sim27` and `debug-sim26` (`python3 scripts/verify_experiences.py --only debug --runtime 27`, and `26`).
- [ ] T-U09-035 Evidence `persistence-host`, `host-visualcore`, `pure-ios27`, `pure-ios26`, `rendering-ios27`, `rendering-ios26` (host and package tests).
- [ ] T-U09-036 Evidence of the app: `xcodegen`, `app-build`, and the 24 chunks `app-<phone|tablet>-ios<27|26>-<a…f>`.
- [ ] T-U09-037 Evidence `release-build`, `release-symbols`, `release-symbols-debug`, `automation-symbols` (`check_experience_symbols.py`, both modules, with and without the flag), `privacy-manifest`, `compliance`, `app-isolation`, `storage-rule`, `stored-data-rule`, `public-api`, `dependencies`.
- [ ] T-U09-038 Evidence `reference-a` and `reference-b`: the two chunks of the ProjectM reference regression (3 of 3 and 4 of 4).
- [ ] T-U09-039 Evidence `docs` and `steering`; then confirm with `gh run list` that the `ci` and `push-scan` runs of the last pushed commit succeeded (a queued run is checked again later, never watched).
- [ ] T-U09-040 Run `/speckit-converge` for UA-F09, run `/speckit-implement` for every task it appends, and repeat until a run appends nothing. Then `python3 scripts/migration_ledger.py seal --gate UA-F09 && python3 scripts/migration_ledger.py record --gate UA-F09`.

## Dependencies & Execution Order

- Phase 1 and Phase 2 come first. US2 (Phase 3) needs T-U09-003 to T-U09-011. US4 (Phase 4) is independent of
  Swift. US3 (Phase 5) needs US2's runner. US1 (Phase 6) needs US2, US3 and US4. US6 (Phase 7) needs US1. US5
  (Phase 8) is proven by US2's tests on both runtimes. US7 (Phase 9) needs US4's validator. US8 (Phase 10)
  needs T-U09-005 and T-U09-009.
- One writer per file: `verify_experiences.py` is written by T-U09-021, 023 and 026 in this order;
  `scripts/test_scripts.py` by T-U09-001, 015, 019, 020, 023 and 025 in this order.

## Parallel Opportunities

- Phase 2: the five test-and-source pairs (T-U09-002/003, 004/005, 006/007, 008/009, 010/011) touch separate
  files; each pair can go to one agent. T-U09-001 and Phase 4 (Python) run beside them.
- T-U09-020's tests and T-U09-025's tests can be written in parallel, in separate files where the test file
  allows (they share `scripts/test_scripts.py`, so the lead merges them).

## Implementation Strategy

The MVP is US2 plus US4: scenarios run through a real session, and records are checked. Then come the app path
(US3), the driver (US1), bundles (US6), frames (US5), audits (US7) and games (US8). Evidence runs once, after the
audit of T-U09-030.

## Analysis record

- **Run 1 (2026-11-12, `/speckit-analyze`)**: 36 requirements and 10 success criteria checked against 40 tasks.
  It found 2 high, 3 medium and 1 low finding, and no critical one. Fixed in this file:
  - H1: the `endurance` scenario (FR-U09-005, FR-U09-060) had no implementing task. It is now in T-U09-013 and
    T-U09-014.
  - H2: "every experience declares at least one probe" (FR-U09-040) was not enforced. The runner now fails
    launch-first-frame without one (T-U09-013, T-U09-014).
  - M1: the driver's `--self-test` with the failing variant (FR-U09-025) is now named in T-U09-021, with a test in
    T-U09-020.
  - M2: the tracked summaries (FR-U09-033) and the `debug` id and several ids (FR-U09-061) are now named in
    T-U09-020 and T-U09-021.
  - M3: device usability of the record format (FR-U09-062) is now traced to T-U09-015.
  - L1: SC-U09-002, 009 and 010 are now traced to T-U09-014 and T-U09-021.

  Constitution and ADR-0009: no conflict. The runner is absent from the shipping build, nothing touches the
  network or a device, and the renderer is unchanged.
- **Run 2 (2026-11-12)**: coverage 100% (46 of 46 requirement and criterion ids traced, ranges included); no
  critical or high finding; no further change.

## Phase 13: Convergence

Appended by `/speckit-converge` run 1 (2026-11-12, the audit of T-U09-030). It checked 36 requirements, 10 success
criteria, the acceptance scenarios and edge cases, the plan's touch-points and 15 constitution principles, and
found 22 gaps: 0 critical, 5 high, 7 medium, 10 low. The tasks below act on 18 of them; 4 are accepted in the
note under the tasks.

- [X] T-U09-041 Judge the save-phase record of the app's save-restore: validate it, require `result: pass`, and fail the scenario with the save launch's failures. Add a VerifyDriverTests case with a failing save record per FR-U09-013, FR-U09-024 (partial) — Verified 2026-11-12: python3 scripts/test_scripts.py: Ran 307 tests, OK (failing and invalid save records fail save-restore with 'save phase:'); verify_experiences.py --only a99.contract-sample debug --runtime 27: 18 of 18 pass (rerun at the new commit, nothing skipped)
- [X] T-U09-042 Resume skips a passed scenario only when it passed at the current commit with the same app or test binary hash. Rerun a pass of another commit, and add a test per FR-U09-021, Constitution VI (contradicts) — Verified 2026-11-12: python3 scripts/test_scripts.py: Ran 307 tests, OK (another commit or binary reruns); verify_experiences.py --only a99.contract-sample debug --runtime 27: 18 of 18 pass (rerun at the new commit, nothing skipped) — the earlier passes at another commit were all rerun
- [X] T-U09-043 Run the sample's endurance at 600 simulated seconds (36,000 frames, the UA-F06 length) and attach its record `evidence-a99.contract-sample-endurance.json`. The driver validates and counts it like the other records per FR-U09-005, FR-U09-060 (contradicts) — Verified 2026-11-12: ScenarioRunnerTests on sim-27.2 and sim-26.5: 144 host tests pass each, endurance 600 simulated seconds (36,000 frames) flat without the corner mark; verify_experiences.py --only a99.contract-sample --scenario endurance --runtime 27: record validated, PASS
- [X] T-U09-044 The manifest validator requires: — Verified 2026-11-12: swift test VisualCoreExperienceTests: 381 passed (theActionScenariosMustProveSomething)
  - an expected outcome and at least one action in `completion`;
  - at least one action in `input-response` and `rejection`;
  - an expected result for every action in `rejection`.
  Add tests for each per FR-U09-001, FR-U09-004 (partial)
- [X] T-U09-045 Validate the manifest at load in the app's scenario run. Problems give an error record (`request.invalid-manifest` with the problems) and exit 2. Add a unit test with a broken manifest per FR-U09-002, FR-U09-011 (missing) — Verified 2026-11-12: app chunk c + ScenarioLaunchTests 73/73 on the iOS 27.2 phone (testADamagedManifestIsRefusedWithExit2)
- [X] T-U09-046 Build the run's targets from the real registry: a registration may carry a scenario manifest in builds for testing or automation. Add a test that a registered experience with a manifest is a target, and correct the doc comment per FR-U09-011, clarification 5 (partial) — Verified 2026-11-12: app 73/73 (testARegisteredExperienceWithAManifestIsATarget; registered experiences take precedence over the debug target)
- [X] T-U09-047 Terminate the app (`xcrun simctl terminate`, bounded) when a scenario gives no record or does not exit. End the record wait early, with "the app exited without a record (crash)", when the process is gone. Kill the whole process group of a test run at its limit. Add tests per FR-U09-024, SC-U09-009 (partial) — Verified 2026-11-12: python3 scripts/test_scripts.py: Ran 307 tests, OK (terminate issued, crash caught early, process group killed at the limit)
- [X] T-U09-048 The summary's bundle block carries the destination and the names of failed tests from `xcresulttool`, and each record's `artifacts.result_bundle` points to the bundle. Record honestly that SC-U09-008 (a bundle with a failed test fails its step) is proven with fixture outputs and with real passing bundles per FR-U09-023, SC-U09-008 (partial) — Verified 2026-11-12: python3 scripts/test_scripts.py: Ran 307 tests, OK (destination and failed test names in the bundle block); SC-U09-008 proven with fixture outputs and real passing bundles, recorded
- [X] T-U09-049 Keep the frame: the app writes the RGBA bytes of the read frame beside its record (`<id>.<scenario>.frame.rgba`) and the package tests attach them. The driver copies the frame to `.autonomy/verify/<run>/`, checks its SHA-256 against the record and sets `frames[].path` per FR-U09-020, FR-U09-033 (missing) — Verified 2026-11-12: app 73/73 (the kept frame's hash equals the record's); verify_experiences.py --only a99.contract-sample debug --runtime 27: 18 of 18 pass (rerun at the new commit, nothing skipped): frames copied to .autonomy/verify/<run>/27.2/, hashes equal, frames[0].path set
- [X] T-U09-050 The content audit reads a game's levels from the runtime catalog's `content.levels`, not from a manifest. The bypass and content audits print "nothing to audit yet (0 registered experiences)" instead of PASS while nothing is registered. Record that both audits act from the first registration (UA-F07) per FR-U09-052, FR-U09-053 (partial) — Verified 2026-11-12: verify_experiences.py --audits: bypass and content print SKIP (0 registered); python3 scripts/test_scripts.py: Ran 307 tests, OK (levels from content.levels, short game manifest fails)
- [X] T-U09-051 Give the debug experience's manifest expected digests (initial, after each tap, final), computed from its core on a bare engine and committed, with a test that they hold per FR-U09-003 (partial) — Verified 2026-11-12: app 73/73 (testTheDebugManifestDigestsHoldOnABareEngine); verify_experiences.py --only a99.contract-sample debug --runtime 27: 18 of 18 pass (rerun at the new commit, nothing skipped) with the committed digests
- [X] T-U09-052 Small corrections: — Verified 2026-11-12: python3 scripts/test_scripts.py: Ran 307 tests, OK; app 73/73 (request error in the run folder; automation false in a plain debug build)
  - test runs limited to 540 s;
  - the raster allow-list requires a tracked generator and a path in the app icon set;
  - `--audits` with `--only` audits only;
  - a request error is written to the request's run folder when its run id parses;
  - `configuration.automation` follows the compilation condition;
  - a summary row of a single-process save-restore says `process: single`;
  per FR-U09-024, FR-U09-051, FR-U09-034, FR-U09-013 (partial)
- [X] T-U09-053 Bring the contract, data model, plan, research section 3 and clarification 5 to the code as built: — Verified 2026-11-12: contract, data model, plan, research section 3 and clarification 5 edited to the code as built; validate_docs.py PASS
  - the runner's signature, `ScenarioRunResult`, `FrameColorClass`, `FrameBounds`, `EvidenceRecord.observed`, `unknownSchema`;
  - `ScenarioHostView` inside ScenarioLaunch.swift;
  - the debug id `a98.debug-experience`;
  - the scenario screen that keeps the host view out of the window;
  - result bundles of the package path;
  - the accepted items below;
  per the documents (contradicts)

Accepted without a task (run 1):
- G12: the runner's frames always carry the fixed delta of `renderOneFrame`, so suspend-resume cannot express time away in frames. The engine's catch-up limit is proven by its own host tests, and the runner proves that no step and no digest change happens while suspended.
- G17: that a reset clears only the experience's own storage is proven by the UA-F05 tests of the app; the runner checks the digest.
- G19: the scenario screen shows a line of text and keeps the session's host view out of the window. That is the decision that makes frames deterministic (no display link); it is recorded in research section 3.
- G20 (shader timing): `shader_compilation_ms` is the scene's set-up time, in which the shaders are compiled. The setup compiles and links, so the name stands; the program count is in the session's timings.
