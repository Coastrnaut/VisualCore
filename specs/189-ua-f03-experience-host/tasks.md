---

description: "Task list for feature 189 — UA-F03 experience host and session lifecycle (migration ledger gate UA-F03)"
---

# Tasks: UA-F03 — Experience host and session lifecycle

**Input**: `specs/189-ua-f03-experience-host/` (spec, plan, research, data-model, contracts/session-api.md,
quickstart).

**Tests** are required by the specification (acceptance items 1 to 8): Swift Testing for the pure part on the
host, XCTest in `Packages/VisualCoreRendering/Tests/VisualCoreExperienceHostTests` on both simulator runtimes, and
`unittest` in `scripts/test_scripts.py`. A test file is written before the code it proves; where an agent writes
test and code of one unit together, the tick says so.

**Conventions**: ids `T-U03-###`; one commit and push per task through `scripts/tick_task.py`; a test task and the
implementation it proves are committed together so that `main` is never red, and the API baseline is updated in
every commit that adds a public symbol; gate evidence through
`python3 scripts/migration_ledger.py run-check --gate UA-F03 --name <check-name> -- <command>` (simulator and
reference commands with `--timeout 600`). "The commit before the feature" is `91c507d` (the commit that recorded
UA-F02). Every public symbol gets its `///` documentation in the task that adds it. Signatures are those of
contracts/session-api.md. `[P]` marks a task whose files no other open task writes: such tasks may go to parallel
agents, which write files only; the lead builds, tests, ticks and commits. The sample experience, `SamplePresenter`
and the helpers of UA-F02's test target are reused. Review checkpoint after each phase: the named tests and
`python3 scripts/validate_docs.py` pass.

**Order of stories**: the session is one class, so its three test files (US1 to US5) come first, then the class,
then the host view (US1), then the tool (US6).

**Device-only**: one `{device}` task (T-U03-025). **Owner-only**: none.

## Phase 1: Setup

- [X] T-U03-001 In `Packages/VisualCoreRendering/Package.swift` set `defaultLocalization: "en"`, give the target `VisualCoreExperienceHost` the dependency `VisualCoreUI` and `resources: [.process("Resources")]`; create `Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost/Resources/Localizable.xcstrings` with the keys `session.preparing`, `session.cancel`, `session.failure.title`, `session.retry`, `session.back`, `session.message.memory`, `session.canvas.hint` (English) and `SessionStrings.swift`, which reads them from the module's bundle; add a test to `ModuleTests.swift` that every key resolves to a text different from its key (FR-U03-063). Proof: `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test` reports TEST SUCCEEDED; if the string catalog does not build for a package target, use `Resources/en.lproj/Localizable.strings` and record the deviation in research.md. — Verified 2026-11-12: xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test: TEST SUCCEEDED; testEveryTextKeyResolves passed, so the string catalog builds for the package target and all seven keys resolve; check_dependencies.py: PASS

## Phase 2: Foundational (pure session values)

- [X] T-U03-002 [P] Write `Packages/VisualCore/Tests/VisualCoreExperienceTests/SessionLifecycleTests.swift`: a new lifecycle is idle; all 49 ordered state pairs against the table of data-model.md section 1 (exactly 17 accepted; a rejection keeps the state and adds exactly one to `rejectedTransitions`); `SessionCloseStep.order` is the seven steps of section 2 and `cancelOrder` the two of a cancelled preparation; `MemoryPressureRule.limit` returns the requested value, else half of the budget's total, never below 1, and `shouldClose` is true only above the limit; `SessionFailure` and `SessionStageTimings` survive a JSON round trip; `SessionDiagnostics.encoded()` has sorted keys, leaves absent items out and decodes to an equal value; the three session codes equal the texts of the contract. — Verified 2026-11-12: SessionLifecycleTests.swift written by a parallel agent with the types; swift test --package-path Packages/VisualCore --filter SessionLifecycleTests run by the lead: 22 tests passed (17 of 49 state pairs accepted, close order, pressure rule, diagnostics encoding)
- [X] T-U03-003 [P] Create `Packages/VisualCore/Sources/VisualCoreExperience/SessionLifecycle.swift` with `SessionState`, `ScenePhaseInput`, `SessionCloseStep`, `SessionStage`, `SessionFailure`, `SessionStageTimings`, `SessionOpenResult`, `MemoryPressureRule`, `SessionLifecycle` and `SessionDiagnostics` (FR-U03-001, FR-U03-080, FR-U03-081, FR-U03-100). Proof: `swift test --package-path Packages/VisualCore --filter SessionLifecycleTests` passes. — Verified 2026-11-12: swift test --package-path Packages/VisualCore --filter SessionLifecycleTests: 22 tests passed; MemoryPressureRule.limit never goes below 1

