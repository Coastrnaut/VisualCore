# Feature Specification: UA-F00 — Governance tooling: feature numbering, validators and ledger operation

**Feature Branch**: `186-ua-f00-governance-tooling` (spec directory only; work stays on `main`)

**Created**: 2026-11-11

**Status**: Draft

**Ledger gate**: UA-F00 (migration ledger) · ID namespace FR-U00-###, SC-U00-###, T-U00-###

**Input**: User description: the UA-F00 `/speckit-specify` prompt of Auto-Creator.md section 20
(`docs/catalog/unified-app-features.json`), verbatim in the invocation.

Canonical overrides:
- **Feature directory and ids:** `specs/186-ua-f00-governance-tooling`; requirement ids FR-U00-###, success criteria
  SC-U00-###, task ids T-U00-###.
- **Who the users are:** the autonomous engineer and the owner. They specify features, tick tasks, record gates and
  push commits with the repository's own tools. Nothing in this feature is visible in the app.
- **Tools named by the brief:** the document validator (`scripts/validate_docs.py`), the tick tool
  (`scripts/tick_task.py`), the pre-push scan (`scripts/prepush_scan.py`), the migration ledger tool
  (`scripts/migration_ledger.py`), the steering validator (`scripts/validate_autocreator.py`), the archive and index
  verifiers (`scripts/planning_archive.py`, `scripts/planning_index.py`), the phase prompt tool
  (`scripts/speckit_prompts.py`), the self-tests (`scripts/test_scripts.py`) and the CI workflow
  (`.github/workflows/ci.yml`). Other modules are not named.
- **Out of scope:** any app or framework source; the legacy ledger `.autonomy/state.json` and its tool
  `Tools/python/desktop_runbook.py`.
- **Device-only and owner-only items:** none.

## Clarifications

### Session 2026-11-11

Answered by the engineer under the owner's standing delegation (ADR-0004 decision 3), recommended option first. No
question concerned a VisualCore or Apple API, a thread-ownership rule or a device measurement: the feature has none.

- Q: How does the scan in CI reach the same verdict as the scan on the development Mac for the identifiers of that
  Mac's simulators, which only that Mac can list? → A: Through one tracked list of SHA-256 hashes of those
  identifiers. A scan command records the hashes from the Mac's simulator list; the scan, on the Mac and in CI,
  accepts an identifier of that form only when its hash is in the list. A simulator of the Mac that is not recorded
  yet is a finding that names the recording command. Rejected: accepting identifiers by file path (identifiers of
  physical devices have the same form and would pass), and tracking readable identifiers (they would be copied
  into commands).
- Q: Which commits does the scan read in CI, given that CI cancels a running check when a newer push arrives? → A:
  The scan is a job that a newer push never cancels. It fetches the full history and reads the commits from the
  commit before the push to the pushed commit, or, for a pull request, from the merge base to its head. When the
  earlier commit is unknown or cannot be reached, the job fails. Rejected: scanning inside the cancellable job (a
  cancelled run would leave its commits unread) and scanning the whole history on every push (old, already
  published lines would fail every run).
- Q: How is "the tick tool and the scan are the only way a commit is pushed" backed, since tracked files cannot stop
  a plain Git push? → A: By procedure, by a self-test that no other tracked script or workflow pushes, and by the CI
  scan that reads every pushed range. No Git hook is installed: a hook lives in untracked local configuration, can
  be skipped with a flag, and changing the owner's local Git configuration is not this feature's business.
- Q: Do the stricter id rules (exact namespace, task ids included) apply to the 35 sealed dossiers as well? → A:
  Yes, one rule for every dossier. The exact shape per directory form is: foundation F<k> followed by two digits,
  original app phase A<nn>-<p> followed by two digits, and every new namespace followed by a hyphen and three
  digits. The 35 dossiers already conform (checked on 2026-11-11: 0 deviations among their defined ids and task
  ids), so none of their files changes.
