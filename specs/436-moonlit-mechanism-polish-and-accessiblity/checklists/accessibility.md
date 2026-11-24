# Requirements Quality Checklist: R02-G14-06 polish and accessibility

**Purpose**: Unit tests for the requirements of feature 436 (player impact, deterministic invariants, empty and error
states, accessibility, licence and sound, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-24
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-24; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the announcement texts given word for word for a turn, re-seat, lamp step, undo, redo, win, failure,
  level change and every refusal code the adapter can return (with the engine's prefix read)? [Clarity, Spec
  §Clarifications Q1; FR-R02G1406-002]
- [x] CHK002 Is it stated whether a revealed hint, choosing a gear, showing a key frame, pending drag texts and orbit are
  announced, and how a gear drag's several turns are announced? [Coverage, Spec §Clarifications Q1; Edge Cases]
- [x] CHK003 Is the haptic for each outcome stated, including that a run and a budget-ending action play only the
  outcome and a drag's turns play one selection? [Completeness, Spec §Clarifications Q2]

## Deterministic invariants

- [x] CHK004 Is it stated that plans are pure functions of the old and new core and that no feedback, light or sound
  changes state or digest? [Consistency, Spec §FR-R02G1406-007; Clarifications Q1, Q3]
- [x] CHK005 Are the faded elements, their targets and durations, the clock they ease by and the flicker measure stated
  in numbers? [Measurability, Spec §Clarifications Q3; SC-R02G1406-003] — corrected 2026-11-24: the fades eased "in
  presentation time", which Reduce Motion holds at 0, so they would never finish there; they now ease by the frame
  clock's elapsed time.
- [x] CHK006 Do FR-004, User Story 2 and the clarification name the same treatment (glow and won brightening of the wall
  faded through `u_won` and the glow gain; the machine still between actions; player-changed elements not faded)?
  [Consistency, Spec §FR-R02G1406-004; US2; Clarifications Q3]

## Empty and error states

- [x] CHK007 Are VoiceOver off, sound off, an unavailable audio session, an aligned mesh and bursts of actions defined?
  [Coverage, Spec §Edge Cases]

## Accessibility

- [x] CHK008 Are the panel's labels, values, adjustable gear and key frame and summary element defined in words?
  [Completeness, Spec §FR-R02G1406-001; Clarifications Q5]
- [x] CHK009 Are Dynamic Type, Increase Contrast and the iPad width stated? [Coverage, Spec §FR-R02G1406-005;
  Clarifications Q5]

## Licence and sound

- [x] CHK010 Are the audition and ambient recipes stated functions (gear tones by teeth, detune by mesh error, the driver
  alone, decay; root by actions share, partials by covered quarters, stage changes, whole-cycle loop) with no recorded
  audio? [Clarity, Spec §Clarifications Q4; Assumptions]

## Simulator proof

- [x] CHK011 Are the host and simulator proofs stated (scripted plans exact, level 1 won through accessibility actions,
  Reduce Motion and Reduce Flashing frames identical, the sound state table)? [Measurability, Spec §SC-R02G1406-001 …
  004]

## Future D1/D2/D3 evidence

- [x] CHK012 Are sound, haptics and VoiceOver on hardware tagged `{device}` and deferred to after
  ImplementationLock-100? [Completeness, Spec §SC-R02G1406-006]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK005 failed at first reading; the spec, plan and research were corrected before the item was judged.
