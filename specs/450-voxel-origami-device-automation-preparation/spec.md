# Feature Specification: R02-G15-10 — Voxel Origami: device automation preparation

**Feature Branch**: `450-voxel-origami-device-automation-preparation` (spec directory only; work on `main`)

**Created**: 2026-11-24

**Status**: Draft

**Ledger gate**: R02-G15-10 (migration ledger, game feature of experience R02-G15) · ID namespace FR-R02G1510-###,
SC-R02G1510-###, T-R02G1510-###

**Input**: User description: the archived R02-G15-10 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Build automation runner and acceptance contract but do not launch a device yet" for Voxel Origami, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/450-voxel-origami-device-automation-preparation`; FR-R02G1510-###,
  SC-R02G1510-###, T-R02G1510-###.
- **Scope (Auto-Creator.md section 21, round-two feature 10):** "scenario set and device-row definition only; no
  device contact before ImplementationLock-100 (UA-F13)". The automation runner is UA-F13's campaign script, written
  in that feature; this feature defines what it will run and measure for Voxel Origami and the conditions each row
  must meet. No device is contacted, installed or listed.
- **Packaging (ADR-0009):** experience R02-G15 (`r02-g15.voxel-origami`, free; a registered candidate) in the one
  app.
- **Device rules:** devices in fixed order D1 iPhone 15, D2 iPad Pro 13-inch (M5), D3 iPad (A16) on iPadOS 26.5 (never
  updated); manual VoiceOver testing is non-gating (P-08). **Owner-only items:** every device handling step (unlock,
  trust, signing, settings, charging) is the owner's, written as such in the plan.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The device campaign knows exactly what to run for Voxel Origami (Priority: P1) 🎯

When the device lab starts after the lock, it finds a single, checked definition of Voxel Origami's device
scenarios and rows, so nothing is improvised on the devices and every earlier "after the lock" promise is measured.

**Why this priority**: without it the device campaign would have to guess what each earlier deferred promise means.

**Independent Test**: a check reads the definition and confirms every scenario exists in the experience's scenario set,
every row names its devices, procedure and pass condition, and every deferred device item of features 441–449 is
covered by a row.

**Acceptance Scenarios**:

1. **Given** the device row definition, **When** it is checked, **Then** every scenario it names exists in Voxel
   Origami's scenario manifest and every row has devices D1, D2, D3 (or a stated subset), a procedure, a pass
   condition and the status "pending device campaign".
2. **Given** the {device} tasks of features 441–449, **When** they are compared with the rows, **Then** each one is
   covered by at least one row.

### User Story 2 - A person can follow the plan on the devices (Priority: P2)

The owner (who handles the devices) and the campaign script read the same plan: what to do, what the owner must do by
hand, what is measured and what counts as pass.

**Why this priority**: the plan is read by a person only once the campaign starts; the checked definition comes first.

**Independent Test**: the written plan lists each row with its owner steps and pass condition and claims no device
number.

**Acceptance Scenarios**:

1. **Given** the written plan, **When** a person reads any row, **Then** it states the devices in order, the owner
   steps, the procedure, what is measured and the pass condition, and no measured value.

### Edge Cases

- **No device numbers before the lock:** the plan and the definition contain no measured device value; every row is
  "pending device campaign".
- **D3's operating system:** the plan states D3 stays on iPadOS 26.5 and is refused otherwise.
- **Long measurements:** the round-two stress session (UA-F13) runs only on devices; nothing here runs it.
- **A missing scenario:** a definition naming a scenario that the manifest lacks fails the check, naming it.
- **A missing or unreadable definition, a schema other than 1, or an unknown experience:** the check fails naming the
  file or the id; it never passes by default.
- **Owner-needed device states** (locked device, trust, signing, settings, charging): each row lists them as owner
  steps; the campaign records them as BLOCKED_OWNER_ACTION with the steps and never waits for input (UA-F13).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1510-001**: A machine-readable definition MUST name Voxel Origami's device scenario set (scenarios from
  its manifest) and its device rows (id, title, devices, procedure, measurements, pass condition, the earlier tasks it
  covers, status pending).
- **FR-R02G1510-002**: A written plan MUST describe every row for a person: devices in order, owner steps, procedure,
  pass condition, and that no number is claimed before the campaign.
- **FR-R02G1510-003**: Every {device} task of features 441–449 and UA-F13's per-experience measurements (launch, first
  frame, frame pacing, memory, thermal state, the round-two stress session) MUST be covered by a row.
- **FR-R02G1510-004**: A check MUST validate the definition against the scenario manifest, the ledger's device rows of
  R02-G15 and the {device} tasks, and fail naming any mismatch.
- **FR-R02G1510-005**: No device MUST be contacted; existing tests MUST pass; the reference regression passes.

### Key Entities

- **Device scenario set**: the manifest scenarios the campaign runs on each device.
- **Device row**: id (VO-D1 … VO-D8, clarification Q1), title, devices, procedure,
  measurements, pass condition, covered tasks, status.
- **Coverage**: the mapping from each deferred {device} task to its rows.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1510-001**: The check passes: every named scenario exists, every row is complete, all {device} tasks of
  441–449 and all UA-F13 measurements are covered.
- **SC-R02G1510-002**: Removing a scenario from the manifest copy, a field from a row or a covered task from the
  definition each makes the check fail with a named reason.
- **SC-R02G1510-003**: No device is contacted; existing tests pass; the reference regression passes 7 of 7.
- **SC-R02G1510-004** {device}: after ImplementationLock-100, the rows are run by the device campaign on D1/D2/D3.

## Assumptions

- UA-F13's campaign script will read the definition; until it exists, the check and the written plan are the contract.
- Pass conditions use the experience's own budgets (frame pacing, memory) where a budget exists and otherwise "recorded"
  (a measurement taken and reported, not judged).
- Feature 440 (Moonlit Mechanism) is the model: the same definition schema, check and plan layout.
- This feature adds no code, visuals or layout: the code-only graphics, their licensing and the iPhone and iPad layout
  stay those of features 443, 446 and 449; simulator proof of the game is features 448 and 449.

## Traceability

| Source item (round2.md R2-G15-10) | Requirement |
|---|---|
| Automation runner (device part) | UA-F13 (superseded here); FR-R02G1510-001 defines its input |
| Acceptance contract | FR-R02G1510-001, 002, 004 |
| Do not launch a device | FR-R02G1510-005 |
| Deterministic tests, error handling | FR-R02G1510-004; Edge Cases |
| Accessibility | the VoiceOver row (non-gating, P-08), FR-R02G1510-003 |
| Copyright/originality | no new visual or audio content; the experience is unchanged |
| Schema migration | none (no saved state changes) |
| Excluded scope | device contact, measured numbers, the campaign script (UA-F13), price, per-game app |