- Q: Must the override note of an archived round feature name the exact feature directory and id forms, as the
  notes of the unified-app features do, or is the reference to the numbering section enough? → A: It names them.
  The prompt tool adds one generated sentence with the feature's directory from the ledger and its three id forms,
  derived by the same rule the validator uses. The archived prompt text and the three canonical override
  paragraphs stay unchanged. This removes a manual derivation that would otherwise be repeated for 788 features.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A dossier of any planned feature validates in its own namespace (Priority: P1) 🎯

The engineer creates the dossier of a unified-app feature, a Round 2 shared feature, a Round 2 game feature or a
feature of Rounds 3 to 12. The document validator accepts the directory, knows which id namespace belongs to it, and
rejects an id from another namespace, a duplicate id and a directory that the numbering map does not contain. The 35
sealed dossiers keep passing without a change.

**Why this priority**: every later feature is specified in one of these directories. If the validator rejected a
valid dossier, or accepted a wrong id, no later gate could be trusted.

**Independent Test**: build a temporary repository with one dossier per directory form, run the validator, and see
zero problems; then break one id or one directory name at a time and see exactly the expected problem.

**Acceptance Scenarios**:

1. **Given** a dossier in a directory numbered 186 to 200, **When** the validator runs, **Then** it accepts ids of
   the form U<kk> for that feature and reports no problem.
2. **Given** dossiers in directories 201 to 234, 301 to 550, `rNN-fFF-*` and `rNN-gGG-FF-*`, **When** the validator
   runs, **Then** each is accepted with its own namespace (R02F<ff>, R02G<gg><ff>, RnnFff, RnnGggff).
3. **Given** a specification that defines a requirement id of another feature's namespace, **When** the validator
   runs, **Then** it reports the id and the namespace it should have had, and exits with a failure.
4. **Given** a task list whose task id belongs to another feature's namespace, **When** the validator runs,
   **Then** it reports that task id and exits with a failure.
5. **Given** the same requirement, success-criterion or task id in two dossiers, **When** the validator runs,
   **Then** it reports the id and both places.
6. **Given** a directory outside the numbering map (for example a number between 235 and 300, a number above 550, a
   round directory for a round below 3 or above 12, or a game directory without a feature number), **When** the
   validator runs, **Then** it reports the directory as outside the map.
7. **Given** the repository as it is, **When** the validator runs, **Then** the 35 sealed dossiers pass and none of
   their files has changed.

---

### User Story 2 - A verified task is ticked, committed and pushed in one safe step (Priority: P1)

After reproducing a task's proof, the engineer ticks the task with the tick tool. The tool marks exactly that task
with the date and the evidence, checks the documents, commits without trailers and, only on `main` and only after a
clean pre-push scan, pushes. When anything is wrong it changes nothing.

**Why this priority**: a tick is the project's unit of progress and a push is the only action that leaves the Mac.
Both must be impossible to do wrongly by accident.

**Independent Test**: in a temporary repository with a bare remote, tick one task per namespace and check the
resulting line, commit and push; then provoke each refusal and check that the task file, the history and the remote
are unchanged.

**Acceptance Scenarios**:

1. **Given** an unticked task of any namespace of the numbering map, **When** the engineer ticks it with evidence,
   **Then** the task line reads `- [X] <id> … — Verified YYYY-MM-DD: <evidence>` and one commit without trailers
   holds the change.
2. **Given** a task that is missing, already ticked or listed twice, or evidence that is empty or spans several
   lines, **When** the engineer ticks, **Then** the tool refuses, the task file is byte-identical to before and no
   commit is made.
3. **Given** a tick after which the document validator fails, **When** the tool runs, **Then** it refuses, restores
   the task file and makes no commit.
4. **Given** a checkout on a branch other than `main`, **When** a task is ticked, **Then** the commit is made and
   nothing is pushed.
5. **Given** a checkout on `main` and a clean scan, **When** a task is ticked, **Then** the commit is pushed to
   `origin main` without force.
6. **Given** a checkout on `main` and a scan with a finding, **When** a task is ticked, **Then** the commit stays
   local, nothing is pushed, and the tool ends with a failure that says so.

---

