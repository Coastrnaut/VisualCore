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
- [ ] T-U09-003 Implement `Packages/VisualCore/Sources/VisualCoreExperience/ExperienceOutcome.swift` (release). Add `outcome` to `ExperienceCore` (default nil, computed, never stored), to `ExperienceEngine` and to `ExperienceDiagnostics`. In `Packages/VisualCore/Sources/VisualCoreTestSupport/SampleExperienceCore.swift`, the sample reports `target-reached` while marker equals target. T-U09-002 passes (FR-U09-004).
- [ ] T-U09-004 [P] Tests first: `Packages/VisualCore/Tests/VisualCoreExperienceTests/ScenarioManifestTests.swift`. Cover:
  - Loading of schema 1.
  - Refusal of schema 2 (`newerSchema`), of more than 4 MiB and of damaged JSON.
  - The validator finds each problem: a missing standard scenario (names it), a duplicate name, a name outside 1–64 `a-z 0-9 -`, more than 1,000 scenarios, more than 10,000 entries, an unknown control, a wrong value count, and an expected outcome or digest with no action before it.
  - A creative experience needs `content.fixtures` scenarios named `fixture-…`.
  - A Round 2 game needs `full-playthrough`, `hero` and 80 `acceptance-…` scenarios. Rounds 3 and 4 also need 50 `fault-…` scenarios. Fixture manifests pass with 80 or 50 and fail with 79 or 49.
- [ ] T-U09-005 Implement `ScenarioManifest.swift` and `ScenarioManifestValidator.swift` in `Packages/VisualCore/Sources/VisualCoreExperience/` (inside `#if DEBUG || VISUALCORE_AUTOMATION`), as data-model section 2 gives them. Entries convert to the existing `ExperienceScenario`. T-U09-004 passes (FR-U09-001, FR-U09-002, FR-U09-003, FR-U09-005).
- [ ] T-U09-006 [P] Tests first: `ScenarioEvaluatorTests.swift`. Cover:
  - Each expectation kind passes and fails with a named message: a step result, a step digest, the initial, final, after-restore and after-reset digests, the outcome, and a probe.
  - `actionsHandled != actionsSent` fails as "bypass".
  - An observation with failures cannot pass.
- [ ] T-U09-007 Implement `ScenarioObservation.swift` (observation and `ScenarioEvaluator`, `#if`). T-U09-006 passes (FR-U09-003, FR-U09-010, FR-U09-052).
- [ ] T-U09-008 [P] Tests first: `FrameChecksTests.swift`. Cover:
  - `isNonBlank` is false for one colour or a spread below 8 of 255, and true for a gradient.
  - `isBlack` treats at most 4 of 255 as black.
  - The histogram has 16 bins summing to the pixel count.
  - `hasNonFinite` finds NaN and infinity.
  - `silhouette` gives the bounding box and nil for an empty frame.
  - `classify` gives `dark`, `light`, `red`, `green`, `blue` or `other`.
  - `FrameProbe` x and y lie in 0…1.
- [ ] T-U09-009 Implement `FrameChecks.swift`. `FrameProbe` is release; the checks are inside `#if`. T-U09-008 passes (FR-U09-040, FR-U09-042).
- [ ] T-U09-010 [P] Tests first: `ScenarioRequestTests.swift`. Cover:
  - No `VISUALCORE_AUTORUN`, or another value, is no request.
  - `scenario` with experience, scenario, seed, run, phase and expected digest parses.
  - A missing experience, a bad seed, a run id outside 1–64 `A-Za-z0-9-`, an unknown phase or a bad digest each give a typed error.
  - Values over 256 characters are refused.
  - `EvidenceRecord` encodes the field names of data-model section 4 with sorted keys and decodes them.
- [ ] T-U09-011 Implement `ScenarioRequest.swift` and `EvidenceRecord.swift` (`#if`). T-U09-010 passes (FR-U09-011, FR-U09-030).
- [ ] T-U09-012 Record the API of Phase 2 with `python3 scripts/check_public_api.py --update`: 0 undocumented and no baseline line lost since `7bc756b`. Proof: `swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests` passes.

**Checkpoint**: the pure layer is complete and host-tested.

## Phase 3: User Story 2 - Every experience carries its scenarios as domain actions (Priority: P1)

**Goal**: a runner plays a manifest's scenarios through a real session; the sample's nine pass and its faults fail.

**Independent test**: `ScenarioRunnerTests` on both simulator runtimes.

