---

description: "Task list for feature 186 — UA-F00 governance tooling (migration ledger gate UA-F00)"
---

# Tasks: UA-F00 — Governance tooling: feature numbering, validators and ledger operation

**Input**: `specs/186-ua-f00-governance-tooling/` (spec, plan, research, data-model, contracts/tools.md,
contracts/ci.md, quickstart).

**Tests** are required by the specification (acceptance items 2, 5 and 7): every change is proven by a self-test in
`scripts/test_scripts.py` that is written first and seen to fail.

**Conventions**: ids `T-U00-###`; one commit and push per task through `scripts/tick_task.py` (evidence text only);
gate evidence through `python3 scripts/migration_ledger.py run-check --gate UA-F00 --name <check-name> -- <command>`.
"The commit before the feature" is `a1bc833` (the record of CONSTITUTION-2). All tasks edit the same few files, so
none is marked `[P]`: one writer per file. Review checkpoint after each phase: `python3 scripts/validate_docs.py`
and `python3 scripts/test_scripts.py` pass.

**Not applicable**: VisualCore does not change, so there is no documentation, API-baseline or ProjectM-regression
task. The brief names no device-only and no owner-only item, so there is no `{device}` and no `{owner}` task.

## Phase 1: Setup

- [X] T-U00-001 Confirm the starting state before any change: `python3 scripts/test_scripts.py` ends with `OK` (103 tests), `python3 scripts/validate_docs.py` prints `PASS: 36 feature dossiers checked, 0 problems`, `python3 scripts/migration_ledger.py show --gate UA-F00` prints `UNMET: none`, and `git status --short` is empty. Expected result: all four as stated; record the test count and the elapsed time as the baseline for SC-U00-009. — Verified 2026-11-11: python3 scripts/test_scripts.py: Ran 103 tests in 5.7 s, OK (baseline for SC-U00-009); validate_docs.py PASS 36 dossiers, 0 problems; migration_ledger.py show --gate UA-F00: UNMET none; git status --short empty

## Phase 2: Foundational (test harness; blocks every story)

- [ ] T-U00-002 In `scripts/test_scripts.py` add the shared helpers the story tests need: load the modules `tick_task` and `speckit_prompts`, and a `GitSandbox` helper that creates a temporary repository on branch `main` with a local identity, a bare remote named `origin`, a minimal constitution and one first commit pushed, and that can report the remote's head and the number of commits. Add one test `GitSandboxTests.test_sandbox_pushes_to_its_bare_remote`. Expected result: the new test passes and the suite ends with `OK`.
- [ ] T-U00-003 In `scripts/test_scripts.py` hash every file under `.autonomy/migration/` before the suite runs and again after it, print `ledger tree unchanged: <hash>`, and exit with a failure when the two differ (FR-U00-038, research R9). Expected result: `python3 scripts/test_scripts.py` prints the line and exits 0; `git status --short .autonomy/migration` is empty afterwards.

**Checkpoint**: harness ready.

## Phase 3: User Story 1 - A dossier of any planned feature validates in its own namespace (Priority: P1) 🎯 MVP

**Goal**: the document validator enforces the whole numbering map with one exact id shape per directory form.

**Independent Test**: `DocsTests` build temporary repositories with one dossier per form and one defect at a time.

### Tests for User Story 1 (written first, must fail)

- [ ] T-U00-004 [US1] In `scripts/test_scripts.py` (`DocsTests`) add tests for gaps G-01 to G-06: (a) `namespace()` returns "" for `000-x`, `235-x`, `300-x`, `551-x`, `r02-f01-x`, `r13-f01-x`, `r03-g26-01-x`, `r03-g01-11-x`, `r03-g01-x` and `r03-f00-x`; (b) a directory `specs/notes` and a directory `specs/r3-g1-x` are reported as outside the numbering map; (c) `id_shape()` exists and an id whose namespace only begins with the expected one (in `r03-f01-x` an id of the namespace with one more digit, `R03F011`; in `001-x` an id with four digits after `F`) is reported as outside the namespace; (d) a task id of another namespace in `tasks.md` is reported; (e) for each of the five new namespaces U<kk>, R02F<ff>, R02G<gg><ff>, RnnFff and RnnGggff one dossier that is accepted and one that is rejected (ten sub-cases, named in the assertion message; FR-U00-008); (f) every `spec_dir` of the real migration ledger maps to a namespace and no two gates share one (823 directories); (g) the summary line counts round directories too. Expected result: the new tests fail against the current validator (list the failing test names in the evidence) and the 103 existing tests still pass.