### User Story 3 - Nothing private leaves the Mac (Priority: P1)

Before any push, the pre-push scan reads the lines that the outgoing commits add and refuses device identifiers,
ECIDs, serial numbers, team ids, e-mail addresses, home paths, private keys and access tokens, and it refuses when a
path that must never be tracked is tracked. Every pattern the scan claims to find, and every forbidden path, is
proven by a self-test, so a pattern cannot silently stop working.

**Why this priority**: the repository is pushed after every commit. One leaked identifier cannot be taken back.

**Independent Test**: run the scan's self-tests; they feed one finding and one clean line per pattern and one path
per forbidden class, and they fail when the scanner gains a pattern that no test covers.

**Acceptance Scenarios**:

1. **Given** an added line with a value of any pattern the scan lists, **When** the scan runs, **Then** it reports
   a finding with the pattern's name and exits with a failure.
2. **Given** an added line with a look-alike that is allowed (a synthetic identifier, an identifier of a simulator
   of the development Mac whose hash is recorded, the allowed service address, a placeholder home path), **When**
   the scan runs, **Then** it reports nothing.
3. **Given** a tracked path of any forbidden class, **When** the scan runs, **Then** it reports the path.
4. **Given** a commit range that cannot be read, **When** the scan runs, **Then** it reports that as a finding and
   never as a pass.
5. **Given** findings, or a branch other than `main`, **When** the scan is asked to push, **Then** it does not push.
6. **Given** a new pattern added to the scanner without a test, **When** the self-tests run, **Then** they fail and
   name the pattern.

---

### User Story 4 - A gate is recorded only in order and only from real evidence (Priority: P1)

The engineer records gates with the migration ledger tool. The tool refuses a gate whose dependencies are open, a
second attestation under a used name, a log that changed after its command ran, any device gate before
`ImplementationLock-100`, the Claude CLI as an evidence command, and an integration gate of an original app whose
legacy phase gates are not all pass. Each refusal is proven by a self-test, and no other tool writes the ledger.

**Why this priority**: the ledger is the only record of progress. A gate recorded out of order, or from evidence
that was not produced by a real command, would make every later claim false.

**Independent Test**: run the ledger self-tests; each builds a temporary ledger, provokes one refusal and checks
that the ledger did not change. The real ledger's hash is the same before and after.

**Acceptance Scenarios**:

1. **Given** a gate with an unmet dependency, **When** a check, a seal or a record is attempted, **Then** the tool
   refuses and names the unmet gate.
2. **Given** an attestation name that was used, **When** the same name is used again for that gate, **Then** the
   tool refuses and no attestation is overwritten.
3. **Given** a log that was altered or removed after its command ran, **When** the gate is sealed, **Then** the tool
   refuses.
4. **Given** `ImplementationLock-100` is not pass, **When** a device row or a device campaign is checked, sealed or
   recorded, or the device guard is asked, **Then** the tool refuses.
5. **Given** an evidence command that is the Claude CLI, a shell wrapper or an inline script, **When** a check is
   requested, **Then** the tool refuses before running anything.
6. **Given** an original app whose seven legacy phase gates are not all pass, **When** its integration gate is
   attempted, **Then** the tool refuses and names the missing legacy gates.
7. **Given** a ledger file that is damaged or has an unknown schema, **When** any command runs, **Then** the tool
   stops with a message that names the file and writes nothing.

---

### User Story 5 - Every pending launch feature has its eight prompts (Priority: P2)

Before the engineer starts a feature, the prompts of all eight Spec Kit stages exist for it. A self-test walks every
pending feature of the launch scope, asks the prompt tools for each stage and fails with the feature and the stage
when a prompt is missing or empty.

**Why this priority**: the procedure forbids hand-written substitutes for a prompt. A missing prompt found in the
middle of the launch work would stop the loop; it is cheaper to find it now.

**Independent Test**: run the prompt coverage self-test; it reports the number of features and prompts it checked.
Removing one prompt in a temporary copy makes it fail with that feature and stage.

**Acceptance Scenarios**:

