# Feature Specification: R02-G21-10 — Binary Gardens: device automation preparation

**Feature Branch**: `510-binary-gardens-device-automation-preparation` (spec directory only; work on `main`)

**Created**: 2026-11-27

**Status**: Clarified

**Ledger gate**: R02-G21-10 (migration ledger, game feature of experience R02-G21) · ID namespace FR-R02G2110-###,
SC-R02G2110-###, T-R02G2110-###

**Input**: User description: the archived R02-G21-10 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Build automation runner and acceptance contract but do not launch a device yet" for Binary Gardens, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/510-binary-gardens-device-automation-preparation`; FR-R02G2110-###,
  SC-R02G2110-###, T-R02G2110-###.
- **Scope (Auto-Creator.md section 21, round-two feature 10):** "scenario set and device-row definition only; no device
  contact before ImplementationLock-100 (UA-F13)". The automation runner is UA-F13's campaign script, written in that
  feature; this feature defines what it will run and measure for Binary Gardens and the conditions each row must meet.
  No device is contacted, installed or listed.
- **Packaging (ADR-0009):** experience R02-G21 (`r02-g21.binary-gardens`, free; a registered candidate) in the one
  app. No app target, bundle identifier, scheme or store listing; the source's price and "no IAP" are replaced by the
  shared purchase controller (tier free).
- **Prerequisites:** features 505 … 509 (R02-G21-05 … 09) are recorded in the ledger before this gate is recorded; the
  rows describe the experience as those features leave it (progress and stars, the tutorial, announcements, haptics and
  the Sound toggle, saved progress and replay, the golden levels and the interface journeys).
- **Device rules:** devices in fixed order D1 iPhone 15, D2 iPad Pro 13-inch (M5), D3 iPad (A16) on iPadOS 26.5 (never
  updated); manual VoiceOver testing is non-gating (P-08). **Owner-only items:** every device handling step (unlock,
  trust, signing, settings, charging) is the owner's, written as such in the plan and recorded by the campaign as
  BLOCKED_OWNER_ACTION with its steps.

## Clarifications

### Session 2026-11-27

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
500's answers (the games agree on the scenario set, the definition, the check and the pass conditions; only the gestures,
the panel journey and the identifiers differ). Facts checked (read-only, 2026-11-27): the ledger holds DEV1-R02-G21 (D1
iPhone 15), DEV2-R02-G21 (D2 iPad Pro 13-inch (M5)) and DEV3-R02-G21 (D3 iPad (A16), must stay on iPadOS 26.5), each
pending until after ImplementationLock-100 and UA-F13; Binary Gardens' manifest
(`Packages/ExperiencesRound02/BinaryGardens/scenario-manifest.json`) has 94 scenarios (11 standard and game scenarios, 3
fixtures `fixture-level-1-solved`, `fixture-run-fails`, `fixture-undo-redo`, 80 acceptance rows); the open {device}
tasks are T-R02G2103-012 (frame time per tier), T-R02G2104-011 (touch feel and latency), T-R02G2106-011 (sound,
haptics and VoiceOver), T-R02G2107-012 (a save across a real termination), T-R02G2108-012 (frame time and memory of the
golden levels) and T-R02G2109-011 (the journeys); features 501, 502 and 505 have no {device} task;
`scripts/check_device_rows.py` (feature 310) is generic over experience ids, reads features 501 … 509 for R02-G21 by its
round-two numbering, and has no extra device items for R02-G21; `release_check.py` runs it as `device-rows` …
`device-rows-r02-g20`; feature 500's plan is `docs/apps/mushroom-weather/device-campaign.md` (rows MW-D1 … MW-D8) and its
check test is `MushroomWeatherDeviceRowsCheckTests` in `scripts/test_scripts.py`; the gestures of feature 504 are a tap
on a world (inspect), a tap on a star (select and explain), a tap on a luminosity pip or the tilt dial (set it), a tap or
drag on a gauge row (show a tick), a star drag along its orbit or across its rings (preview the kernel's report with a
ghost star, set on release), a horizontal drag on a luminosity pip row or the tilt dial (one step per 32 points,
preview, set on release), a double tap on empty space (Reset view) and two-finger orbit; the panel identifiers are
`experience.r02-g21.binary-gardens.<name>` (`BinaryGardensControls`); feature 509 names the interface namespace `BG`
(`BGPlayUITests`, `BGReplayUITests`, serial chunk `d4`), so the rows are BG-D1 … BG-D8; level 1's certified plan is one
action, star 2 set to luminosity level 1 of 2 (index 0), then the run.