### Implementation for User Story 1

- [ ] T-U00-005 [US1] In `scripts/validate_docs.py` implement data-model.md section 1: round directories only for rounds 03–12, games 01–25, game features 01–10 and shared features 01–99; numbered directories only 001–234 and 301–550; every directory directly under `specs/` is examined and reported when it is outside the map; `id_shape(feature_dir)` gives the exact shape ("`F<k>` + two digits", "`A<nn>-<p>` + two digits", "`<ns>-` + three digits") and is applied to defined ids and to task ids; the summary counts every dossier directory (FR-U00-001 to FR-U00-005). Keep every existing check and message (FR-U00-006). Expected result: the tests of T-U00-004 pass, the suite ends with `OK`, and `python3 scripts/validate_docs.py` prints `PASS: 36 feature dossiers checked, 0 problems`.
- [ ] T-U00-006 [US1] Acceptance of User Story 1 (FR-U00-007, SC-U00-001, SC-U00-002, SC-U00-003): run `python3 scripts/validate_docs.py` and `git diff --stat a1bc833 -- "specs/0[0-2][0-9]-*" "specs/03[0-5]-*"`. Expected result: `PASS … 0 problems`; the diff prints nothing; at least ten namespace sub-cases and at least six out-of-map directories are asserted in `DocsTests`.

**Checkpoint**: numbering enforced; the 35 sealed dossiers untouched.

## Phase 4: User Story 2 - A verified task is ticked, committed and pushed in one safe step (Priority: P1)

**Goal**: the tick tool refuses early, restores on failed validation, and pushes only on `main` after a clean scan.

**Independent Test**: `TickTaskTests` run the tool on a `GitSandbox`.

### Tests for User Story 2 (written first, must fail)

- [ ] T-U00-007 [US2] In `scripts/test_scripts.py` add `TickTaskTests` on a `GitSandbox`: (a) one task in each of the seven directory forms is ticked and its line reads `- [X] <id> … — Verified <local date>: <evidence>`, with one new commit whose message has no `Co-Authored-By` and no `Generated with` line; (b) each refusal leaves `tasks.md` byte-identical and adds no commit: task list missing, task missing, task already ticked, task listed twice, empty evidence, evidence with a line break; (c) a tick after which validation fails (the task list holds an id of another namespace) restores the previous bytes, adds no commit and returns a failure; (d) on a branch other than `main` the commit exists and the remote is unchanged; (e) on `main` with a clean scan the remote's head equals the new commit; (f) on `main` with a finding in the outgoing commit the commit stays local, the remote is unchanged and the tool fails with a message that contains `NOT pushed` and `prepush_scan.py --push`; (g) with an unreachable remote the tool fails with the same message. Expected result: the tests fail because `tick_task.main` takes no arguments; the earlier tests still pass.

### Implementation for User Story 2

- [ ] T-U00-008 [US2] In `scripts/tick_task.py` implement research R3 and contracts/tools.md section 2: `main(argv=None, root=ROOT)`; early refusals before any write; write through a temporary file and `os.replace`; call `validate_docs.validate(root)` in process and restore the saved bytes on a problem; commit with `git commit -q -m`; on `main` call the scan in process and push with `git push -q origin main`; fail with `committed but NOT pushed` and the command `python3 scripts/prepush_scan.py --push` when the scan finds something or the push fails (FR-U00-010 to FR-U00-014). Expected result: `TickTaskTests` pass and the suite ends with `OK`.
- [ ] T-U00-009 [US2] Acceptance of User Story 2 (SC-U00-004): run `python3 scripts/test_scripts.py` and confirm that this task itself is ticked with the rebuilt tool. Expected result: `OK`; the tick of this task produces exactly one commit on `main` that is pushed (`git status --short --branch` shows `main...origin/main` without "ahead").