1. **Given** the pending phases of the original apps, **When** the coverage test runs, **Then** each has a
   non-empty prompt for specify, clarify, plan, checklist, tasks, analyze, implement and converge.
2. **Given** the pending unified-app features, shared round features and game features of Rounds 2 to 4, **When**
   the coverage test runs, **Then** each has a non-empty prompt for the same eight stages, and each prompt printed
   with the override ends with its labelled `Canonical override:` note.
3. **Given** a feature whose prompt for one stage is missing or empty, **When** the coverage test runs, **Then** it
   fails and names the feature and the stage.
4. **Given** a shared round feature that is superseded by a unified-app feature, **When** the coverage test runs,
   **Then** it does not require prompts for it, because that feature is never run.

---

### User Story 6 - CI repeats the governance checks on every push (Priority: P2)

Every push to `main` and every pull request runs, besides the existing gates, the steering validator, the archive
verifier, the index verifier, the migration ledger validation and the pre-push scan over the pushed commits. A red
run is visible and is repaired before the next gate.

**Why this priority**: local checks can be forgotten or bypassed. CI is the independent second look, and it is the
only place that sees a push that did not go through the tools.

**Independent Test**: push the change and watch the real run to its conclusion; separately, run the CI scan command
locally against a range with a seeded finding and see it fail.

**Acceptance Scenarios**:

1. **Given** a push to `main`, **When** CI runs, **Then** the four validators run as steps and a failure of any of
   them fails the run.
2. **Given** a push to `main` or a pull request, **When** CI runs, **Then** the pre-push scan reads exactly the
   commits of that push or pull request and a finding fails the run.
3. **Given** an identifier of a simulator of the development Mac in recorded evidence, **When** CI scans the commit
   that added it, **Then** it is not a finding, exactly as on the development Mac.
4. **Given** a push whose range CI cannot determine or read, **When** the scan step runs, **Then** it fails; it does
   not pass an unread range.
5. **Given** the change of the workflow itself, **When** it is pushed, **Then** a real run on that commit ends in
   success and its identifier and conclusion are recorded as evidence of this feature.

---

### Edge Cases

- **Failure**: a command given to the ledger tool exits with an error or times out. The attestation records the
  failure; the gate cannot be recorded as pass from it; the failed attempt stays in the record.
- **Cancellation**: a tick or a ledger command is interrupted. A tick interrupted before its commit leaves either
  the old task file or the complete new one, never a partial file. An interrupted check leaves at most a log without
  an attestation, which no seal accepts.
- **Lifecycle interruption**: a session ends between seal and record. The next seal replaces evidence that was
  sealed but never recorded; recorded evidence is never replaced.
- **Large input**: the validator handles the full planned set of dossiers (more than 1,200 directories) and the
  scan handles a diff of many megabytes; the scan prints a bounded number of findings and the total count.
- **Corrupted or newer-version data**: a ledger with an unknown schema, a damaged ledger or attestation file, or a
  task list that is missing stops the tool with a message that names the file; nothing is written. An evidence file
  that changed after it was recorded is reported by the ledger validation.
- **Look-alike ids**: an id whose namespace part merely begins with the feature's namespace (a longer feature
  number with the same first digits) is rejected.
- **Two tools, one push**: a push made with plain Git bypasses both tools. It cannot be prevented by tracked files;
  the CI scan of the pushed range is what detects it.
- **Memory pressure**: does not apply; these are short host commands.

## Requirements *(mandatory)*

### Functional Requirements

**Numbering and document validation**

- **FR-U00-001**: The document validator MUST accept a dossier in every directory form of the numbering map and
  derive its id namespace: 001–010 (foundation), 011–185 (original app phases), 186–200 (unified-app features,
  U<kk>), 201–234 (Round 2 shared features, R02F<ff>), 301–550 (Round 2 game features, R02G<gg><ff>), `rNN-fFF-*`
  (shared features of Rounds 3–12, RnnFff) and `rNN-gGG-FF-*` (game features of Rounds 3–12, RnnGggff). Every
  feature directory that the migration ledger names MUST map to exactly one namespace, and no two of them to the
  same one.
