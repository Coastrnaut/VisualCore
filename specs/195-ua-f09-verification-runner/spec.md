# Feature Specification: UA-F09 — Experience verification runner and evidence schema

**Feature Branch**: `195-ua-f09-verification-runner` (spec directory only; work stays on `main`)

**Created**: 2026-11-12

**Status**: Draft

**Ledger gate**: UA-F09 (migration ledger) · ID namespace FR-U09-###, SC-U09-###, T-U09-###

**Input**: User description: the UA-F09 `/speckit-specify` prompt of Auto-Creator.md section 20
(`docs/catalog/unified-app-features.json`), verbatim in the invocation.

Canonical overrides:
- **Feature directory and ids:** `specs/195-ua-f09-verification-runner`; requirement ids FR-U09-###, success
  criteria SC-U09-###, task ids T-U09-###.
- **Names from the brief:** the compilation conditions DEBUG and VISUALCORE_AUTOMATION; the new host driver
  `scripts/verify_experiences.py`; the evidence schema of Auto-Creator.md section 22.3; `AutomationRunner` and
  `AutomationReport` (module VisualCoreAutomation, which exists); `scripts/run_automation_sim.py` and
  `scripts/check_test_enumeration.py` (which exist); `xcrun xcresulttool`. Other modules are not named here.
- **Who the users are:** the lead engineer and the owner, who need one command that proves an experience works
  on both simulator runtimes and writes evidence that a gate can trust; later the device campaign (UA-F13), which
  reuses the same scenarios and record format on real devices.