**Checkpoint**: ticks are safe.

## Phase 5: User Story 3 - Nothing private leaves the Mac (Priority: P1)

**Goal**: every scan pattern and forbidden path class is data with a fixture; simulator identifiers are accepted by
hash.

**Independent Test**: `PrepushScanTests`.

### Tests for User Story 3 (written first, must fail)

- [ ] T-U00-010 [US3] In `scripts/test_scripts.py` rewrite and extend `PrepushScanTests`: (a) a fixture table with one finding line and one clean line for each label of data-model.md section 3 (thirteen labels) and a coverage test that fails, naming the label, when `prepush.PATTERNS` has a label without a fixture; (b) the same for the nine forbidden path classes of data-model.md section 4 through `prepush.FORBIDDEN`; (c) allowed look-alikes: synthetic identifier, `git@github.com`, `/Users/<name>/`, `/Users/Shared/`; (d) hash list: an identifier whose SHA-256 (upper case, UTF-8) is in the list is accepted in upper and lower case, any other is a finding; `record_simulators` adds hashes, keeps recorded ones, writes "sorted and without duplicates", stores no identifier, and a second call changes no byte; a list with another schema or invalid JSON is a finding from `scan` and stops the recorder; a missing list is empty; when the simulator list cannot be read the recorder writes nothing and fails, and the scan still works without a simulator list (as on a CI runner); (e) on a `GitSandbox`: an unreadable range is a finding, `main(["--push"])` pushes when clean on `main`, does not push with a finding, does not push on another branch, and `main(["--range", …])` exits 1 for a range with one seeded finding (SC-U00-008). Expected result: the new tests fail against the current scanner; the tests outside `PrepushScanTests` still pass.

### Implementation for User Story 3

- [ ] T-U00-011 [US3] In `scripts/prepush_scan.py` implement research R4 and R5 and contracts/tools.md section 3: `PATTERNS` with one labelled entry per kind (thirteen labels), `FORBIDDEN` as labelled patterns (nine classes), `load_hashes(root)`, `record_simulators(root, identifiers)`, `--record-simulators`, acceptance of a simulator-form identifier only when it is synthetic or its hash is in `Configs/simulator-identifier-hashes.json`, the finding `simulator identifier not recorded` with the recording command when the machine's simulator list knows the identifier, and a finding for an unreadable hash list (FR-U00-020 to FR-U00-026). Update the module description so that it lists exactly what the code finds. Expected result: `PrepushScanTests` pass and the suite ends with `OK`.
- [ ] T-U00-012 [US3] Create `Configs/simulator-identifier-hashes.json` with `python3 scripts/prepush_scan.py --record-simulators`, run the command a second time, and describe the command in `setup.md` section 5.1. Expected result: the first run reports the number of hashes added (one per simulator of this Mac), the second run reports 0 added and `git status --short Configs/` shows no further change; the file holds `"schema": 1`, only 64-digit hexadecimal strings and no identifier of the 8-4-4-4-12 form; `python3 scripts/prepush_scan.py` passes; `python3 scripts/validate_autocreator.py` passes.
- [ ] T-U00-013 [US3] Acceptance of User Story 3 (SC-U00-005): run `python3 scripts/test_scripts.py` and `python3 scripts/prepush_scan.py`. Expected result: `OK`; `PASS: pre-push scan … 0 findings`; the coverage tests assert thirteen pattern labels and nine forbidden path classes.

**Checkpoint**: the scan is the same on the Mac and anywhere else.

