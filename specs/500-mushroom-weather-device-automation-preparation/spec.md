# Feature Specification: R02-G20-10 — Mushroom Weather: device automation preparation

**Feature Branch**: `500-mushroom-weather-device-automation-preparation` (spec directory only; work on `main`)

**Created**: 2026-11-26

**Status**: Clarified

**Ledger gate**: R02-G20-10 (migration ledger, game feature of experience R02-G20) · ID namespace FR-R02G2010-###,
SC-R02G2010-###, T-R02G2010-###

**Input**: User description: the archived R02-G20-10 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Build automation runner and acceptance contract but do not launch a device yet" for Mushroom Weather, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/500-mushroom-weather-device-automation-preparation`; FR-R02G2010-###,
  SC-R02G2010-###, T-R02G2010-###.
- **Scope (Auto-Creator.md section 21, round-two feature 10):** "scenario set and device-row definition only; no device
  contact before ImplementationLock-100 (UA-F13)". The automation runner is UA-F13's campaign script, written in that
  feature; this feature defines what it will run and measure for Mushroom Weather and the conditions each row must
  meet. No device is contacted, installed or listed.
- **Packaging (ADR-0009):** experience R02-G20 (`r02-g20.mushroom-weather`, free; a registered candidate) in the
  one app.
- **Device rules:** devices in fixed order D1 iPhone 15, D2 iPad Pro 13-inch (M5), D3 iPad (A16) on iPadOS 26.5 (never
  updated); manual VoiceOver testing is non-gating (P-08). **Owner-only items:** every device handling step (unlock,
  trust, signing, settings, charging) is the owner's, written as such in the plan.

## Clarifications

### Session 2026-11-26

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
490's answers (the games agree on the scenario set, the definition, the check and the pass conditions; only the gestures
and the panel journey differ). Facts checked (read-only, 2026-11-26): the ledger holds DEV1-R02-G20 (D1 iPhone 15),
DEV2-R02-G20 (D2 iPad Pro 13-inch (M5)) and DEV3-R02-G20 (D3 iPad (A16), iPadOS 26.5), each pending until after
ImplementationLock-100 and UA-F13; Mushroom Weather's manifest has 94 scenarios (11 standard and game scenarios, 3
fixtures `fixture-level-1-solved`, `fixture-run-fails`, `fixture-undo-redo`, 80 acceptance rows); the open {device}
tasks are T-R02G2003-012 (frame time per tier), T-R02G2004-011 (touch feel and latency), T-R02G2006-011 (sound, haptics
and VoiceOver), T-R02G2007-012 (a save across a real termination), T-R02G2008-012 (frame time and memory of the golden
levels) and T-R02G2009-011 (the journeys); features 491, 492 and 495 have no {device} task;
`scripts/check_device_rows.py` (feature 310) is generic over experience ids; `release_check.py` runs it as `device-rows`
… `device-rows-r02-g19`; feature 490's plan is `docs/apps/microscopic-aurora/device-campaign.md` (rows MA-D1 … MA-D8);
the gestures of feature 494 are a tap on an empty site (place a pod), a drag of a pod to another site or off the floor
(preview the kernel's run, set on release), a tap on a vent (toggle), a vertical drag on the moon (preview the
moonlight, set on release), a drag along the scrubber (show a cycle), a double tap off the floor (Reset view) and
two-finger orbit; the interface namespace of feature 499 is `MW`, so the rows are MW-D1 … MW-D8.

- Q: Which device rows exist and which tasks does each cover? → A: MW-D1 launch and first frame (UA-F13 launch,
  first-frame); MW-D2 frame pacing and frame time per tier (T-R02G2003-012, T-R02G2008-012, UA-F13 frame-pacing); MW-D3
  memory per tier and thermal state with the round-two stress session (T-R02G2008-012, UA-F13 memory, thermal, stress);
  MW-D4 touch feel and touch-to-frame latency of a tap on a site that places a pod, a pod drag that previews the run and
  moves or removes the pod, a vent tap, a moon drag that previews and sets the moonlight, a scrubber drag that shows a
  cycle, a double tap off the floor that resets the view and two-finger orbit (T-R02G2004-011); MW-D5 sound and haptics
  heard and felt (T-R02G2006-011); MW-D6 VoiceOver walk-through at the largest text size, non-gating (T-R02G2006-011,
  P-08); MW-D7 progress across a real termination (T-R02G2007-012); MW-D8 panel journeys: win level 1 with its pod placed,
  its vent closed and the run, replay, relaunch (T-R02G2009-011). All rows run on D1, D2, D3 in that order. Impact:
  FR-R02G2010-001, 003; SC-R02G2010-001.
- Q: What is the device scenario set? → A: the 11 standard and game scenarios (`launch-first-frame`, `input-response`,
  `completion`, `rejection`, `save-restore`, `reset`, `suspend-resume`, `teardown-reentry`, `cancel-prepare`,
  `full-playthrough`, `hero`) and `fixture-level-1-solved`; the 80 acceptance rows and the other two fixtures stay
  simulator-only. Impact: FR-R02G2010-001.
