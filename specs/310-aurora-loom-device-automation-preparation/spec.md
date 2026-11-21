# Feature Specification: R02-G01-10 — Aurora Loom: device automation preparation

**Feature Branch**: `310-aurora-loom-device-automation-preparation` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Clarified

**Ledger gate**: R02-G01-10 (migration ledger, game feature of experience R02-G01) · ID namespace FR-R02G0110-###,
SC-R02G0110-###, T-R02G0110-###

**Input**: User description: the archived R02-G01-10 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Build automation runner and acceptance contract but do not launch a device yet" for Aurora Loom, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/310-aurora-loom-device-automation-preparation`; FR-R02G0110-###,
  SC-R02G0110-###, T-R02G0110-###.
- **Scope (Auto-Creator.md section 21, round-two feature 10):** "scenario set and device-row definition only; no
  device contact before ImplementationLock-100 (UA-F13)". The automation runner is UA-F13's campaign script, written
  in that feature; this feature defines what it will run and measure for Aurora Loom and the conditions each row must
  meet. No device is contacted, installed or listed.
- **Packaging (ADR-0009):** experience R02-G01 (`r02-g01.aurora-loom`, free; a registered candidate) in the one app.
- **Device rules:** devices in fixed order D1 iPhone 15, D2 iPad Pro 13-inch (M5), D3 iPad (A16) on iPadOS 26.5 (never
  updated); manual VoiceOver testing is non-gating (P-08). **Owner-only items:** every device handling step (unlock,
  trust, signing, settings, charging) is the owner's, written as such in the plan.

## Clarifications

### Session 2026-11-21

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked
(read-only audit, 2026-11-21): the ledger holds DEV1-R02-G01 (D1 iPhone 15), DEV2-R02-G01 (D2 iPad Pro 13-inch (M5))
and DEV3-R02-G01 (D3 iPad (A16), iPadOS 26.5), each after ImplementationLock-100 and UA-F13; Aurora Loom's manifest has
95 scenarios (11 standard and game scenarios, 4 fixtures, 80 acceptance rows); the deferred {device} tasks are
T-R02G0103-015 (frame time per tier), T-R02G0104-011 (gesture feel, touch-to-frame), the hearing, feeling and VoiceOver
items of R02-G01-06, T-R02G0107-011 (progress across a real termination), T-R02G0108-012 (frame time and memory per tier)
and T-R02G0109-011 (the journeys); `docs/performance/budgets.md` holds the app's device budgets as proposals (first
frame, 60 fps with automatic levels, flat memory, 200 samples per device); A21's plan is
`docs/apps/aurora/device-campaign.md` (rows AU-D1 … AU-D8).

- Q: Which device rows exist and which tasks does each cover? → A: AL-D1 launch and first frame (UA-F13 launch, first
  frame); AL-D2 frame pacing and frame time per tier (T-R02G0103-015, T-R02G0108-012, UA-F13 frame pacing); AL-D3 memory
  per tier and thermal state with the round-two stress session (T-R02G0108-012, UA-F13 memory, thermal, stress); AL-D4
  gesture feel and touch-to-frame latency (T-R02G0104-011); AL-D5 sound and haptics heard and felt (R02-G01-06 items);
  AL-D6 VoiceOver walk-through, non-gating (R02-G01-06 items, P-08); AL-D7 progress across a real termination
  (T-R02G0107-011); AL-D8 panel journeys: win level 1 with pending steps and Apply, replay, relaunch (T-R02G0109-011).
  All rows run on D1, D2, D3 in that order. Impact: FR-R02G0110-001, 003; SC-R02G0110-001.
- Q: What is the device scenario set? → A: the 11 standard and game scenarios (`launch-first-frame`, `input-response`,
  `completion`, `rejection`, `save-restore`, `reset`, `suspend-resume`, `teardown-reentry`, `cancel-prepare`,
  `full-playthrough`, `hero`) and `fixture-replay`; the 80 acceptance rows and the other fixtures stay simulator-only
  (pure rule outcomes the host and simulator already prove). Impact: FR-R02G0110-001.
- Q: What does the machine-readable definition look like? → A: `docs/apps/aurora-loom/device-rows.json`, schema 1, sorted
  keys: `experience`, `devices` (`["D1", "D2", "D3"]` with the ledger row of each), `scenarios` (names), `rows` (each
  `id`, `title`, `devices`, `procedure`, `measurements` (names), `pass` (the condition in words), `gating` (true except
  AL-D6), `covers` (task ids and UA-F13 measurement names), `owner_steps`, `status` "pending device campaign"). Impact:
  FR-R02G0110-001; data model.
