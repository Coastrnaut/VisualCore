# Feature Specification: UA-F10 — Build, project and CI consolidation

**Feature Branch**: `196-ua-f10-build-ci` (spec directory only; work stays on `main`)

**Created**: 2026-11-13

**Status**: Draft

**Ledger gate**: UA-F10 (migration ledger) · ID namespace FR-U10-###, SC-U10-###, T-U10-###

**Input**: User description: the UA-F10 `/speckit-specify` prompt of Auto-Creator.md section 20
(`docs/catalog/unified-app-features.json`), verbatim in the invocation, with the owner's rulings of 2026-11-13.

Canonical overrides:
- **Feature directory and ids:** `specs/196-ua-f10-build-ci`; FR-U10-###, SC-U10-###, T-U10-###.
- **Names from the brief:** `project.yml`; the experience packages `Packages/ExperiencesCreative`,
  `ExperiencesRound02`, `ExperiencesRound03`, `ExperiencesRound04`; `.github/workflows/ci.yml`;
  `scripts/release_check.py`; `scripts/check_dependencies.py`; the catalog. Other modules are not named here.
- **Who the users are:** the owner, who needs every push to prove that the one app still builds and that its
  structure (one shippable app, independent experiences, a catalog that matches the code) still holds; and the
  engineer adding the next experience, who needs fast, chunked local checks that each end within ten minutes.
- **Owner rulings of 2026-11-13 that bind this feature:** tests are short; an app test pass builds once and may run
  interface test classes in parallel simulator clones; accessibility audits wait for the device campaign; a gate's
  interface evidence is one pass on the iOS 27.x phone; nobody waits on CI.
- **Out of scope:** signing, archives and distribution. **Device-only items:** none. **Owner-only items:** none.
- **What exists today (read-only audit of 2026-11-13):**
  - `project.yml` has three application targets: `VisualCore` (the one app), `Showcase` (the framework showcase,
    not shipped) and `ParticleUniverse` (kept until X-A04). The A01–A03 standalone targets were retired by UA-F07.
  - `Packages/ExperiencesCreative` holds A01–A04 (Core, Core tests, Experience, Experience tests per experience).
    `ExperiencesRound02`, `ExperiencesRound03` and `ExperiencesRound04` do not exist. Nothing compares the
    experience packages with the catalog.
  - `check_dependencies.py` enforces rules R1–R5 (ProjectM only in the reference harness, pure package purity, no
    cycles, packages never import apps, test support only in tests). It has no rule about experiences importing
    each other.
  - CI (`ci.yml`) runs host gates, host tests and a simulator build of the pure package. It cannot build the app:
    the app links the ANGLE frameworks, which are built locally inside the reference submodule and are never in
    Git. The repository is public.
  - UA-F07 found that the app's Release build was broken by debug-only code, and no check had caught it.
  - `release_check.py` has `visualcore-app-build` and whole-scheme app test steps that can exceed ten minutes.
    App tests run through `xcodebuild_app.py`, which already supports chunks, a time limit, single-method chunks,
    building once (`build-for-testing`, `test-without-building`) and refusing a busy simulator.
  - `docs/performance/budgets.md` names "clean build, incremental build and app size, recorded at every milestone"
    as a proposal with no tool behind it.

## Clarifications

### Session 2026-11-13

- Q: What does CI link the app against in place of the locally built ANGLE frameworks? → A: Link-only stand-in
  frameworks that a CI step generates from the C headers the rendering package already tracks: every exported
  function exists and aborts if called, and each carries a marker symbol. They are created only in the CI workspace,
  at the path the package expects, and never committed. Every local and Release build check fails if the marker is
  present. Rejected: building ANGLE in CI (a 12 GB tree, hours); publishing the built frameworks as a release or
  artifact (the repository is public, and that would publish binaries); a self-hosted runner on the owner's Mac (an
  owner action).
- Q: Where is it declared which application targets are non-shipping, and why? → A: In a tracked list,
  `Configs/app-targets.json`, giving each target's name, bundle identifier, `ships` and a reason. Each reason names
  the condition that ends it (for Particle Universe, the ledger gate X-A04). The project check compares
  `project.yml` with this list. Comments in `project.yml` cannot be checked.