## Phase 6: User Story 4 - A gate is recorded only in order and only from real evidence (Priority: P1)

**Goal**: every refusal of the ledger tool is proven on a temporary root; damaged files stop the tool cleanly; one
writer, two pushers.

**Independent Test**: `MigrationLedgerTests` and `GovernanceTests`.

### Tests for User Story 4 (written first, must fail where behavior is missing)

- [ ] T-U00-014 [US4] In `scripts/test_scripts.py` extend `MigrationLedgerTests` and add `GovernanceTests`: (a) `seal` and `record` are refused for a gate with an unmet dependency, naming the unmet gate (FR-U00-030); (b) `run-check`, `seal` and `record` are refused for a device row and a device campaign while `ImplementationLock-100` is not pass, and the ledger file is byte-identical afterwards (FR-U00-033); (c) a ledger that is not valid JSON, an attestation that is not valid JSON at `seal`, and an evidence file that is not valid JSON at `record` each stop the tool with a message that contains `cannot read` and the file name, and nothing is written; a ledger with `"schema": 2` and a missing ledger keep their messages (FR-U00-036); (d) `validate` reports a gate that is pass without evidence (FR-U00-037); (e) `GovernanceTests.test_only_the_ledger_tool_writes_the_ledger`: among the tracked files under `scripts/`, `Tools/python/` and `.github/`, only the reviewed readers `scripts/validate_autocreator.py`, `scripts/render_autocreator.py`, `scripts/build_traceability_matrix.py` and the test file name the ledger file besides `scripts/migration_ledger.py`, and no reader has a line that names the ledger together with a write call (FR-U00-039); (f) `GovernanceTests.test_only_two_tools_push`: only `scripts/tick_task.py` and `scripts/prepush_scan.py` contain a Git push among the tracked scripts and workflows (FR-U00-015); (g) `seal` is refused when the log of a passing check was removed (FR-U00-032); (h) `GovernanceTests.test_tools_use_only_the_standard_library`: `validate_docs.py`, `tick_task.py`, `prepush_scan.py`, `migration_ledger.py` and `planning_index.py` import only standard-library modules and each other, and none imports a network module (FR-U00-061). Expected result: the damaged-file tests fail (a `JSONDecodeError` is raised); the other new tests pass or fail as the audit predicts, and the evidence names which.

### Implementation for User Story 4

- [ ] T-U00-015 [US4] In `scripts/migration_ledger.py` make `read_json()` fail with the tool's own message `cannot read <file>: <reason>` for invalid JSON and for a file that cannot be read (research R10); no other behavior changes. Expected result: the tests of T-U00-014 pass, the suite ends with `OK` and prints `ledger tree unchanged`, and `python3 scripts/migration_ledger.py validate` prints `PASS: migration ledger, 0 problems`.
- [ ] T-U00-016 [US4] Acceptance of User Story 4 (SC-U00-006): run `python3 scripts/test_scripts.py`. Expected result: `OK`; each of the six refusals of the brief (dependency order FR-U00-030, duplicate attestation FR-U00-031, changed log FR-U00-032, device gate before the lock FR-U00-033, Claude CLI FR-U00-034, legacy gates of an original app FR-U00-035) has at least one passing test, named in the evidence; the suite reports the same ledger tree hash before and after.

**Checkpoint**: the ledger refuses everything it must.

## Phase 7: User Story 5 - Every pending launch feature has its eight prompts (Priority: P2)

**Goal**: a function and a command that walk every pending launch feature; exact directory and ids in the override
note.

**Independent Test**: `PromptCoverageTests`.

### Tests for User Story 5 (written first, must fail)