- Q: Where does the check run and what does it compare? → A: `scripts/check_device_rows.py --experience
  r02-g01.aurora-loom` (exit 1 with named reasons): JSON shape and required fields; every scenario in the manifest; the
  devices equal the ledger's DEV1/2/3 rows of the experience; every open {device} task line in the tasks of features 301–309
  (`specs/30[1-9]-aurora-loom-*/tasks.md`; 310's own campaign task is not a coverage item) and every UA-F13 measurement name (launch, first-frame, frame-pacing, memory, thermal, stress) is covered by
  some row; every row's status is "pending device campaign" and no row carries a result or measured-value field. Tests in
  `scripts/test_scripts.py`; run in `release_check.py` as step `device-rows`. Impact: FR-R02G0110-004; SC-R02G0110-001,
  002.
- Q: What pass conditions do the rows use? → A: the app's proposed budgets where they exist (first frame without a shader
  compiled after interaction; 60 fps with automatic levels, 30 fps acceptable on the last level; memory flat over the
  stress session within the declared budget; 200 samples per device) and otherwise "recorded" (a measurement reported,
  not judged) or a stated observation (sound audible, haptic felt, VoiceOver reads every control, progress kept, level 1
  won with 3 stars). Every row's status stays "pending device campaign". Impact: FR-R02G0110-002; SC-R02G0110-004.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The device campaign knows exactly what to run for Aurora Loom (Priority: P1) 🎯

When the device lab starts after the lock, it finds a single, checked definition of Aurora Loom's device scenarios and
rows, so nothing is improvised on the devices and every earlier "after the lock" promise is measured.

**Independent Test**: a check reads the definition and confirms every scenario exists in the experience's scenario set,
every row names its devices, procedure and pass condition, and every deferred device item of features 301–309 is
covered by a row.

**Acceptance Scenarios**:

1. **Given** the device row definition, **When** it is checked, **Then** every scenario it names exists in Aurora Loom's
   scenario manifest and every row has devices D1, D2, D3 (or a stated subset), a procedure, a pass condition and the
   status "pending device campaign".
2. **Given** the {device} tasks of features 301–309, **When** they are compared with the rows, **Then** each one is
   covered by at least one row.

### User Story 2 - A person can follow the plan on the devices (Priority: P2)

The owner (who handles the devices) and the campaign script read the same plan: what to do, what the owner must do by
hand, what is measured and what counts as pass.

**Independent Test**: the written plan lists each row with its owner steps and pass condition and claims no device
number.

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

- **FR-R02G0110-001**: A machine-readable definition MUST name Aurora Loom's device scenario set (scenarios from its
  manifest) and its device rows (id, title, devices, procedure, measurements, pass condition, the earlier tasks it
  covers, status pending).
- **FR-R02G0110-002**: A written plan MUST describe every row for a person: devices in order, owner steps, procedure,
  pass condition, and that no number is claimed before the campaign.
- **FR-R02G0110-003**: Every {device} task of features 301–309 and UA-F13's per-experience measurements (launch, first
  frame, frame pacing, memory, thermal state, the round-two stress session) MUST be covered by a row.
- **FR-R02G0110-004**: A check MUST validate the definition against the scenario manifest, the ledger's device rows of
  R02-G01 and the {device} tasks, and fail naming any mismatch.
- **FR-R02G0110-005**: No device MUST be contacted; existing tests MUST pass; the reference regression passes.

### Key Entities

- **Device scenario set**: the manifest scenarios the campaign runs on each device.
- **Device row**: id (AL-D1 …), title, devices, procedure, measurements, pass condition, covered tasks, status.
- **Coverage**: the mapping from each deferred {device} task to its rows.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0110-001**: The check passes: every named scenario exists, every row is complete, all {device} tasks of
  301–309 and all UA-F13 measurements are covered.
- **SC-R02G0110-002**: Removing a scenario from the manifest copy, a field from a row or a covered task from the
  definition each makes the check fail with a named reason.
- **SC-R02G0110-003**: No device is contacted; existing tests pass; the reference regression passes 7 of 7.
- **SC-R02G0110-004** {device}: after ImplementationLock-100, the rows are run by the device campaign on D1/D2/D3.

## Assumptions

- UA-F13's campaign script will read the definition; until it exists, the check and the written plan are the contract.
- Pass conditions use the experience's own budgets (frame pacing, memory) where a budget exists and otherwise "recorded"
  (a measurement taken and reported, not judged).

## Traceability

| Source item (round2.md R2-G01-10) | Requirement |
|---|---|
| Automation runner (device part) | UA-F13 (superseded here); FR-R02G0110-001 defines its input |
| Acceptance contract | FR-R02G0110-001, 002, 004 |
| Do not launch a device | FR-R02G0110-005 |