- Q: Does CI run the app's tests, or only compile them? → A: It compiles the app and its test bundles
  (build-for-testing in Debug, a plain build in Release) and runs no simulator tests. Running them needs the real
  renderer, so app, interface and experience tests stay local in the release check, in chunks (Auto-Creator.md
  section 24.1).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every push proves the one app builds (Priority: P1)

The owner pushes a commit and, without waiting, later sees in CI whether the one app still compiles for the
simulator in both the Debug and the Release configuration, unsigned.

**Why this priority**: a broken build found days later costs far more than one found on the push that caused it;
UA-F07 showed that a Release-only break can go unnoticed.

**Independent Test**: push a commit that breaks only the Release configuration of the app; the CI run of that commit
fails in the app-build job and names the error, while a clean commit passes.

**Acceptance Scenarios**:

1. **Given** a push to `main`, **When** CI runs, **Then** a job compiles the one app for the simulator in Debug and in
   Release without signing and fails on any compile or link error.
2. **Given** a pull request, **When** CI runs, **Then** the same host gates and app build run.
3. **Given** a newer push while a run is in progress, **When** CI starts the newer run, **Then** the older run is
   cancelled and only the newest commit's result counts.

---

### User Story 2 - One shippable application, checked (Priority: P1)

The project keeps exactly one shippable application with one bundle identifier. Every other application target is
a declared non-shipping harness, and a check fails as soon as a second shippable target appears.

**Why this priority**: the App Store product is one app (constitution); a second shippable target would split it.

**Independent Test**: add a shippable application target to a copy of `project.yml`; the check fails and names it.

**Acceptance Scenarios**:

1. **Given** the current project, **When** the check runs, **Then** it reports one shippable app (`VisualCore`) and
   lists every other application target with its declared reason (showcase harness; Particle Universe until X-A04).
2. **Given** an application target without a declared reason or with the app's bundle identifier, **Then** the check
   fails naming the target.
3. **Given** X-A04 is recorded, **Then** the Particle Universe target's reason no longer holds and the check fails
   until the target is removed.

---

### User Story 3 - Experience packages match the catalog (Priority: P2)

Each experience package contains exactly the experiences the catalog assigns to it that are implemented, each with
its expected targets, and nothing else.

**Why this priority**: 100 experiences will be added one by one; a missing or stray target must fail at once.

**Independent Test**: remove one experience's test target from a copy of a package manifest, or add an unknown
target; the validation fails naming it.

**Acceptance Scenarios**:

1. **Given** the catalog and the experience packages, **When** the validation runs, **Then** every implemented
   experience has its targets in the package of its round and every target belongs to a catalog experience.
2. **Given** an experience package for a round with no implemented experience, **Then** the validation accepts its
   absence; the package is created with its first experience.
3. **Given** a corrupted or newer-schema catalog, **Then** the validation refuses with a message, never a crash.

---

### User Story 4 - Experiences stay independent (Priority: P2)

An experience depends only on the framework packages. Importing another experience, or any ProjectM module, fails
the dependency check.

**Independent Test**: add an import of one experience's module to another experience's source in a temporary copy;
the check fails with the rule, the file and the line.

**Acceptance Scenarios**:

1. **Given** the current sources, **When** the dependency check runs, **Then** it passes.
2. **Given** an experience source importing another experience's module, or a package manifest giving one
   experience a dependency on another, **Then** the check fails naming both.
3. **Given** an experience source importing a ProjectM module, **Then** the check fails.

---

### User Story 5 - Local checks of the one app in short chunks (Priority: P2)

The engineer runs the one app's unit tests, interface tests and experience verification through the release check
in named steps, each finishing within ten minutes.

**Independent Test**: list the release-check steps; every unified-app step has a stated budget below ten minutes,
and a step that runs longer stops itself and names where it was.

**Acceptance Scenarios**:

1. **Given** the release check, **When** its steps are listed, **Then** there are unified-app steps for the unit
   tests, the interface tests in chunks (built once, run without building), and verification subsets.