- **FR-U00-002**: The document validator MUST report a feature directory that the numbering map does not contain:
  a number from 235 to 300 or above 550, a round directory whose round is not 03 to 12, and a game directory
  without a feature number.
- **FR-U00-003**: The document validator MUST report every requirement id and success-criterion id defined in a
  specification that is not in the namespace of its directory, naming the id and the expected namespace. The id
  MUST have the exact shape of its directory form: the foundation namespace followed by two digits, the app-phase
  namespace followed by two digits, and every other namespace followed by a hyphen and three digits. An id whose
  namespace part only begins with the expected namespace MUST be reported too.
- **FR-U00-004**: The document validator MUST report every task id in a task list that is not in the namespace of
  its directory, by the same exact shape. FR-U00-003 and FR-U00-004 apply to every dossier, the 35 sealed ones
  included.
- **FR-U00-005**: The document validator MUST report a requirement id, success-criterion id or task id that is
  defined more than once, in one dossier or across dossiers, naming both places.
- **FR-U00-006**: The document validator MUST keep its existing checks: a ticked task carries
  `— Verified YYYY-MM-DD:`, references in plans, task lists and contracts point to defined ids, decision records
  carry a date and a status, relative links resolve, and the constitution has a version line and no unresolved
  template token.
- **FR-U00-007**: The 35 sealed dossiers (`specs/001`–`035`) MUST validate with zero problems, and this feature
  MUST NOT change any file in them.
- **FR-U00-008**: Each of the five new namespaces (U<kk>, R02F<ff>, R02G<gg><ff>, RnnFff, RnnGggff) MUST have at
  least one self-test with a dossier that is accepted and one with a dossier that is rejected.

**Ticking, committing and pushing**

- **FR-U00-010**: The tick tool MUST tick exactly one unticked task of any namespace of the numbering map and
  append `— Verified <today>: <evidence>` to its line.
- **FR-U00-011**: The tick tool MUST refuse, change no file and make no commit when the task is missing, is
  already ticked, matches more than one line, when the evidence is empty or contains a line break, or when the task
  list does not exist.
- **FR-U00-012**: The tick tool MUST run the document validator after ticking; when it fails, the tool MUST restore
  the task list to its previous bytes, make no commit and end with a failure.
- **FR-U00-013**: The tick tool MUST commit without co-author or generator trailers.
- **FR-U00-014**: The tick tool MUST push only when the checkout is on `main` and only after the pre-push scan
  passes, to `origin main` and never with force. On another branch it MUST push nothing. When the scan has a
  finding, the commit MUST stay local and the tool MUST end with a failure that states it was not pushed.
- **FR-U00-015**: The tick tool and the pre-push scan MUST remain the two documented ways a commit is pushed; a
  self-test MUST prove that no other tracked script or workflow pushes. No Git hook is installed and no local Git
  configuration is changed.

**Pre-push scan**

- **FR-U00-020**: The pre-push scan MUST have, for every pattern it lists (hardware identifier, device or simulator
  UUID, ECID, serial number, development team id in both written forms, e-mail address, absolute home path, private
  key, and each kind of access token), a self-test with a line that is a finding and a line that is not.
- **FR-U00-021**: The pre-push scan MUST have a self-test for every allowed look-alike: the synthetic identifier
  form, an identifier of a known simulator, the allowed service address and a placeholder home path.
- **FR-U00-022**: The pre-push scan MUST have a self-test for every class of path that must never be tracked
  (private device data, logs, result bundles, reports, the local signing file, provisioning profiles, key stores and
  certificates), and a self-test that the repository tracks none of them.
- **FR-U00-023**: A self-test MUST fail, naming the pattern, when the scanner lists a pattern or a forbidden path
  class that has no fixture in the self-tests.
- **FR-U00-024**: The pre-push scan MUST report a range it cannot read as a finding, and when asked to push it MUST
  push only without findings and only on `main`, never with force.
