# Feature Specification: Generative Art Studio — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `017-gas-p06-release-readiness` (spec directory only; work stays on `main`)

**Created**: 2026-11-11

**Status**: Draft

**Ledger gate**: A01-P06 · ID namespace FR-A01-6##, SC-A01-6##, T-A01-6##

**Input**: User description: archived manual `apps/01-generative-art-studio.md` §9 Phase 06 `/speckit-specify` prompt
(verbatim in the invocation). Canonical overrides:
- The release tooling (a scan of the built app against its privacy manifest, and a per-app release-readiness check)
  is shared by all 25 apps (constitution Principle II).
- Device tests are prepared to run automatically and recorded as pending device campaign II. No physical device is
  used before the implementation lock (CLAUDE.md §8).
- Signing, archive upload and App Store Connect work are owner-only (`BLOCKED_OWNER_ACTION`, CLAUDE.md §5).
- Evidence is host and simulator only.

## Clarifications

### Session 2026-11-11

Answered autonomously under the owner's standing approval (CLAUDE.md §2); the recommended option was chosen in each case.

- Q: How is "required-reason API use" detected in the built app? → A: By scanning the undefined and imported symbols
  of the app binary and every embedded framework (`nm`) against a maintained table of Apple's required-reason API
  categories and their symbols: UserDefaults, file timestamps, system boot time, disk space, active keyboards and user
  defaults domains. A category used only inside an embedded framework without its own manifest (for example ANGLE) is
  declared in the app's manifest. The table lives with the shared check, so every app gets the same detection.
- Q: Which approved reasons are declared? → A: The reasons that describe the actual use, recorded with the code site
  for each in the privacy summary: UserDefaults CA92.1 (the app's own settings); file timestamps C617.1 (files in the
  app's own container); system boot time 35F9.1 (elapsed-time measurement for frame timing). A category the scan finds
  that has no fitting reason is a release blocker, never a guessed declaration.
- Q: What is the app icon? → A: A 1024×1024 opaque render of the Gradient Noise "Dusk" preset at a fixed time, made
  by the app's own exporter in a hosted test and committed with its provenance (composition, seed, time, commit). It is
  a single-size icon, with no text and no third-party art.
- Q: How is the automation runner hosted in the app? → A: Through a reusable VisualCoreAutomation SwiftUI view that
  hosts any RenderScene and runs the requested mode. It uses the existing `VISUALCORE_AUTORUN` environment trigger and
  the smoke, launch and lifecycle modes, and is compiled only under DEBUG or the automation condition. The app hosts its
  default composition, and the existing simulator runner script rehearses each mode.
- Q: What does crash recovery clean at launch? → A: The export folder in the app's temporary directory (left behind
  when the app is killed with the export sheet open) and leftover store temporary files, which the store already
  removes when it loads. Saved compositions are never touched. An interrupted save keeps the previous file (atomic
  replace, Phase 03).

## User Scenarios & Testing *(mandatory)*

Users: the owner, who will sign and submit the app; App Review; people who install the app; and the maintainers of
the other 24 apps, who reuse the release tooling.

### User Story 1 - Privacy and permissions are declared from what the app actually does (Priority: P1) 🎯

The built app carries a privacy manifest that declares exactly the sensitive system APIs it and its libraries use,
with an approved reason for each. It collects no data and does no tracking. The only permission text is the Photos
add-only text, and the privacy summary matches all of this.

**Why this priority**: App Store submission requires a privacy manifest that matches the built binary (CLAUDE.md §5),
and the manual requires disclosures based on actual behavior, not sample text.

**Independent Test**: Scan the built Release app. Every sensitive-API category found in it is declared with a
reason, and nothing undeclared or unused remains. Tracking is off, and no collected data types or tracking domains
are listed. The usage strings are exactly the expected set.

**Acceptance Scenarios**:

1. **Given** a Release build, **When** the scan runs, **Then** every required-reason category used by the app or its
   linked libraries is declared, and no declared category is unused.
2. **Given** the privacy summary, **When** it is compared with the manifest and the app's behavior, **Then** they
   agree: data stays on the device, no account, no network, and Photos add-only only when the user saves.

---

### User Story 2 - The app is complete and honest as a store candidate (Priority: P1)

The app has its icon, a version, the encryption declaration and credits. Its UI and store text claim only features
that work and are tested. A single release checklist lists every artifact and every evidence item, each with a
status: verified, pending device campaign, or owner action.

**Why this priority**: These are the manual's Phase 06 gates: a complete release checklist and artifact inventory,
and no unsupported promised features in the UI or marketing copy.

**Independent Test**: The release-readiness check passes for the app: icon present in the required size, version
set, encryption flag set, privacy manifest present, usage strings justified, credits and privacy summary present, and
store text present. Every store-text claim maps to a test.

**Acceptance Scenarios**:

1. **Given** the release checklist, **When** it is reviewed, **Then** every item has a status and evidence or the
   exact owner step, with no unexplained gap.
2. **Given** the store description, **When** each claim is traced, **Then** it maps to a passing test or is removed.

---

### User Story 3 - Saved work survives updates and crashes (Priority: P1)

Compositions saved by the earlier build open in this build unchanged. After a crash or a forced quit, the library is
intact on relaunch, no half-written file is left behind, and leftover export files are removed.

**Why this priority**: These are the manual's "local data migration" and "crash recovery" items.

**Independent Test**:
- A committed library fixture written in the current format opens with identical compositions and images.
- A simulated interrupted save leaves the previous version readable.
- Stray temporary and export files from a killed session are cleaned on the next launch.

**Acceptance Scenarios**:

1. **Given** a library saved by the previous build, **When** this build opens it, **Then** every composition is
   listed and renders the same image.
2. **Given** the app was killed during an export or a save, **When** it relaunches, **Then** the library loads without
   problems and no stale temporary or export files remain.

---

### User Story 4 - Device tests are ready to run, and the build is reproducible (Priority: P2)

The app has a debug-only automation runner (smoke, launch timing, lifecycle) that writes a JSON report and exits.
It is rehearsed on simulators, and its symbols are absent from the shipping build. Build and archive instructions
give exact commands. Signing and upload steps are listed as owner actions. No performance number is claimed without
a device measurement.

**Why this priority**: These are the manual's CPU/GPU/device-test and build/archive items. Device results belong to
campaign II.

**Independent Test**:
- The automation modes run on both simulator runtimes and produce valid reports.
- The shipping build contains zero automation symbols and trigger strings.
- The Release build succeeds unsigned for generic iOS.
- The documented commands match what was run.

**Acceptance Scenarios**:

1. **Given** the automation-enabled build, **When** each mode runs on a simulator, **Then** it writes a report with
   the device, OS, app version and results, and exits.
2. **Given** the shipping Release build, **When** it is inspected, **Then** no automation code or trigger is present.

### Edge Cases

- A sensitive API is used only by a library (VisualCore, ANGLE), not by app code: it is still declared.
- The device's system language or text size differs: release text and the icon contain no text that needs
  localization.
- A fixture from a newer schema version: refused without modifying the file. This already holds since Phase 03 and is
  re-run here.
- Automation is requested in a Release build: nothing happens.
- Owner-only steps (signing team, archive upload, App Store Connect record, privacy policy URL hosting) are listed with
  exact instructions and are never performed or simulated.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A01-601**: The app MUST ship a privacy manifest that declares no tracking, no tracking domains, no collected
  data types, and every required-reason API category actually present in the built app with an approved reason.
- **FR-A01-602**: A shared check MUST scan a built app (its binary and embedded frameworks) for required-reason API
  use and compare it with the app's privacy manifest. It reports undeclared and unused categories, and it is usable
  by every app.
- **FR-A01-603**: The app MUST declare only the usage strings it needs (Photos add-only). Each declared permission
  MUST be justified in the privacy summary with the exact UI path that triggers it.
- **FR-A01-604**: The app MUST have a 1024×1024 opaque app icon rendered by the app's own exporter (no third-party art;
  provenance recorded), together with version metadata (1.0.0, build 1) and the export-compliance (encryption)
  declaration.
- **FR-A01-605**: A privacy-and-credits document MUST list stored data, permissions, third-party components with
  licenses, and asset provenance. It MUST agree with the app's About text and the legal notices.
- **FR-A01-606**: A release checklist and artifact inventory MUST list every release item with a status: verified
  (with evidence), pending device campaign, or owner action (with exact steps). Store text MUST claim only
  implemented, tested features.
- **FR-A01-607**: Compositions saved in the current format MUST open unchanged in this build (a committed fixture).
  Interrupted saves MUST leave the previous file readable. Leftover temporary and export files MUST be removed at
  launch.
- **FR-A01-608**: A debug-only automation runner, hosted through a reusable VisualCoreAutomation view, MUST provide
  smoke, launch and lifecycle modes that write JSON reports and exit. It is rehearsed on simulators, and its symbols MUST be absent from the shipping build.
- **FR-A01-609**: Build and archive instructions MUST give exact commands for the unsigned Release build and checks.
  Signing, archive upload and store submission are owner-only steps.
- **FR-A01-610**: A shared release-readiness check MUST verify an app's release artifacts (icon, version, encryption
  flag, privacy manifest, usage strings, required documents) and pass for this app.
- **FR-A01-611**: No performance, device-compatibility or capability claim may appear without device evidence. The
  full app suites, the contract check and the release-check steps MUST pass on both runtimes.

### Key Entities

- **Privacy manifest**: tracking flag, tracking domains, collected data types, and accessed API categories with
  reasons.
- **Release checklist item**: area, item, status (verified / pending campaign II / owner action) and evidence or steps.
- **Automation report**: mode, app version and build, device model, OS, timestamps, results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A01-601**: The privacy scan of the Release build reports 0 undeclared and 0 unused required-reason categories,
  with tracking off and 0 collected data types.
- **SC-A01-602**: The release-readiness check passes all its items for the app, and the shared checks have their own
  tests, including failing fixtures.
- **SC-A01-603**: A library fixture with 4 compositions (one per family) opens with 4 entries and identical renders.
  After an interrupted save and a simulated kill, the library has 0 problems and 0 stale files.
- **SC-A01-604**: The automation smoke, launch and lifecycle modes each produce a valid report on both runtimes. The
  shipping build has 0 automation symbols and 0 trigger strings.
- **SC-A01-605**: Every store-text claim maps to a passing test. The checklist has 0 items without a status.
- **SC-A01-606**: The full app suites (enumeration-guarded), the contract check, the release-check fast steps and the
  Release build all pass on both runtimes.

## Assumptions

- The privacy policy page needs an owner-hosted URL. The policy text is prepared, and hosting is an owner action.
- Store screenshots are taken from simulators at store sizes when the owner prepares the submission. Their capture is
  listed in the checklist and is not part of this gate's evidence.
- Device results (frame pacing, launch time, GPU behavior, memory) are campaign II work on D1, D2 and D3. Here the
  automation is prepared and rehearsed only.
- The version is 1.0.0 (build 1) for the first release candidate. The bundle ID stays the owner-approved placeholder
  `dev.visualcore.GenerativeArtStudio` until the owner chooses store branding.