2. **Given** a step that exceeds its limit, **Then** it stops, fails and names the test or scenario it was on.
3. **Given** interface chunks, **Then** none of them runs a system accessibility audit before the device campaign.

---

### User Story 6 - Build time and size are recorded at milestones (Priority: P3)

At each milestone the clean-build time, the incremental-build time and the app size are measured and recorded with
the commit and the toolchain, so a change in module granularity can be judged against numbers.

**Independent Test**: run the measurement; a record with the three numbers, the commit and the Xcode build is added
to a tracked file, and a record for a commit already measured is not duplicated.

**Acceptance Scenarios**:

1. **Given** a milestone, **When** the measurement runs, **Then** it appends one record.
2. **Given** a damaged or newer-schema record file, **Then** the tool refuses with a message and changes nothing.
3. **Given** a proposal to split or merge modules, **Then** it needs an ADR quoting a before-and-after measurement.

### Edge Cases

- The locally built ANGLE frameworks are missing on a developer Mac: every app step fails at once and names the
  setup command; CI is unaffected (story 1 needs no locally built frameworks).
- A CI run is cancelled by a newer push, or a dependent job is skipped: only the newest finished run is evidence; a
  skipped job is investigated before code is blamed.
- A CI run stays queued because no hosted runner is free: it is not evidence and nobody waits for it; work goes on,
  and the gate is recorded only after a run of a commit containing all of the gate's changes has finished with
  success.
- An interface chunk is interrupted, or another run already uses the simulator: the run refuses or stops and says
  so; nothing is retried blindly.
- The simulator runtime named by the toolchain pins is not installed: the step fails naming the runtime.
- A catalog experience is marked implemented without code, or code exists for an experience the catalog does not
  know: the package validation fails naming the id.
- Memory pressure or a full disk during a build or measurement: the step fails; a measurement record is written
  only after a complete run.

## Requirements *(mandatory)*

### Functional Requirements

**CI (story 1)**
- **FR-U10-001**: CI MUST compile the one app for the iOS Simulator in the Debug configuration with its test bundles
  (build-for-testing) and in the Release configuration, on every push to `main` and every pull request, without
  signing and without a physical device. CI runs no simulator tests; those stay in the local release check.
- **FR-U10-002**: The CI app build MUST NOT need the locally built ANGLE frameworks, MUST NOT build ANGLE, and MUST
  NOT publish any binary. CI generates link-only stand-in frameworks from the tracked C headers. Each export
  aborts if called, and each carries a marker symbol. They exist only in the CI workspace and are never committed.
  The release check fails on a local or Release app that contains the marker.
- **FR-U10-003**: CI MUST keep running the existing host gates, host tests and the pure-package simulator build, and
  MUST add the experience-package and project-structure validations of stories 2 to 4.
- **FR-U10-004**: Every CI job MUST have a timeout and a concurrency group; nothing in CI is signed; a job MUST fetch
  only what it needs.

**Project (story 2)**
- **FR-U10-010**: `project.yml` MUST have exactly one shippable application target, `VisualCore`, with the one
  bundle identifier. Every application target MUST appear in `Configs/app-targets.json` with its bundle identifier,
  whether it ships, and, for a non-shipping target, the reason and the condition that ends it. No other target may
  use the app's bundle identifier.
- **FR-U10-011**: A check MUST fail on an undeclared application target, a second shippable target, a reused
  bundle identifier, or a declared reason that no longer holds (the Particle Universe target once X-A04 is pass).

**Experience packages (story 3)**
- **FR-U10-020**: Each experience package MUST be validated against the catalog: every implemented experience of
  the package's round has its Core, Core tests, Experience and Experience tests targets; every target belongs to a
  catalog experience of that round; a missing or extra target fails.
- **FR-U10-021**: The round-to-package mapping MUST be: A01–A25 → `ExperiencesCreative`, R02 → `ExperiencesRound02`,
  R03 → `ExperiencesRound03`, R04 → `ExperiencesRound04`. A package is created with the first implemented
  experience of its round.
- **FR-U10-022**: The app's registrations MUST be validated against the packages: every registered experience is
  linked, and every linked experience product is registered.

