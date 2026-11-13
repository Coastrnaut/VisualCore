# Feature Specification: Particle Universe — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `038-pu-p06-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-13

**Status**: Draft

**Ledger gate**: A04-P06 (legacy ledger) · ID namespace FR-A04-6##, SC-A04-6##, T-A04-6##

**Input**: User description: archived manual `apps/04-particle-universe.md` §9 Phase 06 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009):** Particle Universe ships as an experience of the VisualCore app, not as a standalone app.
  Its release documents go in `docs/apps/particle-universe/`; app-wide facts go in the shared documents of
  `docs/release/`. The standalone ParticleUniverse target is retired at X-A04, not here.
- **Phase gates (manual §9 Phase 06):** the release checklist and artifact inventory are complete; every required
  automated test has an attached result; device tests are recorded as pending the device campaign; nothing promised
  but unsupported remains in the interface or the copy.
- **Devices and audits:** device measurements wait for ImplementationLock-100 ({device} tasks); system accessibility
  audits wait for the device campaign (owner ruling of 2026-11-13).
- **Owner-only:** signing, archive upload, App Store Connect and agreements (`BLOCKED_OWNER_ACTION` steps with exact
  instructions).
- **No VisualCore change** unless a task proves it necessary.
- **What exists today (read-only audit of 2026-11-13, `Build/agent-notes/A04-P06-audit.md`):**
  - Particle Universe asks for no permission and uses no network, tracking or sensor. The app's privacy manifest
    declares no tracking and the required reasons for user defaults, boot time and file timestamps.
  - Every control has a label, hint and identifier; Reduce Motion starts paused; Reduce Flashing caps brightness; the
    canvas has a spoken summary. The system audit tests exist and wait for devices.
  - No non-code assets and no third-party code; the distinctiveness matrix marks the experience distinct.
  - Saved scenes are versioned (version 1 is migrated, newer is refused and kept); the library file wrapper has no
    version of its own.
  - The session shows a failure view with retry and back; memory warnings and context recreation are tested; no test
    proves a Particle Universe drawing failure reaches that view.
  - No build-and-archive instructions exist for the one app; Particle Universe has no release checklist, privacy and
    credits note, store text input or device campaign plan; the known limitations do not mention it.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nothing about the person leaves the device (Priority: P1) 🎯

A person uses Particle Universe without being asked for any permission, and nothing they make is sent anywhere.

**Why this priority**: Constitution (privacy) and the App Store privacy answers.

**Independent Test**: Inspect the experience's declared permissions, the app's usage strings and privacy manifest,
and the tracking and network scans.

**Acceptance Scenarios**:

1. **Given** the release build, **When** its declarations are checked, **Then** Particle Universe contributes no usage
   string and no tracking domain, and the privacy manifest covers every required-reason use it makes.
2. **Given** the experience's sources, **When** they are scanned, **Then** no network, tracking, advertising or sensor
   use is found.
3. **Given** the privacy and credits note, **When** it is read, **Then** it lists what the experience stores (saved
   scenes in its own folder) and states that nothing is collected.

---

### User Story 2 - A broken scene file or a failed draw never loses work (Priority: P1)

A saved scene from an older version still opens; a damaged or newer file is kept and named, not deleted; and a
drawing failure shows the failure view with retry instead of a crash.

**Why this priority**: the manual's "local data migration" and "crash recovery".

**Independent Test**: Load committed fixtures of every library file form; force a drawing failure in a hosted
session.

**Acceptance Scenarios**:

1. **Given** a library file written before this phase, **When** the library loads, **Then** the scene opens unchanged.
2. **Given** a library file of a newer format, **When** the library loads, **Then** it is counted as newer, kept and
   not opened.
3. **Given** a hosted session whose drawing fails, **When** the failure happens, **Then** the session shows its
   failure state, the saved scenes are untouched, and retry reopens a running session.
4. **Given** Reduce Motion or Reduce Flashing, **When** the hosted experience opens, **Then** it starts paused or caps
   brightness respectively.

---

### User Story 3 - The owner can build, check and archive the app (Priority: P2)

The owner has exact instructions to build the one app, run every release check, and archive and upload it, with the
owner-only steps marked.

**Why this priority**: the phase's "build/archive instructions"; submission stays with the owner.

**Independent Test**: Follow the agent-run steps of the instructions; check that every owner step is marked.

**Acceptance Scenarios**:

1. **Given** the build-and-archive instructions, **When** the agent-run commands are executed, **Then** they succeed
   unsigned on the project Mac.
2. **Given** the same instructions, **When** they are read, **Then** signing, archive upload and App Store Connect are
   marked as owner steps with exact actions.

---

### User Story 4 - The release record is complete and claims nothing unmeasured (Priority: P2)

The owner sees a release checklist and artifact inventory for Particle Universe, a store text input that describes
only tested features, the known limitations, and a device campaign plan for what is still pending.

**Why this priority**: the phase gate and "no fabricated measured performance claims".

**Independent Test**: Run the release document check and the copy check; read the checklist.

**Acceptance Scenarios**:

