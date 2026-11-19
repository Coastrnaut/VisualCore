# Feature Specification: Graphics Benchmark Lab — Phase 05 Repeatability, thermal and methodology review

**Feature Branch**: `177-gbl-p05-repeatability-review` (spec directory only; work stays on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: A24-P05 (legacy ledger) · ID namespace FR-A24-5##, SC-A24-5##, T-A24-5##

**Input**: User description: archived manual `apps/24-graphics-benchmark-lab.md` §9 Phase 05 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 05):**
  - MVP: results export as versioned JSON or CSV (built in A24-P04); here every exported and listed result also says
    whether it is valid, qualified or invalid, and why;
  - regression fixture: a background or thermal interruption flags a run as invalid or qualified;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here:** G-DEVICE (repeatability across trials, thermal context, the device plan) and G-EXPLAIN (the
  in-app explanation of limits) of `docs/apps/graphics-benchmark-lab/visualcore-contract.json`.
- **Interface tests:** the experience's first interface tests run in their own chunk on the iOS 27.2 phone simulator,
  each under 60 seconds.
- **No VisualCore or ProjectM change; no device run** before ImplementationLock-100: the device plan lists checks that
  need real hardware, each pending. Simulator results are never device evidence. Follow `specs/170-vpl-p05-budget-usability`.

## Clarifications

### Session 2026-11-19

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- **Background:** `ExperienceSession` pauses the render host on a background or inactive scene phase and resumes it
  on active; the presenter is not told. `RenderHost` sets `FrameInfo.time` to `CACurrentMediaTime()` minus the host's
  first frame time, never paused, so the first frame after a return carries the whole gap. A24-P02/P03's recorder
  already ends a run as interrupted when an interval leaves 0…1,000 ms, so a background of a second or more interrupts
  the run; a shorter inactive moment shows as a dropped frame.
