# Requirements Quality Checklist: R02-G12-06 polish and accessibility

**Purpose**: Unit tests for the requirements of feature 416 (player impact, deterministic invariants, empty and error
states, accessibility, licence and sound, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-23
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-23; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the announcement texts given word for word for a tuning, undo, redo, win, failure, level change and
  every refusal code the adapter can return (with the engine's prefix read)? [Clarity, Spec §Clarifications Q1;
  FR-R02G1206-002]
- [x] CHK002 Is it stated whether a revealed hint, choosing a string, previewing a peg and orbit are announced?
  [Coverage, Spec §Clarifications Q1; Edge Cases]
- [x] CHK003 Is the haptic for each outcome stated, including that a test and a budget-ending tuning play only the
  outcome? [Completeness, Spec §Clarifications Q2]

## Deterministic invariants

- [x] CHK004 Is it stated that plans are pure functions of the old and new core and that no feedback, light or sound
  changes state or digest? [Consistency, Spec §FR-R02G1206-007; Clarifications Q1, Q3]
- [x] CHK005 Are the faded elements, their targets and durations, and the flicker measure stated in numbers?
  [Measurability, Spec §Clarifications Q3; SC-R02G1206-003]
- [x] CHK006 Do FR-004, User Story 2 and the clarification name the same treatment (glow, bridges and won brightening
  faded; under Reduce Flashing the step held, the strings at rest and no wave shells; player-changed elements not
  faded)? [Consistency, Spec §FR-R02G1206-004; US2; Clarifications Q3] — corrected 2026-11-23: FR-004 and User Story 2
  did not say that Reduce Flashing holds the shown step and rests the strings.
- [x] CHK007 Is the step cycle's rate stated against the 3-per-second limit, with the reason it is held under Reduce
  Flashing? [Measurability, Spec §Clarifications Q3; Research R3]

## Empty and error states

- [x] CHK008 Are VoiceOver off, sound off, an unavailable audio session, a string without modes and bursts of actions
  defined? [Coverage, Spec §Edge Cases]

## Accessibility

- [x] CHK009 Are the panel's labels, values, adjustable string and peg and summary element defined in words?
  [Completeness, Spec §FR-R02G1206-001; Clarifications Q5]
- [x] CHK010 Are Dynamic Type, Increase Contrast and the iPad width stated? [Coverage, Spec §FR-R02G1206-005;
  Clarifications Q5]

## Licence and sound

- [x] CHK011 Are the audition and ambient recipes stated functions (fundamental by peg, partials by resonant modes and
  tone strengths, decay; root by actions share, partials by steps reached, stage changes, whole-cycle loop) with no
  recorded audio? [Clarity, Spec §Clarifications Q4; Assumptions]

## Simulator proof

- [x] CHK012 Are the host and simulator proofs stated (scripted plans exact, level 1 won through accessibility actions,
  Reduce Motion and Reduce Flashing frames identical, no wave shell under Reduce Flashing, the sound state table)?
  [Measurability, Spec §SC-R02G1206-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK013 Are sound, haptics and VoiceOver on hardware tagged `{device}` and deferred to after
  ImplementationLock-100? [Completeness, Spec §SC-R02G1206-006]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK006 failed at first reading; the spec was corrected before the item was judged.