- [ ] T-U00-017 [US5] In `scripts/test_scripts.py` add `PromptCoverageTests`: (a) `planidx.prompt_coverage(ROOT_DIR)` returns no problem, a feature count equal to the number of pending original-app phases in the legacy ledger plus the pending unified-app, shared and game gates of the migration ledger, and a prompt count of eight times that; (b) on a temporary copy of the catalog files, removing one stage of one round feature from the feature index, and emptying one stage prompt of one phase in the manifest, each give a problem that names the feature and the stage; (c) a superseded shared feature is not walked; (d) where `.autonomy/context` exists, the manifest entries of the pending phases equal what `speckit_prompts` builds from the extraction, otherwise that sub-check is skipped with a message; (e) `planidx.override_ids()` for every pending round feature names the gate's `spec_dir` and the three id forms of the namespace `docs.namespace()` gives, and the printed output of `prompt --feature R02-G01-01 --stage specify --override` ends with that sentence after the existing canonical override paragraph, while the archived prompt text is unchanged. Expected result: the tests fail because the functions do not exist.

### Implementation for User Story 5

- [ ] T-U00-018 [US5] In `scripts/planning_index.py` implement research R7 and R8 and contracts/tools.md section 5: `prompt_coverage(root)`, the command `coverage` (prints `PASS: <features> pending launch features, <prompts> stage prompts, 0 problems` or the problems and `FAIL`), `override_ids(root, feature)`, and the extra sentence in `prompt --override` for archived round features (FR-U00-040 to FR-U00-042). Each archive file is read once per run. Expected result: `PromptCoverageTests` pass; `python3 scripts/planning_index.py coverage` prints the counts (953 and 7,624 while no further gate has passed) and exits 0; `python3 scripts/planning_index.py verify` still passes.
- [ ] T-U00-019 [US5] Describe the override sentence and the `coverage` command where the book describes them: `Auto-Creator.md` section 21.2 (the sentence that `--override` adds for a round feature) and section 25.3 (the validator table gains `python3 scripts/planning_index.py coverage`), edited in place; run `python3 scripts/render_autocreator.py` and `python3 scripts/validate_autocreator.py`. Expected result: `PASS: steering documents, 16 checks, 0 problems` and `PASS: generated blocks of Auto-Creator.md`.
- [ ] T-U00-020 [US5] Acceptance of User Story 5 (SC-U00-007): run `python3 scripts/planning_index.py coverage` and `python3 scripts/planning_index.py prompt --feature R02-G01-01 --stage specify --override`. Expected result: the coverage line with both counts and 0 problems; the prompt output ends with `Canonical override: feature directory specs/301-aurora-loom-playable-rule-kernel; requirement ids FR-R02G0101-###, success criteria SC-R02G0101-###, task ids T-R02G0101-###.`

**Checkpoint**: no pending launch feature lacks a prompt.

## Phase 8: User Story 6 - CI repeats the governance checks on every push (Priority: P2)

**Goal**: four validator steps in `ci.yml`; the scan of the pushed range in its own workflow; both confirmed by a
real run.

**Independent Test**: `GovernanceTests` for the workflow files; real runs on GitHub.

### Tests for User Story 6 (written first, must fail)

- [ ] T-U00-021 [US6] In `scripts/test_scripts.py` add `GovernanceTests.test_ci_runs_the_governance_checks`: `.github/workflows/ci.yml` contains the four commands `python3 scripts/validate_autocreator.py`, `python3 scripts/planning_archive.py verify`, `python3 scripts/planning_index.py verify` and `python3 scripts/migration_ledger.py validate`; `.github/workflows/push-scan.yml` exists and contains `fetch-depth: 0`, `cancel-in-progress: false`, a group that includes the commit, `timeout-minutes`, `contents: read`, the triggers push to `main` and pull request, and `python3 scripts/prepush_scan.py --range`; neither workflow names a secret. Expected result: the test fails because the steps and the file do not exist.

### Implementation for User Story 6