- [ ] T-U09-013 [US2] Tests first: `Packages/VisualCoreRendering/Tests/VisualCoreExperienceHostTests/ScenarioRunnerTests.swift` with the fixture `Fixtures/sample-manifest.json` (nine scenarios; seeds and digests from the sample's committed goldens). Cover:
  - Each of the nine passes with `SamplePresenter<NoFault>`.
  - `LossySnapshot` fails save-restore and `MutatingRejection` fails rejection, each with the named expectation.
  - A presenter that draws black fails launch-first-frame with "blank", and a probe expecting `red` on a blue frame fails.
  - teardown-reentry runs 5 cycles with zero live and leaked objects. cancel-prepare uses `SlowPreparation` and the result is `.cancelled`. suspend-resume uses a scripted time source, with no step for the time away.
  - An `endurance` scenario (the manifest names its seconds, 1 to 600) runs in the same class, outside the default run, and passes by the UA-F06 growth rule. A presenter that declares no probe fails launch-first-frame with "no probe declared". Each test attaches its record as `evidence-a99.contract-sample-<scenario>.json`.
  - The test-target manifest must be added to the package resources.
- [ ] T-U09-014 [US2] Add `probes(_:)` (default empty) to `ExperiencePresenter` and `frameProbes` to `Experience`, forwarded by `ExperienceShell`. Implement `Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost/ScenarioRunner.swift` (`#if`), using the session calls of research R3. The sample presenter declares one probe. Update the API baseline. The runner fails launch-first-frame when the experience declares no probe. It runs `endurance` by the UA-F06 growth rule. T-U09-013 passes on the iOS 27.2 and 26.5 simulators (FR-U09-005, FR-U09-010, FR-U09-013, FR-U09-014, FR-U09-040, FR-U09-060; SC-U09-002).

## Phase 4: User Story 4 - Evidence records are complete, versioned and checked (Priority: P1)

- [ ] T-U09-015 [P] [US4] Tests first in `scripts/test_scripts.py` (class `EvidenceValidatorTests`). Cover:
  - A valid simulator record passes.
  - Each of these is rejected by name: each field group missing (14), a wrong type, schema 0 or 2, a bad hash, a `result` outside three values, a pass with failures, a pass without steps or digests, a drawing pass without a frame, a UDID-shaped value, an ECID-shaped value, and `environment.kind` other than simulator or device.
  - A device record without identifiers passes, so the format stays usable on devices (FR-U09-062).
- [ ] T-U09-016 [US4] Implement `scripts/check_evidence.py` (validator; `--self-test`; exit 0 or 1). T-U09-015 passes (FR-U09-030 to FR-U09-032; SC-U09-003).

## Phase 5: User Story 3 - The app runs one scenario and exits (Priority: P1)

- [ ] T-U09-017 [US3] Tests first: `Apps/VisualCore/Tests/Unit/ScenarioLaunchTests.swift`. Cover:
  - The request is read from an environment dictionary.
  - The registry for a run holds the real registry plus, in debug builds, the debug experience under its first fixture id with its manifest.
  - A run of `input-response` for the debug experience writes a valid record to a temporary `Documents/visualcore-evidence/<run>/` and reports exit code 0. The exit is injected, so the test process stays alive.
  - An unknown id writes a record with result `error` and code 2.
  - The debug core reports `taps-counted` after three taps.
  - The inventory rule lists the evidence folder.
- [ ] T-U09-018 [US3] Implement the app side:
  - `Apps/VisualCore/App/Automation/ScenarioLaunch.swift` and `ScenarioHostView.swift` (`#if DEBUG || VISUALCORE_AUTOMATION`).
  - The request check in `VisualCoreApp.swift` before the model.
  - In `DebugExperience.swift`: the outcome `taps-counted`, one probe, and its manifest of nine scenarios.
  - The rule `Documents/visualcore-evidence/…` in `DebugInventory.swift`.
  - Add `project.yml` sources if needed.
  - T-U09-017 passes. The app chunks a to f still pass on the iOS 27.2 phone (FR-U09-011, FR-U09-015, FR-U09-034).
- [ ] T-U09-019 [US3] Release absence:
  - Add `ScenarioRunner ScenarioLaunch ScenarioManifest VISUALCORE_AUTORUN_EXPERIENCE` to `scripts/check_release_symbols.py`'s lists.
  - Add the new type names to `scripts/check_experience_symbols.py` for `--module pure` and `--module host`, with script tests.
  - Proof: a Release build shows 0 found, and `check_experience_symbols.py --with-flag` shows them present (FR-U09-012; SC-U09-004).

## Phase 6: User Story 1 - One command proves an experience on both runtimes (Priority: P1)

- [ ] T-U09-020 [US1] Tests first in `scripts/test_scripts.py` (class `VerifyDriverTests`). Use fixtures and injected command runners, with no simulator. Cover:
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
- [ ] T-U09-021 [US1] Implement `scripts/verify_experiences.py` (research R6). It has the options of FR-U09-021, takes several ids and the id `debug`, and writes the tracked summaries `docs/verification/<id>/summary-<runtime>.json`. Its `--self-test` runs the validator and audit self-tests without a simulator; with `--runtime`, it also runs the sample path with the `LossySnapshot` variant, which must fail save-restore by name while the self-test itself exits 0. T-U09-020 passes (FR-U09-020 to FR-U09-022, FR-U09-024, FR-U09-025, FR-U09-033, FR-U09-061; SC-U09-002, SC-U09-009, SC-U09-010).
- [ ] T-U09-022 [US1] Acceptance:
  - `python3 scripts/verify_experiences.py --only a99.contract-sample --runtime 27` passes 9 of 9.
  - `--only debug --runtime 27` passes 9 of 9 in the app, with save-restore over two launches.
  - An interrupted run resumed with `--only` repeats nothing (SC-U09-001, SC-U09-005).

## Phase 7: User Story 6 - Result bundles count only when checked independently (Priority: P2)

- [ ] T-U09-023 [US6] Tests first, then the code in `verify_experiences.py`:
  - Read `xcresulttool get test-results summary` and `tests` output from fixture JSON: passed, one failed, and missing.
  - Export the attachments.
  - Acceptance: the self-test path with the `LossySnapshot` variant produces a real bundle with one failed test. The driver fails that step, even though xcodebuild's printed summary is not trusted (FR-U09-023; SC-U09-008).

## Phase 8: User Story 5 - Rendered frames prove that something real was drawn (Priority: P2)

- [ ] T-U09-024 [US5] Acceptance on both runtimes (package tests of T-U09-013):
  - The blank and wrong-probe cases fail.
  - The launch-first-frame records of the sample and the debug experience carry a frame hash and probe outcomes.
  - A golden image, when one exists, is recorded as `supporting` and changes no result (FR-U09-040, FR-U09-041; SC-U09-007).

## Phase 9: User Story 7 - Audits (Priority: P2)

- [ ] T-U09-025 [US7] Tests first in `scripts/test_scripts.py` (class `AuditTests`), on temporary copies. Each of these is found:
  - A TODO in a comment, and a FIXME in a string.
  - "coming soon" in the string catalog, and "placeholder" in a `Text("…")`.
  - The word "placeholder" as a variable name is not a finding.
  - A stray PNG; a listed generated PNG with the right hash passes, and the wrong hash fails.
  - A completion expected without actions.
  - A record whose handled count is lower than the sent count.
  - A game manifest short by one acceptance scenario.
  - The audits ignore untracked build products.
- [ ] T-U09-026 [US7] Implement `--audits` in `verify_experiences.py` (research R8):
  - Create `Catalog/generated-art.json` (`{"schema": 1, "files": []}`).
  - Run the direct-GL check (`check_app_isolation.py`) and the network check (`check_compliance.py`).
  - Name the entitlement audit "not yet provided (UA-F08)".
  - Add the release-check steps `evidence-self-test` and `verify-audits` to `scripts/release_check.py`.
  - Today's sources pass. T-U09-025 passes (FR-U09-050 to FR-U09-055; SC-U09-006).

## Phase 10: User Story 8 - Games run their extra scenarios (Priority: P3)

- [ ] T-U09-027 [US8] Acceptance:
  - The validator tests of T-U09-004 with fixture game manifests (Round 2 complete, 79 acceptance, Round 3 without fault cases).
  - The frame-check tests of T-U09-008 for the hero checks.
  - The content counts in the audit read the planning catalog rows: 100 levels, 80 acceptance, 50 faults.
  - Since no game exists, record in the task that the requirement is enforced and proven by fixtures (FR-U09-005, FR-U09-042, FR-U09-053).

## Phase 11: Framework obligations, documents and the audit before evidence

- [ ] T-U09-028 API baseline, rules and boundaries:
  - `check_public_api.py --update` leaves no difference: 0 undocumented and no line lost since `7bc756b`.
  - `git diff --stat 7bc756b -- External Vendor Showcase Harnesses Apps/GenerativeArtStudio Apps/FluidArtPlayground Apps/FractalExplorer Apps/ParticleUniverse` is empty.
  - `check_dependencies.py`, `check_compliance.py`, the three documented-API checks and the storage rules pass (FR-U09-063, FR-U09-064).
- [ ] T-U09-029 Documents as built, edited in place:
  - Auto-Creator.md sections 6 (outcome), 11.4 (runner), 16 (new files) and 22 (driver, options, record location, audits).
  - `docs/verification/README.md` (new: record layout).
  - `render_autocreator.py` and `validate_autocreator.py` pass.
  - specs/192-ua-f06-quality-performance/quickstart.md gets no edit; its obligation is met by the `sample-endurance` check.
- [ ] T-U09-030 Run a read-only audit of the implementation against the specification before the evidence round (`/speckit-converge`); implement what it appends.
- [ ] T-U09-031 Consumers: after `release_check.py --only xcodegen`, build for testing `Showcase`, `GenerativeArtStudio`, `FluidArtPlayground`, `FractalExplorer`, `ParticleUniverse`, `InteractiveDemo` and `SecondConsumer` into `Build/DerivedData/ua-f09-<Scheme>`, recorded as `build-<Scheme>`: exit 0 seven times.

## Phase 12: Evidence and convergence

- [ ] T-U09-032 Evidence `script-tests` (`python3 scripts/test_scripts.py`), `self-test` (`python3 scripts/verify_experiences.py --self-test`), `audits` (`python3 scripts/verify_experiences.py --audits`).
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