- Q: Which device rows exist and which tasks does each cover? → A: BG-D1 launch and first frame (UA-F13 launch,
  first-frame); BG-D2 frame pacing and frame time per tier (T-R02G2103-012, T-R02G2108-012, UA-F13 frame-pacing); BG-D3
  memory per tier and thermal state with the round-two stress session (T-R02G2108-012, UA-F13 memory, thermal, stress);
  BG-D4 touch feel and touch-to-frame latency of a tap on a world that inspects it, a tap on a star that selects it, a
  tap on a luminosity pip and on the tilt dial that sets them, a gauge-row tap and drag that show a tick, a star drag
  across its rings and along its orbit that previews and sets the change, a luminosity drag and a tilt drag that
  preview and set the value, a double tap on empty space that resets the view and two-finger orbit (T-R02G2104-011);
  BG-D5 sound and haptics heard and felt (T-R02G2106-011); BG-D6 VoiceOver walk-through at the largest text size,
  non-gating (T-R02G2106-011, P-08); BG-D7 progress across a real termination (T-R02G2107-012); BG-D8 panel journeys:
  win level 1 with star 2's luminosity lowered and the run, reading the panel's win text, replay, relaunch
  (T-R02G2109-011); BG-D5 and BG-D6 quote feature 506's spoken announcements, re-read when R02-G21-06 is recorded. All rows run on D1, D2,
  D3 in that order. Impact: FR-R02G2110-001, 003; SC-R02G2110-001.
- Q: What is the device scenario set? → A: the 11 standard and game scenarios (`launch-first-frame`, `input-response`,
  `completion`, `rejection`, `save-restore`, `reset`, `suspend-resume`, `teardown-reentry`, `cancel-prepare`,
  `full-playthrough`, `hero`) and `fixture-level-1-solved`; the 80 acceptance rows and the other two fixtures stay
  simulator-only. Impact: FR-R02G2110-001.
- Q: What does the machine-readable definition look like? → A: `docs/apps/binary-gardens/device-rows.json`, the schema
  of feature 310 (schema 1, sorted keys: `experience`, `devices` with the ledger row of each, `scenarios`, `rows` with
  `id`, `title`, `devices`, `procedure`, `measurements`, `pass`, `gating` (true except BG-D6), `covers`, `owner_steps`,
  `status` "pending device campaign"). Impact: FR-R02G2110-001; data model.
- Q: Where does the check run? → A: the existing `scripts/check_device_rows.py --experience r02-g21.binary-gardens`
  unchanged in its rules; `release_check.py` gains the step `device-rows-r02-g21`; `scripts/test_scripts.py` gains a
  test class that the real Binary Gardens definition passes (8 rows, 12 scenarios) and that removing a covered task, a
  row field or a scenario fails with a named reason. Impact: FR-R02G2110-004, 006; SC-R02G2110-001, 002.
- Q: What pass conditions do the rows use? → A: those of features 310 … 500: the app's proposed budgets where they exist
  (no shader compiled after interaction; 60 fps with automatic levels, 30 fps acceptable on the last level; memory flat
  over the stress session; 200 samples per device), otherwise "recorded" or a stated observation (sound audible, haptic
  felt, VoiceOver reads every control, progress kept, level 1 won with 3 of 3 stars). Every row stays "pending device
  campaign". Impact: FR-R02G2110-002; SC-R02G2110-004.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The device campaign knows exactly what to run for Binary Gardens (Priority: P1) 🎯

When the device lab starts after the lock, it finds a single, checked definition of Binary Gardens' device scenarios
and rows, so nothing is improvised on the devices and every earlier "after the lock" promise is measured.

**Why this priority**: without it the device campaign would have to guess what each earlier deferred promise means.

**Independent Test**: a check reads the definition and confirms every scenario exists in the experience's scenario set,
every row names its devices, procedure and pass condition, and every deferred device item of features 501–509 is
covered by a row.

**Acceptance Scenarios**:

1. **Given** the device row definition, **When** it is checked, **Then** every scenario it names exists in Binary
   Gardens' scenario manifest and every row has devices D1, D2, D3 (or a stated subset), a procedure, a pass condition
   and the status "pending device campaign".
2. **Given** the {device} tasks of features 501–509, **When** they are compared with the rows, **Then** each one is
   covered by at least one row.
3. **Given** the release check, **When** its steps are listed, **Then** it contains `device-rows-r02-g21` running the
   check for `r02-g21.binary-gardens`.

### User Story 2 - A person can follow the plan on the devices (Priority: P2)

The owner (who handles the devices) and the campaign script read the same plan: what to do, what the owner must do by
hand, what is measured and what counts as pass.

**Why this priority**: the plan is read by a person only once the campaign starts; the checked definition comes first.

**Independent Test**: the written plan lists each row with its owner steps and pass condition and claims no device
number.

**Acceptance Scenarios**:

1. **Given** the written plan, **When** a person reads any row, **Then** it states the devices in order, the owner
   steps, the procedure, what is measured and the pass condition, and no measured value.