- [ ] T-U00-022 [US6] Modify `.github/workflows/ci.yml` (four steps after "Docs", contracts/ci.md section 1) and create `.github/workflows/push-scan.yml` (contracts/ci.md section 2: `ubuntu-latest`, 10 minutes, `fetch-depth: 0`, group `push-scan-<commit>` with `cancel-in-progress: false`, range `<before>..<after>` for a push and `<base>...<head>` for a pull request, commit ids passed through environment variables) (FR-U00-050 to FR-U00-052). Expected result: the test of T-U00-021 passes, the suite ends with `OK`, and `python3 scripts/prepush_scan.py --range "HEAD~1..HEAD"` exits 0 on this Mac.
- [ ] T-U00-023 [US6] Update the documents that describe CI and the tools, in place: `Auto-Creator.md` section 24.1 (what CI runs now; the scan workflow and why it is never cancelled) and section 19.4 (the tick tool restores the task list when validation fails), `README.md` (workflow list and CI paragraph), and set the state of this gate's part in `docs/migration/path-map.json` as its `states` allow (an entry shared with later gates stays pending and gets a note). Run `python3 scripts/render_autocreator.py`, `python3 scripts/validate_autocreator.py` and `python3 scripts/validate_docs.py`. Expected result: all three pass.
- [ ] T-U00-024 [US6] Confirm the workflows by real runs on the commit that T-U00-022 pushed or a later one (FR-U00-053, SC-U00-008): read the run ids with `gh run list --branch main --workflow ci --limit 1` and `gh run list --branch main --workflow push-scan --limit 1`, then record `python3 scripts/migration_ledger.py run-check --gate UA-F00 --name ci-run -- gh run watch <ci id> --exit-status` and `… --name push-scan-run -- gh run watch <scan id> --exit-status`. Expected result: both checks exit 0; the evidence text names both run ids, their commit and their conclusion `success`. A red run is repaired and watched again under a new check name; the failed attempt stays in the record.

**Checkpoint**: CI is the second look.

## Phase 9: Evidence and convergence

**Purpose**: one task per evidence command of quickstart.md, the boundary checks, and the convergence loop. The
checks run on a clean tree after the last source change.

- [ ] T-U00-025 Record `script-tests`: `python3 scripts/migration_ledger.py run-check --gate UA-F00 --name script-tests -- python3 scripts/test_scripts.py`. Expected result: exit 0; the attestation's `elapsed_seconds` is under 300 (SC-U00-009); the evidence text gives the test count and the elapsed time.
- [ ] T-U00-026 Record `docs`: `… --name docs -- python3 scripts/validate_docs.py`. Expected result: exit 0, `PASS … 0 problems`.
- [ ] T-U00-027 Record `steering`: `… --name steering -- python3 scripts/validate_autocreator.py`. Expected result: exit 0, `PASS: steering documents, 16 checks, 0 problems`.
- [ ] T-U00-028 Record `ledger`: `… --name ledger -- python3 scripts/migration_ledger.py validate`. Expected result: exit 0, `PASS: migration ledger, 0 problems`.
- [ ] T-U00-029 Record `prepush-scan`: `… --name prepush-scan -- python3 scripts/prepush_scan.py`. Expected result: exit 0, `PASS: pre-push scan … 0 findings`.
- [ ] T-U00-030 Record `prompt-coverage`, `archive` and `index`: `… --name prompt-coverage -- python3 scripts/planning_index.py coverage`, `… --name archive -- python3 scripts/planning_archive.py verify`, `… --name index -- python3 scripts/planning_index.py verify`. Expected result: three exits 0 with their `PASS` lines; the coverage line gives both counts.
- [ ] T-U00-031 Record the boundary checks (FR-U00-060, SC-U00-002, SC-U00-010): `… --name scope-untouched -- git diff --quiet a1bc833 -- Apps Packages Showcase Harnesses External Vendor Tools .autonomy/state.json` and `… --name sealed-dossiers-untouched -- git diff --quiet a1bc833 -- "specs/0[0-2][0-9]-*" "specs/03[0-5]-*"`. Expected result: both exit 0 (no difference).
- [ ] T-U00-032 Run `/speckit-converge` with its supplied prompt and override; implement what it appends with `/speckit-implement`; repeat until a run appends nothing and reports what it checked. If a source file changed after T-U00-025 to T-U00-031, rerun the affected checks under new names. Record `… --name unchanged-since-ci -- git diff --quiet <commit of the watched CI runs> HEAD -- scripts .github Configs` (exit 0: the tools, the workflows and the hash list are the ones CI ran); if it differs, watch new runs first. Then `python3 scripts/migration_ledger.py seal --gate UA-F00 && python3 scripts/migration_ledger.py record --gate UA-F00`, write the milestone bundle of M1 (`git bundle create ../VisualCore-backups/VisualCore-UA-F00-<short commit>.bundle --all`), commit and push. Expected result: the last convergence run appends no task; `python3 scripts/migration_ledger.py show --gate UA-F00` shows `"status": "pass"`; `python3 scripts/migration_ledger.py validate` passes; `git bundle verify` accepts the bundle.

