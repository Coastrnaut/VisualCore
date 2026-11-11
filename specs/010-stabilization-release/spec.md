# Feature Specification: Phase 9 — Stabilization, Documentation and Release

**Feature Branch**: `010-stabilization-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-10

**Status**: Draft

**Ledger gate**: F09 · ID namespace FR-F9##, SC-F9##, T-F9##

**Input**: User description: archived `sources/README.md` §10.11 Phase 9 prompt (verbatim in the invocation), plus the
canonical override: includes the AutomationRunner (`VisualCoreAutomation`, compiled only under `DEBUG ||
VISUALCORE_AUTOMATION`, zero symbols in the shipping Release build) needed for the device campaign; device support stays
"pending campaign II" until real D1–D3 evidence exists (constitution V, CLAUDE.md §9).

## Clarifications

### Session 2026-11-10

Answered autonomously under the owner's standing approval (CLAUDE.md §2), best option chosen.

- Q: Which version does this release get? → A: `1.0.0-rc.1` for every VisualCore module (the version constants and release notes). The final `1.0.0` waits for the device campaign evidence and owner approval; no device support is claimed in rc.1.
- Q: How is the public API reviewed and baselined? → A: `scripts/check_public_api.py` scans `Packages/*/Sources` for public declarations, requires a `///` documentation comment on each, and compares the normalized surface with the committed baseline `docs/api/visualcore-public-api.txt` (`--update` regenerates it deliberately); it runs in the release check and CI.
- Q: What does the AutomationRunner do and how is it triggered? → A: `VisualCoreAutomation.AutomationRunner`, compiled only under `DEBUG || VISUALCORE_AUTOMATION`, reads `VISUALCORE_AUTORUN=<mode>` (modes `smoke` — render N frames and report frame-time statistics; `launch` — time to first presented frame; `lifecycle` — suspend/resume and context-loss cycles with leak counts) plus `VISUALCORE_AUTORUN_FRAMES`, writes `Documents/visualcore-automation-<mode>-<UTC>.json`, then exits; unknown modes write an error report and exit non-zero. The Showcase integrates it. No URL scheme or remote input exists. A Release build of the Showcase is checked with `nm` for zero automation symbols.
- Q: What can CI run, given the ANGLE frameworks are a local 12 GB build output? → A: GitHub Actions on macOS runners runs documentation, compliance, dependency rules, script tests, the public-API check, and host `swift test` for the pure VisualCore package and GardenKit. Rendering, simulator and app builds need the locally built ANGLE/engine frameworks and run in the local release check; this is recorded as a known limitation, not hidden.
- Q: Where do performance baselines come from? → A: Host baselines from a release-configuration executable `VisualCoreBaselines` (particle stepping, effect-graph validation, shader expansion, coordinate mapping; median of repeated runs) written to `docs/performance/baselines-host.json`; simulator baselines from the AutomationRunner `smoke`/`launch` modes run in the Showcase on the iOS 27.2 and 26.5 simulators. Both are labelled "not device evidence".

## User Scenarios & Testing *(mandatory)*

Users: developers of the 25 apps adopting VisualCore, the owner deciding on a release, and the later device campaign.

### User Story 1 - Trustworthy, documented public API (Priority: P1) 🎯

A developer can rely on a reviewed public API: every public declaration is documented, the API surface is recorded,
and a change to it is detected.

**Acceptance Scenarios**:

1. **Given** the packages, **When** the public-API review runs, **Then** every public declaration has a documentation comment and the API surface matches the recorded baseline.
2. **Given** a public declaration added without documentation or a change to the surface, **When** the review runs, **Then** it fails and names the declaration.

---

### User Story 2 - Honest support matrix and limitations (Priority: P1)

The owner and adopters see exactly what has been verified: OS versions and simulators tested, devices pending the
campaign, and unsupported capabilities.

**Acceptance Scenarios**:

1. **Given** the support matrix, **When** read, **Then** each OS/runtime/device row states its evidence and status, and no device is marked supported without device evidence.
2. **Given** the limitations document, **When** read, **Then** it lists unsupported capabilities (e.g. system/app audio capture, home-screen live wallpaper, direct Metal rendering) and known limitations with reasons.

---

### User Story 3 - One-command release verification (Priority: P1)

A maintainer runs one release check that executes all regression tests, shader validation, resource-cleanup checks,
dependency and documented-API audits, license/notice checks and documentation checks, and gets a pass/fail summary.

**Acceptance Scenarios**:

1. **Given** a clean checkout, **When** the release check runs, **Then** every step runs and the summary lists each with its result; any failure fails the whole check.
2. **Given** every bundled and built-in shader, **When** shader validation runs, **Then** each compiles and links on the ANGLE path, or the failing file and line are reported.
3. **Given** every sample/harness scene, **When** the cleanup check runs, **Then** it reports zero leaked GPU resources after teardown and context loss.

---

### User Story 4 - Automation for the device campaign (Priority: P2)

The device campaign can drive builds without a person: an automation runner, available only in debug or measurement
builds, runs a named mode from an environment variable, writes a JSON report and exits; shipping builds contain none of it.

**Acceptance Scenarios**:

1. **Given** a debug build launched with an automation mode, **When** it runs, **Then** it writes a JSON report (mode, device model, OS, frames, timings) to the app's documents and exits.
2. **Given** a shipping Release build, **When** inspected, **Then** it contains zero automation symbols, and no URL or remote input can trigger automation.

---

### User Story 5 - Release package (Priority: P2)

The owner gets versioned packages, continuous integration, release notes and baselines ready for a release
candidate.

**Acceptance Scenarios**:

1. **Given** the repository, **When** CI runs on push, **Then** documentation, compliance, script tests, host tests and simulator builds run.
2. **Given** the release notes, **When** read, **Then** they state the version, what is included, the verification evidence, the support matrix and the limitations.
3. **Given** the performance baselines, **When** read, **Then** they record host and simulator measurements with their environment and are clearly marked as not device evidence.

### Edge Cases

- A public API change is intentional: the baseline is updated in the same change with a note.
- A shader that only fails on one runtime: reported per runtime.
- An automation mode name that is unknown: report an error JSON and exit non-zero; never hang.
- A dependency whose license is unknown: the license check fails.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-F901**: A public-API review (`scripts/check_public_api.py`) MUST verify a documentation comment on every public declaration in the VisualCore packages and compare the public surface with the committed baseline `docs/api/visualcore-public-api.txt`, failing with names on violations.
- **FR-F902**: A support matrix MUST list OS/runtime/simulator/device rows with evidence and status; devices D1–D3 MUST be "pending campaign II" until device evidence exists.
- **FR-F903**: A known-limitations document MUST list unsupported capabilities and known limitations with reasons.
- **FR-F904**: The package dependency audit (rules R1–R5, ProjectM independence of non-harness targets, documented-API use) MUST be part of the release check.
- **FR-F905**: Performance baselines MUST be recorded for host (`VisualCoreBaselines`, release configuration, median of repeats) and simulator (AutomationRunner `smoke`/`launch` in the Showcase on iOS 27.2 and 26.5) with their environment and explicitly marked non-device.
- **FR-F906**: A release check MUST run all regression suites (host, rendering, effects, Showcase, harnesses, reference regression) and report per-step results.
- **FR-F907**: Shader validation MUST compile and link every built-in and bundled shader on the ANGLE path on both simulator runtimes.
- **FR-F908**: A resource-cleanup check MUST confirm zero leaked GPU resources after teardown and context loss for every sample scene.
- **FR-F909**: License/notice compliance MUST list every third-party component with its license and obligations (including an LGPL analysis of the reference engine's linkage) and fail on unknown licenses.
- **FR-F910**: Documentation MUST include an index, getting-started guide, API overview per module and links to contracts, and a documentation check MUST pass.
- **FR-F911**: The sample apps (Showcase, Lumen Garden) MUST be referenced as the official samples and pass their smoke tests.
- **FR-F912**: CI MUST run documentation, compliance, dependency rules, script tests, the public-API check and host package tests on push; builds that need the locally built ANGLE/engine frameworks run in the local release check (documented limitation).
- **FR-F913**: Versioning MUST be `1.0.0-rc.1` consistently across modules, with release notes for that version.
- **FR-F914**: An AutomationRunner MUST exist only under `DEBUG || VISUALCORE_AUTOMATION`, run the mode named by `VISUALCORE_AUTORUN` (`smoke`, `launch`, `lifecycle`), write `Documents/visualcore-automation-<mode>-<UTC>.json` and exit (error report and non-zero exit for unknown modes); the shipping Release build MUST contain zero automation symbols and no URL/remote trigger.

### Key Entities

- **API baseline**: module, public declarations (kind, name, signature).
- **Support matrix row**: platform, OS/build, simulator or device, evidence, status.
- **Release check report**: steps, command, result, log.
- **Automation report**: mode, app, device model, OS, frames, timings, result.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-F901**: 100% of public declarations are documented and the surface matches the baseline.
- **SC-F902**: The release check passes end to end with every step green on the build machine.
- **SC-F903**: 100% of shaders validate on iOS 27.2 and 26.5 simulators.
- **SC-F904**: 0 leaked GPU resources across all sample scenes.
- **SC-F905**: 0 automation symbols in the shipping Release build; automation runs and exits in debug.
- **SC-F906**: No support claim exists without matching evidence (matrix review).

## Assumptions

- Device rows stay pending until the device campaign (after the implementation lock); simulator results are functional only.
- The release is a release candidate; a final stable version follows the device campaign and owner approval.
- CI uses public GitHub-hosted macOS runners for the public repository; signing is never used in CI; ANGLE-dependent builds are local-only (documented limitation).