**Dependencies (story 4)**
- **FR-U10-030**: `check_dependencies.py` MUST fail when an experience source imports another experience's module,
  when an experience target depends on another experience's target, or when an experience imports a ProjectM
  module. Experiences MAY depend only on the framework packages `Packages/VisualCore` and
  `Packages/VisualCoreRendering`.

**Release check (story 5)**
- **FR-U10-040**: `release_check.py` MUST offer unified-app steps for the unit tests, the interface tests in chunks
  (one build, then chunks without building; parallel simulator clones allowed), and verification subsets with one
  step per registered experience and runtime, derived from `Catalog/registrations.json` so that a new registration
  gets its steps without an edit, each with a limit below ten minutes that stops the step and names where it was.
- **FR-U10-041**: The release check MUST also build the one app in Release for the simulator and check its
  symbols and privacy manifest.
- **FR-U10-042**: A unified-app step MUST NOT run a system accessibility audit before the device campaign (owner ruling
  of 2026-11-13); the audit tests stay in the sources and are run by the campaign.

**Budgets (story 6)**
- **FR-U10-050**: A tool MUST measure the clean-build time, the incremental-build time (after a one-line change to an
  experience source) and the size of the Release app for the simulator, and append a record with the commit, the
  Xcode build and the date to a tracked file. A damaged or newer-schema file is refused.
- **FR-U10-051**: A change of module granularity (splitting or merging packages or targets) MUST have an ADR quoting
  a measurement before and after.

**Sources absorbed**
- **FR-U10-060**: The requirements of R02-F30, R03-F10 and R04-F10 are carried as follows: package tests (adopted:
  release-check steps); exact tool pins (adopted: `Configs/toolchain.json`); isolated signing (adopted: CI unsigned,
  the local signing file never committed); merging without rebuilding vendor forks, corrupting signing or duplicating
  framework files (adopted: CI never builds ANGLE; the app embeds one copy of the ANGLE frameworks); 25 app schemes,
  simulator test plans and 25-target CI (superseded by the one app and its chunks, ADR-0009).

**Boundaries**
- **FR-U10-070**: One app target and one bundle identifier; experiences never depend on each other; the OpenGL ES to
  ANGLE to Metal path is the only renderer and is not forked; `External/projectm-ios` stays read-only; no network,
  advertising, analytics or tracking code; every new public symbol is documented and in the API baseline.

### Key Entities

- **Application target**: a target that builds an app, with its bundle identifier and whether it ships.
- **Experience package**: a package holding the experiences of one round, each with four targets.
- **Build measurement**: clean-build seconds, incremental-build seconds, app bytes, commit, Xcode build, date.
- **Release-check step**: a named command with a time limit.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-U10-001**: The CI run of a commit that breaks only the Release build fails, and the run of a clean commit
  passes, in 2 of 2 trials; the app-build job ends within 30 minutes.
- **SC-U10-002**: The project check reports 1 shippable app; 3 of 3 planted defects (undeclared target, second
  shippable target, reused bundle identifier) fail it.
- **SC-U10-003**: The package validation passes on the current tree with 4 of 4 experiences; 3 of 3 planted defects
  (missing target, extra target, unknown id) fail it.
- **SC-U10-004**: 3 of 3 planted dependency defects (cross-experience import, cross-experience target dependency,
  ProjectM import) fail the dependency check; the current tree passes.
- **SC-U10-005**: Every unified-app release-check step has a limit below 600 seconds; a full local pass of the one
  app's unit tests and interface chunks on the iOS 27.x phone finishes in under 45 minutes of machine time.
- **SC-U10-006**: One build measurement is recorded for the current milestone; a damaged record file is refused.
- **SC-U10-007**: 0 shipped or locally built app contains anything CI uses in place of the ANGLE frameworks.

## Assumptions

- GitHub-hosted macOS runners with the Xcode the toolchain pins (or the nearest available) build the app; the run
  time of CI is not a gating number beyond the job timeout.
- The catalog says which experiences are implemented (registered); this feature does not change the catalog.
- The Particle Universe target remains until X-A04 (UA-F07, FR-U07-043).