- **FR-U00-025**: The pre-push scan MUST give the same verdict for the same commits on the development Mac and in
  CI. It accepts an identifier of the simulator form only when the SHA-256 hash of the identifier is in one tracked
  list; no readable identifier is tracked. An identifier of a simulator of the development Mac whose hash is not in
  the list MUST be a finding that names the command that records it.
- **FR-U00-026**: A scan command MUST record the hashes of the development Mac's current simulator identifiers in
  the tracked list, keep the hashes already recorded, and write the list sorted so that recording twice changes
  nothing. Where the simulator list cannot be read, it MUST change nothing and say so.

**Migration ledger**

- **FR-U00-030**: The ledger tool MUST refuse a check, a seal and a record for a gate with an unmet dependency and
  name what is unmet.
- **FR-U00-031**: The ledger tool MUST refuse a second attestation under a name already used for the gate, and a
  seal MUST use only attestations that no earlier evidence revision of the gate used.
- **FR-U00-032**: The ledger tool MUST refuse to seal when a log of a passing check is missing or differs from the
  hash in its attestation.
- **FR-U00-033**: The ledger tool MUST refuse a check, a seal and a record of every device row and device campaign,
  and the device guard MUST fail, until `ImplementationLock-100` is pass.
- **FR-U00-034**: The ledger tool MUST refuse the Claude CLI, a shell wrapper and an inline script as an evidence
  command before running it.
- **FR-U00-035**: The ledger tool MUST refuse the integration gate of an original app until its seven legacy phase
  gates are pass in the legacy ledger, without writing the legacy ledger.
- **FR-U00-036**: The ledger tool MUST stop with a message that names the file, and write nothing, when the ledger
  is missing, damaged or of an unknown schema, or when an attestation or evidence file it needs is damaged.
- **FR-U00-037**: The ledger validation MUST report a gate that is pass or fail without recorded evidence, an
  evidence file that is missing or changed after it was recorded, and a device gate recorded before the lock.
- **FR-U00-038**: Each refusal of FR-U00-030 to FR-U00-037 MUST be proven by a self-test that works on a temporary
  copy; the self-tests MUST NOT change the real ledger, its checks or its evidence.
- **FR-U00-039**: The migration ledger tool MUST remain the only writer of the migration ledger: a self-test MUST
  fail when another tracked script or workflow names the ledger file outside a reviewed list of readers.

**Prompt coverage**

- **FR-U00-040**: A self-test MUST prove, for every pending feature of the launch scope, that a non-empty prompt
  exists for each of the eight stages specify, clarify, plan, checklist, tasks, analyze, implement and converge:
  the pending phases of the original apps through the phase prompt tool, and the pending unified-app features,
  shared round features and game features of Rounds 2 to 4 through the planning index.
- **FR-U00-041**: The coverage test MUST take the list of pending features from the two ledgers, not from a list
  written into the test, MUST skip superseded features, and MUST name the feature and the stage of every missing or
  empty prompt.
- **FR-U00-042**: Every prompt of a migration-ledger feature printed with the override MUST end with a labelled
  `Canonical override` note that names the feature directory and the three id forms of its namespace. For an
  archived round feature the prompt tool adds them as one generated sentence, with the directory of the ledger and
  the namespace the validator derives from it; the archived prompt text and the canonical override paragraphs MUST
  stay unchanged.

**Continuous integration**

- **FR-U00-050**: CI MUST run, on every push to `main` and on every pull request, the steering validator, the
  archive verifier, the index verifier and the migration ledger validation, and a failure of any MUST fail the run.
- **FR-U00-051**: CI MUST run the pre-push scan over exactly the commits of the push (from the commit before the
  push to the pushed commit) or of the pull request (from the merge base to its head), with the full history
  fetched. The scan job MUST NOT be cancelled by a newer push. A finding, a forbidden tracked path, an unknown
  earlier commit or an unreadable range MUST fail the run.
- **FR-U00-052**: The CI steps MUST need no signing, no secret and no network access beyond fetching the
  repository.
- **FR-U00-053**: The workflow change MUST be confirmed by a real run on the pushed commit that ends in success;
  its identifier and conclusion MUST be recorded as evidence of the gate.