- **Out of scope:** physical devices (UA-F13); the lock run (`--lock`, UA-F12).
- **Device-only items:** none. **Owner-only items:** none.
- **What exists today (read-only audit of 2026-11-12):**
  - A scripted run of an experience exists only for builds made for testing. It replays seeded actions through
    the real engine and reports the final digest. It records no expectation and no per-step digest.
  - The conformance helper checks determinism, snapshot round trip, reset, rejection, quality and replay on the
    host.
  - The session can open, close, suspend, resume, retry, checkpoint and recreate a context, and it records stage
    timings, resource counts and pacing.
  - The contract has no notion of an outcome or completion: no experience can say "solved" or "saved".
  - The older automation runner of the standalone apps runs `smoke`, `launch` and `lifecycle` modes chosen by the
    environment variable `VISUALCORE_AUTORUN`. It writes a report of its own schema to the app's Documents
    folder and exits. The one app does not use it.
  - A simulator script runs one such mode and copies the report out; a guard compares declared and passed XCTest
    methods in a log. No script reads result bundles; the app test runner writes none.
  - The sample experience exists only for tests and has no catalog id. The app's debug experience exists only in
    debug builds, under fixture catalog ids. No catalog experience is registered.
  - The planning catalog gives games 100 levels and 80 acceptance scenarios, and Round 3 and 4 games also 50
    fault-injection cases. Creative experiences have a list of regression fixtures. No game is implemented.
  - The shipped sources contain no TODO, FIXME, XXX, "lorem" or "coming soon". The word "placeholder" occurs 16
    times as technical vocabulary (the renderer's placeholder surface). The shipped app and packages contain
    no raster file.

## Clarifications

### Session 2026-11-12

Answered by the lead under the owner's standing delegation; the recommended option was taken each time.

- Q: In what form does an experience report that its outcome was reached, so that the completion scenario can
  check it? → A: As an optional outcome that the core derives from its own state when asked (none by default),
  surfaced through the engine and the diagnostics. It is never stored, so it adds nothing to snapshots or
  digests. A manifest can only expect it, never set it.
- Q: Do the three further audits of Auto-Creator.md section 22.2 belong to this feature? They cover direct GL
  calls outside the framework, a premium experience opening without entitlement, and network symbols. → A: The
  direct-GL and network-symbol audits run in `--audits` here, reusing the existing isolation and compliance
  checks. The entitlement audit belongs to UA-F08, which builds the entitlement; `--audits` names it as "not yet
  provided (UA-F08)" and does not report it as passed.
- Q: Where does the app write its evidence record, and what removes it? → A: In
  `Documents/visualcore-evidence/<run id>/<experience>.<scenario>.json` of its own container, written atomically.
  The driver copies it out and then removes it. The container inventory of builds made for testing lists that
  folder with the runner as its writer.
- Q: How does the marker audit tell a real placeholder from the word used as a technical term in code? → A: TODO,
  FIXME and XXX are markers wherever they appear in comments or strings. "lorem ipsum", "coming soon" and
  "placeholder" are markers in text a person can see: the string catalog and string literals of views. A name or
  comment in code that uses "placeholder" as a technical term is not a marker. No list of exceptions is kept.
- Q: How are the sample experience (tests only) and the app's debug experience verified, since neither is a
  catalog experience? → A: `--only a99.contract-sample` runs the scenarios through the package tests on each
  runtime, whose result bundles the driver checks. The app path is proven with the debug experience under its
  first fixture id, which the runner registers by itself in builds made for testing, with no launch argument.
  Real experiences run in the app path.

## Absorbed source requirements

Every unique requirement of the archived features R02-F29, R02-F31, R03-F11 and R04-F11, with its disposition.

| # | Source | Requirement | Disposition | Reason |
|---|---|---|---|---|
| 1 | R02-F29 | Fixed seeds for visual regression | adopted | every scenario names its seed |
| 2 | R02-F29 | Reference camera angles | adapted | one seed and camera per game for its hero scenario; creative experiences use the scenario seed's view |
| 3 | R02-F29 | Platform tolerances | adopted | tolerances and domain checks, never exact pixels across devices |
| 4 | R02-F29 | Pixel goldens | adapted | goldens are supporting evidence only; non-blank and probe checks decide; a reference image is never overwritten |
| 5 | R02-F29 | Human checks of snapshots | superseded | human reviews do not gate (Auto-Creator.md 6.5) |
| 6 | R02-F29 | Shader regression | adapted | a successful compile is recorded but never proof; rendered frames with probes are |
| 7 | R02-F29 | Mesh goldens | adapted | covered by probes and CPU digests; no mesh image is proof |
| 8 | R02-F29, R02-F31 | Round 2 prerequisites (R2-F06, R2-F25, R2-F30) | superseded | the unified-app gates replace them |
| 9 | R02-F29 | Consumers: all games | adapted | all registered experiences of the one app, creative ones included |
| 10 | R02-F31, R03/R04-F11 | devicectl wrappers and device launch modes | superseded here | device part is UA-F13; this feature keeps the trigger, file and exit protocol usable on devices |
| 11 | R02-F31 | Launch modes | adapted | the named scenarios replace free-form modes; the older modes stay for the standalone apps |
| 12 | R02-F31, R03/R04-F11 | Result bundle archive | adopted | counted only after an independent `xcresulttool` check |
| 13 | R02-F31, R03/R04-F11 | Per-run JSON | adopted | one record per experience, scenario and environment |
| 14 | R02-F31 | Checksums | adopted | SHA-256 of frames, logs, bundles and the app binary |
| 15 | R02-F31 | Report schema | adapted | the evidence schema version 1 replaces the older report schema for the one app |
| 16 | R03/R04-F11 | Stress runs | adapted | an `endurance` scenario on simulators as a development signal; device stress is UA-F13 |
| 17 | R03/R04-F11 | Lock verification | superseded here | the lock run is UA-F12; it reuses this record format and validator |
| 18 | R03/R04-F11 | Numeric stability, integer ticks | adopted | fixed steps, digests and the rejection of non-finite input |
| 19 | R03/R04-F11 | Explicit GL ES capabilities | adapted | recorded as context in the environment, not judged |
| 20 | R03/R04-F11 | Independent host and simulator verification | adopted | host tests, package tests and app scenarios on both runtimes |
| 21 | R03/R04-F11 | Gameplay truth on the CPU, serialized apart from rendering | adopted | digests come from core state; the reducer-bypass audit enforces it |
| 22 | R03/R04-F11 | No ads, analytics, accounts, external art | adopted | boundaries of the one app; the purchase wording is superseded by ADR-0009 |
| 23 | R03/R04-F11 | Screenshots from the real renderer, not mock-ups | adopted | frames come from the real render host with their hash |
| 24 | R03/R04-F11 | Exit gates and traceability to the prior round | adapted | the exit gate is UA-F09; rounds of separate apps no longer exist |
| 25 | R03/R04-F11 | Duplicate rejection | adapted | the existing scripted run and automation runner are reused, not duplicated |
| 26 | all | Device work after the lock; owner controls signing and devices | adopted | rule 5 and rule 6 of the project |
| 27 | all | Price wording and per-round device lock | superseded | ADR-0009 (one purchase) and ImplementationLock-100 |
| 28 | all | Spec boilerplate (journeys, schema migration, error handling, observability, accessibility, originality) | adopted where it applies | schema versioning, typed failures, no runner UI, the raster audit |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - One command proves an experience on both runtimes (Priority: P1)

The lead runs one command for an experience. It runs the experience's host tests, builds the app once, runs every
scenario of the experience on the iOS 27 and iOS 26.5 simulators, collects the evidence, and ends with a clear
pass or fail. A failure names the experience, the scenario, the runtime and the failed expectation.

**Why this priority**: Every X gate of the 100 experiences depends on this command; nothing can be called
verified without it.

**Independent Test**: Run the command for the sample experience and the debug experience, then for a
deliberately failing variant, and check the exit status and the named failure.

**Acceptance Scenarios**:

1. **Given** a healthy experience, **When** the command runs for it on both runtimes, **Then** it exits 0 and one
   valid record exists per scenario and runtime.
2. **Given** an experience with a deliberately broken behaviour, **When** the command runs, **Then** it exits
   non-zero and names the scenario and the expectation that failed.
3. **Given** a run that stopped part way, **When** it is run again with `--only` or `--skip`, **Then** it runs only
   what was asked and keeps the records already made.
4. **Given** a command that does not finish, **When** its time limit passes, **Then** the driver stops it, records
   the scenario it was on and exits non-zero; it never waits without a limit.

---

### User Story 2 - Every experience carries its scenarios as domain actions (Priority: P1)

The author of an experience writes the nine standard scenarios as seeded lists of domain actions with
expectations. The runner plays them through the experience's real reducer, never around it.

**Why this priority**: The scenarios are the evidence of every experience; they must be complete and honest.

**Independent Test**: Validate a complete manifest, an incomplete one and one with an expectation that no
action produces; play the complete one through the real engine on the host.

**Acceptance Scenarios**:

1. **Given** a manifest without one of the nine scenarios, **When** it is validated, **Then** validation fails
   and names the missing scenario.
2. **Given** a scenario, **When** it is played, **Then** every action goes through the experience's real reducer
   and the digest after each step is compared with the expectation.
3. **Given** a completion scenario, **When** its actions are played, **Then** it passes only if the experience
   itself reports the outcome; a manifest cannot declare the outcome reached.

---

### User Story 3 - The app runs one scenario and exits, and nothing else can start it (Priority: P1)

In a build made for testing or for automation, the app started with the scenario request in its launch
environment runs that one scenario for the given experience id and seed, writes its evidence and exits. In the
shipping build the runner does not exist, and no link, file or input can start a scenario.

**Why this priority**: The simulator evidence and, later, the device campaign rely on this behaviour; the
shipping build must not contain it.

**Independent Test**: Start the debug build with and without the request, start it with a request for an
unknown id, and scan the shipping build for the runner's symbols.

**Acceptance Scenarios**:

1. **Given** a debug build and a request in the launch environment, **When** the app starts, **Then** it runs the
   scenario, writes one record and exits with 0 for pass and 1 for fail.
2. **Given** a request for an unknown experience or scenario, **When** the app starts, **Then** it writes a record
   with the error and exits with 2. It never shows the launcher and waits.
3. **Given** the shipping build, **When** its binary is scanned, **Then** no runner symbol or request key is found,
   and the app has no URL scheme.

---

### User Story 4 - Evidence records are complete, versioned and checked (Priority: P1)

Every record follows schema version 1 of Auto-Creator.md section 22.3. It names the simulator runtime build,
the device type, the Xcode build, the commit and the app binary hash. A validator with self-tests rejects any
record that is incomplete, of an unknown version, or that claims a pass without observed evidence.

**Why this priority**: A gate seals only evidence that a tool can check; a claim without observation must be
impossible.

**Independent Test**: Run the validator's self-tests: one valid record, one record per missing field, a pass
without frames or steps, a newer schema version, and a device record that carries a hardware identifier.

**Acceptance Scenarios**:

1. **Given** a record from a real run, **When** it is validated, **Then** it passes.
2. **Given** a record with result `pass` and no observed steps, digests or frames, **When** it is validated,
   **Then** it is rejected.
3. **Given** a record of schema version 2, **When** it is validated, **Then** it is rejected as newer.

---

### User Story 5 - Rendered frames prove that something real was drawn (Priority: P2)

For the scenarios that draw, the runner reads the rendered frame from the real renderer. It checks that the
frame is not blank and that its semantic probes match the experience's state. A golden image, when one exists,
is recorded as supporting evidence only.

**Why this priority**: Rendering must be proven from the real renderer, but pixel goldens differ between
devices and must never decide a gate.

**Independent Test**: Run launch-first-frame for the debug experience; then make the frame blank (a presenter that
draws nothing) and a probe that cannot match, and check that both fail.

**Acceptance Scenarios**:

1. **Given** a drawn frame, **When** the checks run, **Then** non-blank and every probe pass, and the frame's
   hash is in the record.
2. **Given** a black frame, **When** the checks run, **Then** the scenario fails with a non-blank failure.

---

### User Story 6 - Result bundles count only when checked independently (Priority: P2)

A test run's result bundle counts as evidence only after `xcrun xcresulttool`, run by the driver as a separate
command, reports the tests as passed. The record then carries the test counts, failures, destination and
attachments that the bundle holds.

**Why this priority**: The build's own printed summary has been wrong before; the bundle is the independent
witness.

**Independent Test**: Give the driver a passing bundle, a bundle with one failed test, and a missing bundle.

**Acceptance Scenarios**:

1. **Given** a bundle whose tests passed, **When** the driver checks it, **Then** the counts and destination are
   recorded and the step passes.
2. **Given** a bundle with a failed test, or no bundle, **When** the driver checks it, **Then** the step fails.

---

### User Story 7 - Audits keep placeholders, foreign art and fake gameplay out (Priority: P2)

The audits fail when shipped sources contain TODO or placeholder markers, when shipped files contain raster
art other than the generated app icon, when a scenario does not go through the real reducer, or when an
experience's content counts are below its source specification.

**Why this priority**: The rules of the project forbid placeholders, outside art and mock-only gameplay; the
audits make the rules executable.

**Independent Test**: Run the audits on the current sources (pass); on a copy with a TODO, a stray PNG, a
manifest whose completion is declared without actions, and a game manifest with 79 acceptance scenarios
(each fails).

**Acceptance Scenarios**:

1. **Given** today's shipped sources, **When** the audits run, **Then** they pass, and each technical use of the
   word "placeholder" is recognised as not a marker.
2. **Given** a game manifest with fewer acceptance scenarios, levels or fault cases than its source, **When**
   the audits run, **Then** they fail and name the shortfall.

---

### User Story 8 - Games run their extra scenarios (Priority: P3)

A game additionally carries the 80 acceptance scenarios of its chapter and a hero scenario with automatic
image checks (histogram, no black frame, no non-finite value, silhouette bounds). Games of Round 3 and later
also carry the 50 fault-injection cases.

**Why this priority**: No game exists yet; the requirement is enforced now by the manifest validator and the
audits, and exercised by every game when it is integrated.

**Independent Test**: Validate fixture game manifests: complete (pass), short by one acceptance scenario (fail),
a Round 3 game without fault cases (fail); run the hero image checks on a drawn frame and on bad frames.

**Acceptance Scenarios**:

1. **Given** a game manifest of Round 2 with 80 acceptance scenarios and a hero scenario, **When** it is
   validated, **Then** it passes; with 79 it fails.
2. **Given** a frame with a non-finite value or an empty silhouette, **When** the hero checks run, **Then** they
   fail.

### Edge Cases

- **Failure:** a scenario whose experience fails to prepare records the failure with its stage and exits 1. A
  crash of the app is detected by the driver (no record, process gone) and recorded as a failure of that
  scenario.
- **Cancellation:** the cancel-prepare scenario leaves during preparation; the record proves that nothing arrived
  after the experience was deactivated.
- **Lifecycle interruption:** suspend-resume proves that no steps run for the time away. Save-restore uses two
  launches: the first saves and exits, the second restores. A relaunch that finds no saved state fails.
- **Memory pressure:** teardown-reentry repeats open and close and fails when memory or GPU bytes grow beyond the
  rule of UA-F06.
- **Corrupted or newer-version data:** the validator rejects a damaged or newer record. A damaged manifest is
  refused at load with a typed error, and the runner exits 2.
- **A simulator that refuses to launch** ("Busy"): the driver retries the launch once after a wait and then
  records the failure; it never waits without a limit.
- **Two runs at once:** the driver refuses to start while another of its runs holds the lock of the same output
  folder.
- **A hardware identifier:** no tracked record contains a UDID, serial or similar identifier.

## Requirements *(mandatory)*

### Functional Requirements

**Scenario manifests (story 2)**
- **FR-U09-001**: Each experience MUST ship a scenario manifest with at least the nine scenarios
  `launch-first-frame`, `input-response`, `completion`, `rejection`, `save-restore`, `reset`, `suspend-resume`,
  `teardown-reentry` and `cancel-prepare`. Each scenario has a seed and a list of domain actions, each action
  placed at a step, plus its expectations.
- **FR-U09-002**: A manifest MUST be versioned, bounded in size and validated at load. A missing scenario, an
  unknown control, a duplicate name, or an expectation that no action can produce MUST fail validation with a
  typed reason.
- **FR-U09-003**: Expectations MUST cover, as the scenario needs: the result of each action (accepted, or
  rejected with a reason code), the digest after chosen steps, the initial and final digest, the probes of the
  rendered frame, and the outcome.
- **FR-U09-004**: An experience MUST be able to report an outcome (for example a level solved, or work saved),
  derived from its own state when asked and absent by default. The outcome is never stored, so it changes no
  snapshot or digest. The completion scenario passes only when the experience reports the expected outcome after
  the scripted actions; a manifest cannot set it.
- **FR-U09-005**: Creative experiences MUST add one scenario per regression fixture of their card. Games MUST
  add `full-playthrough`, `hero`, the acceptance scenarios of their chapter (80) and, from Round 3, the
  fault-injection cases (50). An optional `endurance` scenario runs for ten minutes.

**Running (stories 1 and 3)**
- **FR-U09-010**: Every scenario MUST run through the open session, the experience and its real reducer,
  exactly as a person's input would. No scenario may set state, outcome or digest directly.
- **FR-U09-011**: The app MUST start a scenario only when the launch environment names it, with an experience
  id, a scenario name and a seed. It writes one evidence file into its own container and exits: 0 for pass, 1
  for fail, 2 for an error such as an unknown id or a damaged manifest.
- **FR-U09-012**: The runner MUST exist only in builds with DEBUG or VISUALCORE_AUTOMATION. The shipping build
  MUST contain no runner symbol and no request key. No URL, file, argument or other outside input can start a
  scenario.
- **FR-U09-013**: In the app, the save-restore scenario MUST span two launches: the first saves the snapshot and
  exits, the second restores it and compares the digest. On the package-test path of the sample, the two
  sessions run in one test process. The record says so (`configuration.process` = `single`), and that run is not
  counted as proof of a relaunch.
- **FR-U09-014**: Suspend-resume MUST prove that no step runs for the time away and that the digest is unchanged
  while suspended. Teardown-reentry MUST prove zero live and zero leaked GPU objects after each leave over at
  least 5 cycles, and no growth by the resource growth rule of UA-F06 (`GrowthRule`). Cancel-prepare MUST prove
  that nothing arrives after the cancelled preparation.
- **FR-U09-015**: The scenarios MUST run against an experience before it is available to everyone, without
  changing the catalog's availability.

**Driver (stories 1 and 6)**
- **FR-U09-020**: `scripts/verify_experiences.py` MUST, per runtime: run the experience's host tests, build the
  app once, install it, run each scenario with a time limit, collect the record, the frame and the logs, check
  the result bundles, and complete the record's environment, source and artifact fields.
- **FR-U09-021**: The driver MUST accept `--only` and `--skip` (experience ids), `--scenario` (names, including
  `endurance`), `--runtime` (27, 26 or both), `--audits` and `--self-test`. It MUST be resumable: a run picks
  up what an earlier run left undone. It MUST exit non-zero on any failure.
- **FR-U09-022**: The driver MUST choose simulators by runtime and kind, never by an identifier from an old log.
  No tracked output contains a simulator identifier.
- **FR-U09-023**: A result bundle MUST count only after `xcrun xcresulttool`, run by the driver as its own
  command, reports the tests as passed. The record carries the test count, the failures, the destination and the
  attachments taken from the bundle.
- **FR-U09-024**: Every wait of the driver MUST have a time limit: 120 seconds per scenario unless the manifest
  names a longer one (`endurance`: its time plus 120 seconds), 300 seconds for a simulator to boot, and the 540
  seconds of the test runners for a test run. A scenario that ends without a record, or a process that does not
  exit, is a failure that names the scenario.
- **FR-U09-025**: The driver MUST have self-tests that use the sample experience, including a deliberately
  failing scenario whose failure the driver must report by name and with a non-zero exit.

**Evidence (story 4)**
- **FR-U09-030**: Every record MUST follow schema version 1 of Auto-Creator.md section 22.3. Its fields are
  `schema`, `experience`, `code`, `scenario`, `seed`, `result`, `run`, `environment`, `source`,
  `configuration`, `steps`, `digests`, `frames`, `timing`, `pacing`, `resources`, `thermal_state`,
  `low_power`, `battery`, `artifacts` and `failures`.
- **FR-U09-031**: Each record MUST name the simulator runtime and its build, the device type, the Xcode build, the
  commit with its dirty flag and tree hash, and the SHA-256 of the app binary.
- **FR-U09-032**: A validator MUST reject a record with a missing or mistyped field, an unknown or newer schema
  version, a pass without observed evidence (no steps, no digests, or no frame for a drawing scenario), a pass
  with failures, and a device record with a hardware identifier. It has self-tests.
- **FR-U09-033**: Tracked summaries MUST go under `docs/verification/`; raw logs, frames and result bundles stay in
  untracked folders and are referenced by hash.
- **FR-U09-034**: The app MUST write its record atomically to `Documents/visualcore-evidence/<run id>/` of its
  own container. The driver removes the record after copying it. The container inventory of builds made for
  testing lists that folder.

**Frames (story 5)**
- **FR-U09-040**: A drawing scenario MUST read its frame from the real renderer and check that it is not blank
  and that each probe the experience declares matches its state. Every experience MUST declare at least one
  probe. The record carries the frame's hash.
- **FR-U09-041**: A golden image MUST be supporting evidence only: never compared exactly across devices, never
  overwritten once accepted, and never what decides a pass.
- **FR-U09-042**: The hero checks MUST cover the histogram, no black frame, no non-finite value and the silhouette
  bounds.

**Audits (story 7)**
- **FR-U09-050**: An audit MUST fail on TODO, FIXME or XXX in comments or strings of shipped sources. It MUST also
  fail on "lorem ipsum", "coming soon" or "placeholder" in text a person can see: the string catalog and string
  literals of views. "placeholder" as a technical term in code is not a marker. No list of exceptions is kept.
- **FR-U09-051**: An audit MUST fail on any raster file in the shipped sources and resources other than an app
  icon produced by a generator in the repository.
- **FR-U09-052**: An audit MUST fail on a scenario that bypasses the real reducer: a step without an action of a
  declared control, or an outcome or digest expected without actions that produce it, or a run whose engine
  counted fewer handled actions than the scenario sent.
- **FR-U09-053**: An audit MUST fail on content counts below the source specification: the scenario counts of a
  manifest, and for a game its levels, acceptance scenarios and fault cases compared with the planning catalog.
- **FR-U09-054**: The audits MUST read the tracked files only, so that build products are never audited.
- **FR-U09-055**: `--audits` MUST also run the direct-GL check and the network-symbol check of section 22.2 with the
  existing tools. It MUST name the entitlement audit as not yet provided (UA-F08) and never report it as passed.

**Boundaries and carried obligations**
- **FR-U09-060**: The driver MUST run `--only a99.contract-sample --scenario endurance --runtime 27`, which is the
  obligation UA-F06 carries.
- **FR-U09-061**: The driver MUST accept several experience ids in one run, as UA-F07 needs for A01 to A03. The id
  `debug` names the app's debug experience; its records carry the fixture id it runs under and the code
  `debug`.
- **FR-U09-062**: The record format, the request keys and the exit protocol MUST stay usable unchanged on devices
  (UA-F13), with `environment.kind = device`.
- **FR-U09-063**: Every new public framework symbol MUST have `///` documentation and the API baseline MUST be
  updated. The ProjectM reference regression passes 7 of 7 in two chunks after any framework change.
- **FR-U09-064**: One app target and one bundle identifier stay; no network, advertising or tracking code
  enters; no physical device is touched. The runner shows no screen of its own beyond the session's views, and
  the shipping app's accessibility is unchanged.

### Key Entities

- **Scenario manifest**: an experience's scenarios: name, seed, entries (step and action), expectations, kind
  (creative or game) and version.
- **Scenario result**: what one run observed: each action's result and digest, the outcome, the frame checks,
  timings, resources and failures.
- **Evidence record**: schema version 1 of section 22.3; the app writes the observed part, the driver completes
  environment, source and artifacts.
- **Audit finding**: rule, file and line or manifest, and message.
- **Run state**: what a driver run has done per experience, scenario and runtime, so that a later run can resume.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-U09-001**: For the sample experience and the debug experience, 9 of 9 standard scenarios pass on 2 of 2
  simulator runtimes, with one valid record each.
- **SC-U09-002**: A deliberately broken variant fails in 100% of the scenarios that test the broken behaviour,
  and the driver exits non-zero, naming the scenario and the expectation.
- **SC-U09-003**: The validator accepts 100% of the records of real runs, and rejects each of at least 12 kinds of
  invalid record (each missing field group, a pass without evidence, a pass with failures, a newer version, a
  hardware identifier).
- **SC-U09-004**: The shipping build contains 0 runner symbols and 0 request keys; a build made with
  VISUALCORE_AUTOMATION contains them.
- **SC-U09-005**: A run interrupted after any scenario and resumed with `--only` or `--skip` runs nothing twice
  and finishes with the same set of records as an uninterrupted run.
- **SC-U09-006**: Today's shipped sources pass every audit. Each of 4 planted defects is found: a TODO, a stray
  raster file, a completion expected without actions, and a game manifest short by one acceptance scenario.
- **SC-U09-007**: A blank frame and a frame whose probe does not match each fail their scenario; goldens never
  change a result.
- **SC-U09-008**: A result bundle with one failed test makes its step fail even when the build's printed summary
  says it passed; the record holds the counts from the bundle.
- **SC-U09-009**: No driver wait exceeds its limit: a scenario that does not exit is stopped within its limit plus
  30 seconds and recorded as failed.
- **SC-U09-010**: Every record names the runtime build, device type, Xcode build, commit, tree hash and app binary
  hash; 0 tracked files contain a simulator or device identifier.

## Assumptions

- The sample experience exists only for tests and cannot be linked into the app (clarification 5).
- A Round 2 game counts 80 acceptance scenarios and 100 levels, and a Round 3 or 4 game also 50 fault cases, as
  the planning catalog says. A creative experience counts its regression fixtures. Fixture manifests prove the
  rules, because no game exists yet.
- Pacing, thermal state and battery on simulators are development signals, recorded and never claimed for
  devices.