- Q: What does the machine-readable definition look like? → A: `docs/apps/mushroom-weather/device-rows.json`, the schema
  of feature 310 (schema 1, sorted keys: `experience`, `devices` with the ledger row of each, `scenarios`, `rows` with
  `id`, `title`, `devices`, `procedure`, `measurements`, `pass`, `gating` (true except MW-D6), `covers`, `owner_steps`,
  `status` "pending device campaign"). Impact: FR-R02G2010-001; data model.
- Q: Where does the check run? → A: the existing `scripts/check_device_rows.py --experience r02-g20.mushroom-weather`
  unchanged in its rules; `release_check.py` gains the step `device-rows-r02-g20`; `scripts/test_scripts.py` gains a
  test that the real Mushroom Weather definition passes and that removing a covered task or a scenario fails with a
  named reason. Impact: FR-R02G2010-004; SC-R02G2010-001, 002.
- Q: What pass conditions do the rows use? → A: those of features 310 … 490: the app's proposed budgets where they exist
  (no shader compiled after interaction; 60 fps with automatic levels, 30 fps acceptable on the last level; memory flat
  over the stress session; 200 samples per device), otherwise "recorded" or a stated observation (sound audible, haptic
  felt, VoiceOver reads every control, progress kept, level 1 won with 3 stars). Every row stays "pending device
  campaign". Impact: FR-R02G2010-002; SC-R02G2010-004.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The device campaign knows exactly what to run for Mushroom Weather (Priority: P1) 🎯

When the device lab starts after the lock, it finds a single, checked definition of Mushroom Weather's device
scenarios and rows, so nothing is improvised on the devices and every earlier "after the lock" promise is measured.

**Why this priority**: without it the device campaign would have to guess what each earlier deferred promise means.

**Independent Test**: a check reads the definition and confirms every scenario exists in the experience's scenario set,
every row names its devices, procedure and pass condition, and every deferred device item of features 491–499 is
covered by a row.

**Acceptance Scenarios**:

1. **Given** the device row definition, **When** it is checked, **Then** every scenario it names exists in Mushroom
   Weather's scenario manifest and every row has devices D1, D2, D3 (or a stated subset), a procedure, a pass
   condition and the status "pending device campaign".
2. **Given** the {device} tasks of features 491–499, **When** they are compared with the rows, **Then** each one is
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

- **FR-R02G2010-001**: A machine-readable definition MUST name Mushroom Weather's device scenario set (scenarios
  from its manifest) and its device rows (id, title, devices, procedure, measurements, pass condition, the earlier tasks
  it covers, status pending).
- **FR-R02G2010-002**: A written plan MUST describe every row for a person: devices in order, owner steps, procedure,
  pass condition, and that no number is claimed before the campaign.
- **FR-R02G2010-003**: Every {device} task of features 491–499 and UA-F13's per-experience measurements (launch, first
  frame, frame pacing, memory, thermal state, the round-two stress session) MUST be covered by a row.
- **FR-R02G2010-004**: A check MUST validate the definition against the scenario manifest, the ledger's device rows of
  R02-G20 and the {device} tasks, and fail naming any mismatch.
- **FR-R02G2010-005**: No device MUST be contacted; existing tests MUST pass; the reference regression passes.

### Key Entities

- **Device scenario set**: the manifest scenarios the campaign runs on each device.
- **Device row**: id (MW-D1 … MW-D8, clarification Q1), title, devices, procedure,
  measurements, pass condition, covered tasks, status.
- **Coverage**: the mapping from each deferred {device} task to its rows.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G2010-001**: The check passes: every named scenario exists, every row is complete, all {device} tasks of
  491–499 and all UA-F13 measurements are covered.
- **SC-R02G2010-002**: Removing a scenario from the manifest copy, a field from a row or a covered task from the
  definition each makes the check fail with a named reason.
- **SC-R02G2010-003**: No device is contacted; existing tests pass; the reference regression passes 7 of 7.
- **SC-R02G2010-004** {device}: after ImplementationLock-100, the rows are run by the device campaign on D1/D2/D3.

## Assumptions

- UA-F13's campaign script will read the definition; until it exists, the check and the written plan are the contract.
- Pass conditions use the experience's own budgets (frame pacing, memory) where a budget exists and otherwise "recorded"
  (a measurement taken and reported, not judged).
- Feature 490 (Microscopic Aurora) is the model: the same definition schema, check and plan layout.
- This feature adds no code, visuals or layout: the code-only graphics, their licensing and the iPhone and iPad layout
  stay those of features 493, 496 and 499; simulator proof of the game is features 498 and 499.

## Traceability

| Source item (round2.md R2-G19-10) | Requirement |
|---|---|
| Automation runner (device part) | UA-F13 (superseded here); FR-R02G2010-001 defines its input |
| Acceptance contract | FR-R02G2010-001, 002, 004 |
| Do not launch a device | FR-R02G2010-005 |
| Deterministic tests, error handling | FR-R02G2010-004; Edge Cases |
| Accessibility | the VoiceOver row (non-gating, P-08), FR-R02G2010-003 |
| Copyright/originality | no new visual or audio content; the experience is unchanged |
| Schema migration | none (no saved state changes) |
| Excluded scope | device contact, measured numbers, the campaign script (UA-F13), price, per-game app |