**Boundaries**

- **FR-U00-060**: This feature MUST NOT change any app or framework source, the reference submodule, the vendored
  ANGLE tree, the legacy ledger or the legacy ledger tool.
- **FR-U00-061**: Every tool of this feature MUST use only the Python standard library and MUST NOT start the
  Claude CLI, call a model or use the network; pushing through Git is the single exception.

### Absorbed source requirements

R02-F01 ("Round 1 evidence & reproducible baseline audit") is superseded as a gate and its purpose is delivered here
and by the consolidation. Its archived specify prompt names six things to verify:

| Source requirement | Disposition | Reason |
|---|---|---|
| Verify the repository status | adopted | The checkpoint commands, `scripts/migration_baseline.py verify` and the validators of this feature do it at every session start; FR-U00-050 repeats them in CI. |
| Prior 25 app builds | superseded | Twenty-five app builds never existed: three original apps are complete and one is partial. Their state is the 35 sealed legacy gates, which the baseline and FR-U00-035 protect. |
| Simulator results | adapted | The sealed simulator evidence of the legacy gates stays as recorded and is verified by hash; it certifies those phases only, never the unified app (ADR-0009 D-12). |
| D1–D3 campaign | superseded | No device test has ever been run in this repository. Devices come after `ImplementationLock-100` (ADR-0009 D-07, D-08); FR-U00-033 enforces it. |
| Tool versions | adopted | `scripts/verify_environment.py` against `Configs/toolchain.json`; already in place and unchanged here. |
| Git pins | adopted | The baseline records the pins and `scripts/check_reference_clean.py` proves the reference submodule; unchanged here. |
| Context: separate paid apps without in-app purchase; no device before the "Round 2 lock" | superseded | ADR-0009 D-03 and D-07: one app, one purchase, one lock for all 100 experiences. The no-advertising rule is kept. |
| Consumers: all | adopted | Every later feature uses these tools. |

### Key Entities

- **Numbering map**: the rule that gives every feature directory its id namespace (ADR-0009 D-11, Auto-Creator.md
  section 19.1). Seven directory forms.
- **Dossier**: the directory of one feature with its specification, plan, task list, contracts and checklists.
- **Task tick**: one task line marked done with the date and the evidence that was reproduced.
- **Attestation**: the record of one evidence command: the argument list, the exit code and the hash of its log.
- **Evidence revision**: the sealed set of attestations from which a gate is recorded; a gate keeps every revision.
- **Gate**: one entry of the migration ledger with its dependencies, status and attempts.
- **Scan pattern**: one kind of value that must not be pushed, with its allowed look-alikes.
- **Forbidden path class**: one kind of path that must never be tracked.
- **Stage prompt**: the supplied text for one Spec Kit stage of one feature, with its override note.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-U00-001**: All seven directory forms are accepted with the right namespace, and each of at least six
  different out-of-map directories is reported: 100% of the fixtures behave as specified.
- **SC-U00-002**: The 35 sealed dossiers validate with 0 problems, and a comparison with the commit before this
  feature shows 0 changed files under `specs/001` to `specs/035`.
- **SC-U00-003**: At least 10 namespace self-tests pass: one accepted and one rejected dossier for each of the 5
  new namespaces.
- **SC-U00-004**: The tick tool ticks a task in each of the 7 directory forms; each of at least 6 refusal cases
  leaves the task file byte-identical and adds 0 commits; out of the three push situations (other branch, finding,
  clean on `main`) exactly one pushes.
- **SC-U00-005**: Every scan pattern and every forbidden path class has at least 1 finding case and 1 clean case;
  the coverage self-test fails when one is missing. The tracked hash list holds 1 hash for each simulator of the
  development Mac at the time of recording and 0 readable identifiers, and recording a second time changes 0 bytes.
- **SC-U00-006**: Each of the 6 ledger refusals named in the acceptance list has at least 1 self-test, and the hash
  of the real ledger is identical before and after the self-tests.