- **Interface tests:** the app's interface tests launch with `-vcResetData`, `-vcSkipWelcome`, `-vcCandidates` and
  `-openExperience <id>` (Visual Programming Lab's `VPLSupport`), and XCUITest can send the app to the background with
  `XCUIDevice.shared.press(.home)` and bring it back with `activate()`.

- Q: What makes a run valid, qualified or invalid? → A: `RunQualification` in the core, from the run alone:
  - **invalid** when the state is `stopped` (reason `stopped`) or `interrupted` (`interrupted`), or no frame was measured
    (`no-samples`);
  - otherwise **qualified** with every reason that applies: `thermal-changed` (start and end differ), `thermal-serious`
    or `thermal-critical` (either state), `low-power` (on at start or end), `dropped-frames` (the summary's flag),
    `too-few-for-p99`;
  - otherwise **valid**. A run without a report (a test fixture) is qualified with `no-report`.
  Sentences: "Interrupted (for example by leaving the app)", "Stopped before the end", "No frame was measured", "The
  thermal state changed during the run", "The device was hot (serious)", "The device was hot (critical)", "Low Power
  Mode was on", "Some frames were dropped", "Too few frames for p99", "No device report".
- Q: How is the qualification shown and exported? → A: Computed, not stored: the list shows "Valid", "Qualified" or
  "Invalid"; the opened result lists the sentences; the CSV gains the key rows `qualification` and
  `qualification_reasons` (codes joined by `;`) after `state` (CSV format version 2), and the JSON stays the run file
  (version 3) because the qualification is derived from it.
- Q: How are trials compared? → A: `Repeatability.summarise(_ runs: [BenchmarkRun])` in the core groups by case
  fingerprint; within the group of the run the person opened, a trial is comparable when its device model, OS version,
  app build and tier equal the opened run's and it is not invalid; otherwise it is listed with `different-case`,
  `different-device`, `different-os`, `different-build`, `different-tier` or `invalid`. The summary gives each
  comparable trial's interval p50 and p95 (by save order), the spread (largest minus smallest) for each when there are
  at least two, and the GPU p50 spread only when every comparable trial has a GPU distribution. Shown in a
  `repeatability` block of the opened result.
- Q: What does "About these numbers" say, and where is it? → A: `GBLExplanation` (the copy in the experience) opened
  by `explain` from an opened result and from the repeatability block; sections with spoken headings: "What is
  measured" (frame interval, presenter CPU time, GPU time where a timer exists), "Valid, qualified, invalid", "Why
  numbers differ" (thermal state, Low Power Mode, display refresh, background work, the case's version), "Simulator
  numbers" (say nothing about a device), "What the lab does not do" (rank devices, claim precision, send results).
  The interface tests (`GBLRunUITests` in chunk `f3`) run quads to Finished (18 s), save, open, explain, and a second
  test sends the app to the background mid-run for at least 2 seconds (longer than the 1,000 ms sample cap) and expects
  "Interrupted"; each under 60 s. The explanation's words are scanned with `scripts/check_copy_claims.py` and the shared
  denylist over `GBLExplanation.swift` (the full claims scan of the store text comes with A24-P06).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A run says whether it can be trusted (Priority: P1) 🎯

Every ended run carries a qualification: valid (completed with no caveat), qualified (completed, but the thermal
state changed or was serious or critical, or Low Power Mode was on, or frames were dropped, or there were too few
samples for p99), or invalid (stopped or interrupted, for example by going to the background or a context rebuild).
The list, the opened result and both exports show it with its reasons.

**Why this priority**: the phase's regression fixture.

**Independent Test**: qualify fixture runs of each kind; interrupt a real run by suspension.

**Acceptance Scenarios**:

1. **Given** a run interrupted by going to the background, **When** it is qualified, **Then** it is invalid with the
   reason "interrupted".
2. **Given** a completed run whose thermal state rose from nominal to serious, **When** qualified, **Then** it is
   qualified with "thermal state changed" and "thermal state serious".
3. **Given** a completed run with no caveat, **Then** it is valid.

---

### User Story 2 - Trials of the same case can be compared (Priority: P1)

The person saves several runs of the same case and sees a repeatability view: the number of comparable trials, each
trial's p50 and p95 of the frame interval, and the spread between them. Trials are comparable only when they share the
case fingerprint, device model, OS version, app build and quality tier and are not invalid; the rest are listed as
not comparable with the reason.

**Why this priority**: repeatability is the point of the lab (manual risk 1).

**Independent Test**: summarise fixture sets of trials; mix in a different case, device and an invalid run.

**Acceptance Scenarios**:

1. **Given** three comparable trials, **When** summarised, **Then** the view lists them and their spread (the largest
   minus the smallest p50, and the same for p95).
2. **Given** a trial of another OS version or an invalid one, **Then** it is listed as not comparable with its reason.
3. **Given** one comparable trial, **Then** no spread is shown ("one trial; run it again to compare").

---

### User Story 3 - The limits are explained where the numbers are (Priority: P1)

From a result and from the repeatability view the person opens "About these numbers": what each measure is (frame
interval, presenter CPU time, GPU time where a timer exists), what makes a run qualified or invalid, why results differ
between devices and runs (thermal state, Low Power Mode, display refresh, background work), that simulator numbers say
nothing about a device, and that the lab ranks nothing. It is plain text with spoken headings.

**Why this priority**: version 0.1 feature 06; constitution A24 truthful claims.

**Independent Test**: open the explanation from both places; read its sections; scan its words.

**Acceptance Scenarios**:

1. **Given** an opened result, **When** "About these numbers" is opened, **Then** each named limit is present and
   VoiceOver reads each heading.
2. **Given** the explanation's words, **When** scanned, **Then** there is no ranking, scientific or invented-number
   claim.

---

### User Story 4 - A first session works end to end in the app (Priority: P2)

In the one app, a person starts the textured-quads run, sees warm-up, measuring and cool-down, sees "Finished" with
percentiles and the qualification, saves the result, opens the results list, opens the result and its explanation.

**Why this priority**: interface evidence at this phase.

**Independent Test**: the interface chunk on the iOS 27.2 phone simulator.

**Acceptance Scenarios**:

1. **Given** a fresh start, **When** a run is started and finishes, **Then** the status reads "Finished", a
   qualification is shown, and saving lists the result.
2. **Given** the saved result, **When** it and its explanation are opened, **Then** both are present and the test takes
   under 60 seconds.

---

### User Story 5 - The device checks are planned, not claimed (Priority: P2)

A device plan lists, per device (D1, D2, D3), the checks only hardware can answer: repeatability of each case over
several trials, the thermal states seen during a long series, Low Power Mode, display refresh, the GPU timer's
availability and plausibility, and the system accessibility audits; each is pending until after
ImplementationLock-100.

**Independent Test**: read the plan.

**Acceptance Scenarios**:

1. **Given** the plan, **Then** it has rows for D1, D2 and D3 for each check, all pending, and states that no device
   number is claimed.

### Edge Cases

- **A run interrupted during warm-up:** invalid, no measured samples.
- **A thermal state that was already serious at the start:** qualified ("thermal state serious"), even without change.
- **A result saved before qualification existed (A24-P04):** qualified on reading from its stored report and state.
- **Trials of a case whose version changed:** not comparable ("different case version").
- **No GPU timer on one trial and a timer on another:** comparable on frame interval; the GPU column is shown only when
  every comparable trial has it.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A24-501**: Every ended run MUST be qualified as valid, qualified or invalid with named reasons, from its state,
  report and summary only.
- **FR-A24-502**: The list, the opened result, the JSON and the CSV MUST show the qualification and its reasons.
- **FR-A24-503**: A repeatability summary MUST compare only trials sharing the case fingerprint, device model, OS version,
  app build and tier that are not invalid, list the others with a reason, and give each trial's p50 and p95 and the
  spread.
- **FR-A24-504**: "About these numbers" MUST be reachable from an opened result and from the repeatability view, name
  each limit of User Story 3, and read with spoken headings.
- **FR-A24-505**: Interface tests MUST prove a full run, saving, opening the result and the explanation on the iOS 27.2
  phone simulator.
- **FR-A24-506**: A device plan MUST list the hardware checks per device, each pending.
- **FR-A24-507**: G-DEVICE and G-EXPLAIN MUST be closed with evidence; every public name documented.

### Key Entities

- **Qualification**: valid, qualified or invalid, and its reasons.
- **Repeatability summary**: comparable trials (p50, p95), spread, not comparable trials and reasons.
- **Device plan row**: GBL-Dn, devices, steps, expected result, owner actions, state pending.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A24-501**: 100% of the qualification fixtures give the expected class and reasons; a suspended run is invalid.
- **SC-A24-502**: 100% of the repeatability fixtures give the expected comparable set and spread.
- **SC-A24-503**: The explanation names 100% of the listed limits; the copy scan finds 0 refused words.
- **SC-A24-504**: The interface tests pass on the iOS 27.2 phone simulator, each in under 60 seconds.
- **SC-A24-505**: The device plan has rows for each of D1, D2 and D3, all pending.
- **SC-A24-506**: Each unit test finishes in under 10 seconds.

## Assumptions

- A24-P01 to P04 are reused; the qualification is computed, not stored, so old saved results need no migration.
- The interface test's run uses the built-in quads case (18 s) or a shorter test plan if the 60-second limit requires it.

## Traceability

| Source | Requirement |
|---|---|
| MVP: results export as versioned JSON or CSV (with qualification) | FR-A24-502 |
| Regression fixture: background/thermal interruption flags invalid/qualified | FR-A24-501, US1 |
| EGL/context ownership solely in the host | Assumptions (no graphics in qualification or comparison) |
| Version 0.1 feature 06: explanation of limits and variability | FR-A24-504, US3 |
| Manual risk 1 (thermal and refresh skew), risk 3 (overheating) | FR-A24-501, 503, 506 |
| Contract G-DEVICE, G-EXPLAIN | FR-A24-501–507 |

## Negative Requirements

- No ranking of devices, no scientific claim, no device number, no network, no VisualCore change, no device run.