## Analyze fixes (2026-11-11, owner delegation)

Run 1 found no critical finding and two high ones. C1: FR-U00-061 had no task; it now has a provable form and the
test (h) in T-U00-014. I1: FR-U00-002 states the full bounds of the map that data-model.md section 1 uses. Medium:
C2 the requirements FR-U00-008, 031, 032, 034 and 035 are referenced by their tasks and a removed log gets a test;
U1 an unreadable simulator list and a machine without one are tested in T-U00-010; I2 plan and tasks name the same
sections of Auto-Creator.md (19.4, 21.2, 24.1, 25.3); I3 data-model.md says that "simulator identifier not
recorded" is a message of the UUID pattern; U2 T-U00-032 records that the tools, workflows and hash list did not
change after the watched CI runs. Low, kept: D1 (FR-U00-024 and FR-U00-051 both fail an unreadable range, one in
the tool and one in CI). Run 2: 50 of 50 requirements and criteria are referenced by a task; no critical or high
finding; no speculative dependency (`gh`, Git and Python 3 are present; the scan needs no simulator list).

## Dependencies & Execution Order

### Phase Dependencies

- Phase 1 → Phase 2 → Phases 3 to 8 in the order written → Phase 9.
- Every phase edits `scripts/test_scripts.py`, so the phases run one after another (one writer per file).

### User Story Dependencies

- **US1** needs only the harness.
- **US2** needs US1 (the tick tool calls the validator in process) and the `GitSandbox`.
- **US3** needs the `GitSandbox`. It must be complete (T-U00-012 included) before any later commit adds a simulator
  identifier; none of this feature's commits does.
- **US4** is independent of US1 to US3 apart from the test file.
- **US5** needs US1 (`namespace()` for the override sentence).
- **US6** needs US3 (the scan that CI runs must use the hash list) and US5 only for the documents.

### Within Each User Story

Tests first and seen to fail, then the implementation, then the acceptance task. Each task is one commit.

### Parallel Opportunities

None is used. The tasks share `scripts/test_scripts.py`, `Auto-Creator.md` and `tasks.md`; the integration session
owns them, and the owner has switched subagents off.

## Implementation Strategy

### MVP First (User Story 1 Only)

Phases 1 to 3 give a validator that enforces the whole numbering map; every later dossier depends on it.

### Incremental Delivery

US1 (numbering) → US2 (safe ticks) → US3 (scan) → US4 (ledger refusals) → US5 (prompts) → US6 (CI). After each
story the suite is green and the repository is pushed; nothing is half-built between tasks.

## Notes

- A task is ticked only with reproduced evidence: `python3 scripts/tick_task.py specs/186-ua-f00-governance-tooling
  <task-id> "<evidence>" "<commit subject>"`.
- Until T-U00-008 the existing tick tool is used; from T-U00-009 on, the rebuilt one.
- Commits carry no trailers. Every push goes through the pre-push scan.
- No task changes `Apps/`, `Packages/`, `Showcase/`, `Harnesses/`, `External/`, `Vendor/`, `Tools/python/`,
  `.autonomy/state.json` or `specs/001`–`035`.