- **SC-U00-007**: The prompt coverage test finds a non-empty prompt for 100% of the pending launch features in all 8
  stages (at the time of writing 953 features and 7,624 prompts) and reports both numbers; with one prompt removed
  in a temporary copy it fails naming that feature and stage.
- **SC-U00-008**: The CI run on the commit that changes the workflow contains the 4 added validator steps and the
  scan step and ends in success; the scan command of CI fails on a test range with 1 seeded finding.
- **SC-U00-009**: The complete self-test suite finishes in under 5 minutes on the development Mac.
- **SC-U00-010**: A comparison with the commit before this feature shows 0 changed files under the app, framework,
  showcase, harness, reference and vendored trees, and the legacy ledger and its tool are byte-identical.

## Assumptions

- The numbering map is the one of ADR-0009 D-11 and Auto-Creator.md section 19.1. The round directories of Rounds
  3 to 12 are the ones the archived prompts name.
- Part of this feature exists since the consolidation: the validator already knows the namespaces, and the scan and
  the ledger tool have self-tests. This specification states the complete required behavior; the plan's audit
  decides what is already met and what is missing, and nothing that already passes is rebuilt.
- "Pending feature of the launch scope" means: a phase of an original app that is not pass in the legacy ledger,
  and a unified-app feature, shared round feature or game feature of Rounds 2 to 4 that is pending in the migration
  ledger. Superseded shared features are never run and need no prompts.
- "The only way a commit is pushed" is a rule of procedure backed by detection: tracked files cannot stop a plain
  `git push`, so the tools are the documented ways, a self-test proves that nothing else in the repository pushes,
  and the CI scan detects a push that bypassed them (Clarifications).
- A SHA-256 hash of a simulator identifier reveals nothing about the identifier and cannot be used as one.
- CI runs on GitHub-hosted macOS runners as today, with a shallow checkout of the reference submodule only.
- Timing in SC-U00-009 is a host measurement on the development Mac. It is not a device or app performance claim.
- The owner's ruling of 2026-11-11 stands: work happens on `main` and is pushed after every commit.

## Traceability

| Source | Requirement |
|---|---|
| Acceptance 1 (numbering map accepted, ids unique in their namespace, 35 dossiers unchanged) | FR-U00-001–007, US1, SC-U00-001, SC-U00-002 |
| Acceptance 2 (positive and negative fixture per new namespace) | FR-U00-008, SC-U00-003 |
| Acceptance 3 (tick every namespace, refuse on validation failure, push only on `main` after the scan) | FR-U00-010–015, US2, SC-U00-004 |
| Acceptance 4 (eight prompts for every pending launch feature) | FR-U00-040–042, US5, SC-U00-007 |
| Acceptance 5 (ledger self-tests for the six refusals) | FR-U00-030–038, US4, SC-U00-006 |
| Acceptance 6 (CI runs the four validators) | FR-U00-050, FR-U00-052, FR-U00-053, US6, SC-U00-008 |
| Acceptance 7 (scan self-tests for every pattern and forbidden path; CI scans the pushed range) | FR-U00-020–026, FR-U00-051, US3, US6, SC-U00-005, SC-U00-008 |
| Scope: the ledger tool is the only writer of the migration ledger | FR-U00-039 |
| Scope: the tick tool and the scan are the only way a commit is pushed | FR-U00-015 |
| Out of scope: app and framework source, legacy ledger and its tool | FR-U00-060, SC-U00-010 |
| Boundaries: no Claude CLI, no model, no network | FR-U00-061, FR-U00-034 |
| Absorbed R02-F01 | table "Absorbed source requirements" |
| Auto-Creator.md section 19.4 (ticks and evidence), section 25 (ledgers, recovery) | FR-U00-010–014, FR-U00-030–038, Edge Cases |
| ADR-0009 D-11, D-12, D-13 | FR-U00-001, FR-U00-035, FR-U00-014 |
| ADR-0009 C-19 (a CI change is confirmed by a real run) | FR-U00-053 |
| Constitution VI (evidence over assertion), Development Workflow | FR-U00-006, FR-U00-013, FR-U00-038 |
