# Feature Specification: Ambient Clock — Phase 05 Overnight device tests and App Store QA

**Feature Branch**: `135-ac-p05-device-qa` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A18-P05 (legacy ledger) · ID namespace FR-A18-5##, SC-A18-5##, T-A18-5##

**Input**: User description: archived manual `apps/18-ambient-clock.md` §9 Phase 05 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 05):**
  - MVP: night mode and the motion-reduction option, checked through the app's interface on the simulator here and on
    devices in the campaign;
  - regression fixture: frame scheduling lowers work for a static background with seconds off;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gap built here:** G-DEVICE, the device campaign plan. Overnight runs, heat, memory, frame pacing, drift and night
  readability on real devices are {device} tasks that run only after ImplementationLock-100.
- **Regression fixture:** a picture that does not change is drawn once and then reused. An additive VisualCoreRendering
  scene redraws its child only when the child's state key changes, because experiences may not call the graphics API
  directly.
- Follow `specs/128-ia-p05-review-device-qa`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A still clock does almost no work (Priority: P1) 🎯

A person who turns motion off (or uses Reduce Motion) and hides the seconds sees the same calm picture, while the
clock redraws its background only when something visible changes.

**Why this priority**: the manual's regression fixture and its thermal risk.

**Independent Test**: count how often the background is drawn over many frames with a still picture, with motion
on, and after a change.

**Acceptance Scenarios**:

1. **Given** a still picture (motion off or reduced, seconds off), **When** 120 frames are drawn with no change,
   **Then** the background is drawn once and the frames are identical.
2. **Given** a change (theme, palette, night, dim, drift step, size, quality level), **Then** the background is drawn
   again once and the new frame matches a fresh drawing.
3. **Given** motion on, **Then** the background is drawn every frame, as before.

---

### User Story 2 - The owner can run the overnight campaign (Priority: P1)

The owner has an exact device plan: what to run overnight on which device, what to record and the thresholds that
pass.

**Why this priority**: the manual's Phase 05 deliverable.

**Independent Test**: read the campaign document; every row has a device, procedure, threshold and status.

**Acceptance Scenarios**:

1. **Given** the document, **Then** each row names a device class, a procedure, a threshold and "pending device
   campaign".
2. **Given** a claim in the store copy, **Then** it is backed by a test or by a campaign row, never by a guess.

---

### User Story 3 - Night mode and motion reduction work from the interface (Priority: P2)

A person can turn on night mode and the clock's own motion reduction from the controls, and both survive a reopen.

**Why this priority**: the manual's MVP for this phase.

**Independent Test**: an interface test on the iOS 27 phone simulator.

**Acceptance Scenarios**:

1. **Given** the clock open, **When** night mode is set on and reduce motion on, **Then** the controls show them and
   reopening keeps them.

### Edge Cases

- **A context loss with a cached picture:** the cache is rebuilt and drawn again.
- **A resize:** the cache is rebuilt at the new size.
- **The drift moves while motion is off:** each drift step redraws once (about every few seconds), never every frame.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A18-501**: A picture whose state key has not changed MUST NOT be redrawn; the cached picture MUST be shown
  unchanged.
- **FR-A18-502**: Any change of the state key MUST redraw the background once; context loss and resize MUST rebuild the
  cache.
- **FR-A18-503**: The cache MUST be an additive VisualCore scene with documentation, tests and an API baseline update,
  and the reference regression at X-A18; existing scenes are unchanged.
- **FR-A18-504**: The device campaign MUST list the overnight, heat, memory, frame-pacing, drift, night-readability,
  daylight-saving and accessibility rows, each with device class, procedure, threshold and status.
- **FR-A18-505**: The interface tests MUST set night mode and reduce motion from the controls and find them after a
  reopen.
- **FR-A18-506**: No pacing, heat, battery or memory number is claimed anywhere before the campaign.

### Key Entities

- **Cached picture**: child scene, state key, target, draw count.
- **Campaign row**: id, measurement, device, procedure, threshold, status.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A18-501**: Over 120 still frames the background is drawn exactly once; the frames are identical.
- **SC-A18-502**: Each kind of change redraws exactly once; motion on draws every frame.
- **SC-A18-503**: The campaign document has at least eight rows, all pending, each complete.
- **SC-A18-504**: The interface tests pass on the iOS 27 phone simulator in under 60 seconds each; every other test
  under 10 seconds.

## Assumptions

- The campaign runs only after ImplementationLock-100, in the order D1 → D2 → D3; D3 is not updated from iPadOS 26.5.

## Traceability

| Source | Requirement |
|---|---|
| Phase 05 deliverable: overnight device tests and App Store QA | FR-A18-504, 506 |
| MVP: night mode and motion reduction | FR-A18-505 |
| Regression fixture: lower work for a static background with seconds off | FR-A18-501–503 |
| Manual risk 1: thermal load | FR-A18-501, 504 |
| Contract G-DEVICE | FR-A18-504, 506 |

## Negative Requirements

- No device install or measurement before ImplementationLock-100; no number claimed without a measurement; no
  accessibility audit before devices (owner ruling of 2026-11-13).