## Phase 3: User Stories 1 to 5 - the session (Priority: P1 and P2) 🎯 MVP

**Goal**: `ExperienceSession`. **Independent Test**: each story's test class on both simulator runtimes.

- [ ] T-U03-004 [P] [US2] Write `Packages/VisualCoreRendering/Tests/VisualCoreExperienceHostTests/SessionOpenCloseTests.swift` (helpers: an open request for the sample, a laid-out window for `session.renderHost`): opening the sample ends in running with `.running`, a centre pixel that shows the state, and the four stage timings; closing records exactly `SessionCloseStep.order`, hands one snapshot to the sink, and leaves `lastCloseCounts` at 0 objects and 0 leaked; opening B while A runs closes A completely before B's factory is called (the test records the order of events) and `hostsAlive` never exceeds 1, also for opens during preparing, failed and message (SC-U03-001); 50 open and close cycles end each with 0 live and 0 leaked objects and equal live bytes while running in cycle 1 and cycle 50 (SC-U03-002); a presenter that keeps its texture gives a recorded failure with the code `experience.gpu-leak` at stage close, an idle session and a successful next open; closing when idle and closing twice do nothing; 20 opens and closes in a row leave the session idle with 0 objects; an open with a snapshot restores it (equal digest) and an open with a snapshot of another experience opens fresh and records `snapshot.wrong-experience` (FR-U03-002 to FR-U03-006, FR-U03-010 to FR-U03-013).
- [ ] T-U03-005 [P] [US1] Write `Packages/VisualCoreRendering/Tests/VisualCoreExperienceHostTests/SessionFailureTests.swift`: a failing preparation, a presenter that throws in setup and one that throws in draw each end in failed with the stage and code in `diagnostics.lastFailure`, `renderHost == nil`, 0 live objects, and a following open of the healthy sample runs (SC-U03-003); the slow sample with a time limit of 100 ms fails with `experience.preparation-timeout`; `retry()` after the cause is removed runs with the same seed, and `retry()` outside failed is refused without effect; `back()` makes the session idle and keeps the failure in the diagnostics; [US3] closing the slow sample 50 ms after `open` makes the session idle within 1 second with `.cancelled`, 0 render hosts created and 0 setup, draw or action calls on the presenter, 20 of 20 times (SC-U03-004); opening the healthy sample while the slow one prepares returns `.superseded` for the first and `.running` for the second; a preparation result that arrives after the close changes nothing (FR-U03-020 to FR-U03-023, FR-U03-030 to FR-U03-032).
- [ ] T-U03-006 [P] [US4] Write `Packages/VisualCoreRendering/Tests/VisualCoreExperienceHostTests/SessionPhaseMemoryTests.swift`: background and inactive suspend a running session (experience suspended, host state suspended, one snapshot per suspension) and active resumes it with 0 steps for the time away and an equal digest (SC-U03-005); a preparation that ends while the phase is background gives `.suspended` and runs after active; phases in idle, failed and message only store the phase; [US5] a memory warning below the limit sheds caches (the presenter's shed counter grows), keeps digest and state; with a memory-pressure limit of 0 bytes it hands out a snapshot, closes with 0 objects and ends in message with the memory text, and `back()` returns to idle (SC-U03-006); `recreateContext()` keeps digest and centre pixel within 2 of 255 and counts one recreation (SC-U03-007); a sink that throws is counted as `sinkFailures` and stops neither suspension nor close; the session removes its memory-warning observer when released (FR-U03-040 to FR-U03-053, FR-U03-070, FR-U03-071).
- [ ] T-U03-007 Create `Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost/ExperienceOpenRequest.swift` and `ExperienceSession.swift` as contracts/session-api.md states, every state change through `SessionLifecycle`, every close step recorded (the requirements listed in T-U03-004, T-U03-005 and T-U03-006, and FR-U03-044, FR-U03-100). Proof: `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test` reports TEST SUCCEEDED with the three session test classes.
- [ ] T-U03-008 [P] [US1] Write `Packages/VisualCoreRendering/Tests/VisualCoreExperienceHostTests/ExperienceHostViewTests.swift`: for a session in preparing, running, failed and message the host view builds in a `UIHostingController` inside a window of 320 by 568 points at the content size category `accessibilityExtraExtraExtraLarge`; the fitting width is not above 320; the state views are scrollable; the shared button style has a minimum of 44 by 44 points; the identifiers `session.cancel`, `session.retry`, `session.back`, `session.failure`, `session.message`, `session.preparing` and `session.canvas` are the constants the views use; the canvas label is the experience's state description (FR-U03-060 to FR-U03-062, SC-U03-010).
- [ ] T-U03-009 [US1] Create `Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost/ExperienceHostView.swift` (host view, preparing, failure and message views, one button style, identifiers, texts from `SessionStrings`, scene phase forwarded to the session). Proof: the simulator test run of T-U03-007 reports TEST SUCCEEDED with `ExperienceHostViewTests`.
- [ ] T-U03-010 [US1] Acceptance of US1 to US5: record `run-check --gate UA-F03 --name us-ios27 --timeout 600 -- python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test` and the same as `us-ios26` on `sim-26.5`; in both logs the classes `SessionOpenCloseTests` (US2), `SessionFailureTests` (US1, US3), `SessionPhaseMemoryTests` (US4, US5) and `ExperienceHostViewTests` (US1) passed.

## Phase 4: User Story 6 - isolation check (Priority: P2)

- [ ] T-U03-011 [P] [US6] Add tests for `scripts/check_app_isolation.py` to `scripts/test_scripts.py` (extend the existing class for that tool or add `ExperienceIsolationTests`): `--experiences` with two folders passes on clean sources and fails with file and line on an import of `CVisualCoreGL`, on an `egl…(` call and on a `vcgl…(` or `gl…(` call; test folders are left out and their number is printed; a missing or empty folder prints `nothing checked (no Swift sources yet)` with exit 0, and exit 1 with `--require-sources`; `--app` behaves as before for an existing app folder; bad input exits 2 (FR-U03-090, FR-U03-091, SC-U03-008).
- [ ] T-U03-012 [P] [US6] Change `scripts/check_app_isolation.py` as contracts/session-api.md states. Proof: `python3 scripts/test_scripts.py` passes; `python3 scripts/check_app_isolation.py --app Apps/VisualCore` exits 0 with "nothing checked"; `python3 scripts/check_app_isolation.py --experiences Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost Packages/VisualCore/Sources/VisualCoreExperience` passes; `python3 scripts/check_app_isolation.py --app Apps/FluidArtPlayground` still passes.
- [ ] T-U03-013 [US6] Acceptance of US6: record `run-check --gate UA-F03 --name app-isolation -- python3 scripts/check_app_isolation.py --app Apps/VisualCore` and `--name experience-isolation -- python3 scripts/check_app_isolation.py --experiences Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost Packages/VisualCore/Sources/VisualCoreExperience`.

## Phase 5: Framework obligations and documents

- [ ] T-U03-014 Documentation: a section "Experience session" in `Packages/VisualCoreRendering/README.md`, the session in `docs/getting-started.md`, Auto-Creator.md section 11.4 brought in line with what was built (open request with a factory, newest open wins, memory-pressure limit) and section 16, notes in `docs/migration/path-map.json`. Proof: `python3 scripts/render_autocreator.py --check`, `python3 scripts/validate_autocreator.py` and `python3 scripts/validate_docs.py` pass.
- [ ] T-U03-015 API baseline, rules and boundaries (FR-U03-101, FR-U03-102, FR-U03-103; SC-U03-009): `python3 scripts/check_public_api.py --update` leaves no difference and the check passes with 0 undocumented symbols; `git diff 91c507d -- docs/api/visualcore-public-api.txt` removes no line; `git diff --stat 91c507d -- Apps Showcase Harnesses External Vendor project.yml` prints nothing; no network, store, advertising or reference-engine name and no file access in the new sources; record `run-check --name public-api`, `--name dependencies -- python3 scripts/check_dependencies.py` and `--name documented-api-showcase`, `documented-api-interactivedemo`, `documented-api-secondconsumer`.
- [ ] T-U03-016 Consumers: after `python3 scripts/release_check.py --only xcodegen`, build for testing into new derived-data folders `Build/DerivedData/ua-f03-<Scheme>` the schemes `Showcase`, `GenerativeArtStudio`, `FluidArtPlayground`, `FractalExplorer`, `ParticleUniverse` of `VisualCore.xcodeproj` and the harness projects `InteractiveDemo` and `SecondConsumer`, recorded as `build-<Scheme>`. Expected: exit 0 seven times and no tracked file changed.

## Phase 6: Evidence and convergence

- [ ] T-U03-017 Evidence `host-visualcore`: `swift test --package-path Packages/VisualCore`.
- [ ] T-U03-018 Evidence `rendering-ios27`: `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --result-name ua-f03-ios27` (TEST SUCCEEDED).
- [ ] T-U03-019 Evidence `rendering-ios26`: `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-26.5 --action test --result-name ua-f03-ios26` (TEST SUCCEEDED).
- [ ] T-U03-020 Evidence `pure-ios27` and `pure-ios26`: `python3 scripts/xcodebuild_package.py --package Packages/VisualCore --scheme VisualCore-Package --destination sim-27.2 --action test` and `--destination sim-26.5`.
- [ ] T-U03-021 Evidence `reference-a` and `reference-b`: the two chunks of the ProjectM reference regression (3 of 3 and 4 of 4).
- [ ] T-U03-022 Evidence `script-tests`, `docs`, `steering`: `python3 scripts/test_scripts.py`, `python3 scripts/validate_docs.py`, `python3 scripts/validate_autocreator.py`; then confirm that the `ci` and `push-scan` runs of the last pushed commit succeeded.
- [ ] T-U03-023 Record the final evidence of the brief's third command on the final sources: `run-check --name app-isolation-final -- python3 scripts/check_app_isolation.py --app Apps/VisualCore`.
- [ ] T-U03-024 Run `/speckit-converge` for UA-F03; run `/speckit-implement` for every task it appends and `/speckit-converge` again, until a run appends nothing; then `python3 scripts/migration_ledger.py seal --gate UA-F03` and `python3 scripts/migration_ledger.py record --gate UA-F03`.
- [ ] T-U03-025 {device} After ImplementationLock-100, on D1, D2 and D3: run a session of the sample and of three real experiences for 30 minutes each and record memory footprint and thermal state over time (FR-U03-104). Not run before the lock; stays open and does not block the gate.

## Analyze fixes (2026-11-12, owner delegation)

`/speckit-analyze` run 1 found no critical or high finding and three lower ones, all applied before run 2:

- C1: T-U03-004 now names SC-U03-001 and covers opens during preparing, failed and message.
- I1: T-U03-007 names its requirements through the three test tasks instead of a range with gaps.
- I2: plan.md lists `ModuleTests.swift` as modified.

`/speckit-analyze` run 2: 41 of 41 functional requirements and 10 of 10 success criteria are named by a task; 25
tasks, each mapped; plan.md and tasks.md name the same files; every check name of quickstart.md has a task; no
constitution conflict. No critical, high or medium finding remains.

## Dependencies & Execution Order

- T-U03-001 first. T-U03-002/003 block the session. T-U03-004, 005, 006 (three test files) before T-U03-007;
  T-U03-008 before T-U03-009; T-U03-011 before T-U03-012.
- T-U03-014 to T-U03-023 come after all code; evidence runs on the final sources, one heavy build at a time.
- T-U03-025 runs after ImplementationLock-100.

### Parallel Opportunities

- After T-U03-001: 002+003 (pure), 004, 005, 006 (three test files), 011+012 (tool) in parallel agents; the lead
  writes 007.
- 008+009 by one agent once the session's API compiles.

## Implementation Strategy

MVP is the session with open, close and the resource proof. Failure handling, cancellation, phases and memory are
parts of the same class and are proven by their own test classes. The host view and the tool follow. Evidence is
collected at the end on the final sources.

## Notes

- A test task is committed together with the implementation task that follows it.
- An agent's report is not evidence: every proof command is run by the lead before the task is ticked.
- T-U03-025 is a device task: it stays open and does not block the gate, which is recorded by T-U03-024.