2. **Given** the written plan and the definition, **When** their rows are compared, **Then** they have the same ids,
   titles, devices and gating (a lead review step recorded in the task, as for feature 500; the check reads only the
   definition).

### Edge Cases

- **No device numbers before the lock:** the plan and the definition contain no measured device value; every row is
  "pending device campaign"; a result field on a row fails the check.
- **D3's operating system:** the plan states D3 stays on iPadOS 26.5 and that a campaign finding another version is
  refused, not adapted.
- **Long measurements:** the 30-minute round-two stress session (UA-F13) runs only on devices; nothing here runs it.
- **A missing scenario:** a definition naming a scenario that the manifest lacks fails the check, naming it.
- **A missing or unreadable definition, a schema other than 1, or an unknown experience:** the check fails naming the
  file or the id; it never passes by default.
- **A prerequisite not yet recorded:** while any of features 505 … 509 is unrecorded, its {device} task may still
  change; this gate is recorded only after all five, so the coverage is read from their final task lists.
- **Owner-needed device states** (locked device, trust, signing, settings, charging): each row lists them as owner
  steps; the campaign records them as BLOCKED_OWNER_ACTION with the steps and never waits for input (UA-F13).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G2110-001**: A machine-readable definition MUST name Binary Gardens' device scenario set (scenarios from its
  manifest) and its device rows (id, title, devices, procedure, measurements, pass condition, gating, the earlier tasks
  it covers, owner steps, status pending).
- **FR-R02G2110-002**: A written plan MUST describe every row for a person: devices in order, owner steps, procedure,
  pass condition, and that no number is claimed before the campaign.
- **FR-R02G2110-003**: Every {device} task of features 501–509 and UA-F13's per-experience measurements (launch, first
  frame, frame pacing, memory, thermal state, the round-two stress session) MUST be covered by a row.
- **FR-R02G2110-004**: A check MUST validate the definition against the scenario manifest, the ledger's device rows of
  R02-G21 and the {device} tasks, and fail naming any mismatch.
- **FR-R02G2110-005**: No device MUST be contacted; existing tests MUST pass; the reference regression passes.
- **FR-R02G2110-006**: The release check MUST run the check for `r02-g21.binary-gardens` as its own step, and the script
  self-tests MUST prove the real definition passes and that each named defect fails.

### Key Entities

- **Device scenario set**: the manifest scenarios the campaign runs on each device.
- **Device row**: id (BG-D1 … BG-D8, clarification Q1), title, devices, procedure, measurements, pass condition,
  gating, covered tasks, owner steps, status.
- **Coverage**: the mapping from each deferred {device} task and UA-F13 measurement to its rows.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G2110-001**: The check passes and prints `device-rows r02-g21.binary-gardens: PASS (8 rows, 12 scenarios)`:
  every named scenario exists, every row is complete, all 6 {device} tasks of 501–509 and all 6 UA-F13 measurements are
  covered.
- **SC-R02G2110-002**: Removing a scenario from the manifest copy, a field from a row or a covered task from the
  definition each makes the check fail with a named reason (4 or more self-tests, each with its exact message).
- **SC-R02G2110-003**: No device is contacted; existing tests pass; the reference regression passes 7 of 7.
- **SC-R02G2110-004** {device}: after ImplementationLock-100, the rows are run by the device campaign on D1/D2/D3.

## Assumptions

- UA-F13's campaign script will read the definition; until it exists, the check and the written plan are the contract.
- Pass conditions use the experience's own budgets (frame pacing, memory) where a budget exists and otherwise "recorded"
  (a measurement taken and reported, not judged).
- Feature 500 (Mushroom Weather) is the model: the same definition schema, check and plan layout.
- The panel names the rows use are those of `BinaryGardensControls` plus the ones features 505 … 507 add as recorded;
  where a row names a control those features add (Dismiss tutorial, Hint, the modes, the level picker, Replay with Step
  and Stop, the Sound toggle), it is written from their recorded specifications.
- This feature adds no code, visuals or layout: the code-only graphics, their licensing and the iPhone and iPad layout
  stay those of features 503, 506 and 509; simulator proof of the game is features 508 and 509.

## Traceability

| Source item (round2.md R2-G21-10) | Requirement |
|---|---|
| Automation runner (device part) | UA-F13 (superseded here); FR-R02G2110-001 defines its input |
| Acceptance contract | FR-R02G2110-001, 002, 004, 006 |
| Do not launch a device | FR-R02G2110-005 |
| Deterministic tests, error handling | FR-R02G2110-004, 006; Edge Cases |
| Observability | the check's one line per problem and its PASS line; the plan's rows |
| Accessibility | the VoiceOver row (non-gating, P-08), FR-R02G2110-003 |
| Copyright/originality | no new visual or audio content; the experience is unchanged |
| Schema migration | none (no saved state changes) |
| Excluded scope | device contact, measured numbers, the campaign script (UA-F13), price, per-game app |