1. **Given** the release documents, **When** they are checked, **Then** each required document exists and every
   checklist item names its evidence or "pending device campaign".
2. **Given** the store text input and the in-app copy, **When** the copy check runs, **Then** no measured number, frame
   rate, device or battery claim and no unimplemented feature appears.
3. **Given** the known limitations, **When** they are read, **Then** Particle Universe's device-only items are listed.

### Edge Cases

- **Library file without a format field** (all files written so far): treated as format 1.
- **Library file of a newer format**: counted as newer, kept, never opened or rewritten.
- **Drawing failure during the first frame**: the failure view appears; no partial save happens.
- **Failure while the library is open for renaming**: nothing is written; the library reloads on the next open.
- **Reduce Motion turned on while playing**: unchanged behaviour of earlier phases (out of scope here).
- **Release build without the debug-only scenario switches**: no automation symbols ship.
- **Copy mentioning "smooth" or "fast"**: refused by the copy check unless backed by a recorded measurement.

## Requirements *(mandatory)*

### Functional Requirements

**Privacy (story 1)**
- **FR-A04-601**: Particle Universe MUST declare no permission and contribute no usage string; the release build's
  usage strings MUST stay exactly those declared by other experiences.
- **FR-A04-602**: The experience's sources MUST contain no network, tracking, advertising or sensor use (scan).
- **FR-A04-603**: The app's privacy manifest MUST cover every required-reason use the experience makes.
- **FR-A04-604**: A privacy and credits note MUST state what the experience stores, where, and that nothing is
  collected or shared, and that it has no third-party code or non-code assets.

**Migration and recovery (story 2)**
- **FR-A04-610**: Library files MUST carry a format number; a file without one MUST be read as format 1; a newer
  format MUST be counted as newer, kept and never opened.
- **FR-A04-611**: Committed fixtures of each library file form (without format, format 1, newer format, damaged) MUST
  be loaded by tests.
- **FR-A04-612**: A drawing failure in a hosted session MUST put the session in its failure state without changing any
  saved scene, and retry MUST reopen a running session.
- **FR-A04-613**: Hosted tests MUST prove Reduce Motion starts paused and Reduce Flashing caps brightness.

**Build and archive (story 3)**
- **FR-A04-620**: Build-and-archive instructions for the one app MUST list the exact unsigned build, test and release
  check commands and mark signing, archive upload and App Store Connect as owner steps.

**Release record (story 4)**
- **FR-A04-630**: Particle Universe MUST have a release checklist with an artifact inventory, each item naming its
  evidence or "pending device campaign".
- **FR-A04-631**: A store text input MUST describe only implemented, tested features; a copy check MUST refuse
  measured claims and unimplemented features in it and in the experience's interface text.
- **FR-A04-632**: The known limitations MUST list Particle Universe's device-only items; a device campaign plan MUST
  name each pending device measurement (pacing, detail steps under load, thermal behaviour, memory, accessibility
  audits).
- **FR-A04-633**: A release document check MUST fail when a required document or checklist evidence is missing.

**Common**
- **FR-A04-640**: Every Particle Universe test suite MUST pass on both simulator runtimes; the release build MUST pass
  the privacy, tracking, license and usage checks.
- **FR-A04-641**: No standalone-app change; no new permission; no network; no VisualCore change unless proven needed.

### Key Entities

- **Library file**: format number (absent means 1), identifier, saved time, scene document.
- **Release checklist**: items with evidence references or "pending device campaign".
- **Store text input**: the experience's description for the App Store record, owned by the owner at submission.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A04-601**: 0 usage strings, 0 tracking domains and 0 network uses added by the experience; the manifest check
  passes.
- **SC-A04-602**: 4 of 4 library fixtures load as specified; 100% of fields of the format-1 fixture are equal after
  loading.
- **SC-A04-603**: The forced drawing failure reaches the failure state in 1 of 1 run with saved scenes byte-identical,
  and retry returns to running.
- **SC-A04-604**: The release document check passes with every required document; removing one makes it fail.
- **SC-A04-605**: The copy check finds 0 measured or unimplemented claims.
- **SC-A04-606**: All Particle Universe suites pass on both runtimes; every new test finishes in under 10 seconds.

## Assumptions

- A04-P05 is pass; X-A04 (integration, retirement of the standalone target, metadata inputs entry) follows this phase.
- The store text is an input for the owner; the agent never enters it in App Store Connect.
- Device evidence is never produced here.

## Traceability

| Source | Requirement |
|---|---|
| Phase 06: privacy/permission strings | FR-A04-601–604, US1 |
| Phase 06: accessibility | FR-A04-613, FR-A04-632 (audits pending devices) |
| Phase 06: App Store asset/credit review | FR-A04-604, FR-A04-631 |
| Phase 06: local data migration | FR-A04-610, 611, US2 |
| Phase 06: crash recovery | FR-A04-612, US2 |
| Phase 06: CPU/GPU/device tests | FR-A04-640, FR-A04-632 ({device}) |
| Phase 06: build/archive instructions | FR-A04-620, US3 |
| "No fabricated measured performance claims" | FR-A04-631, SC-A04-605 |
