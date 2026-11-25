# Requirements Quality Checklist: R02-G17-06 polish and accessibility

**Purpose**: Unit tests for the requirements of feature 466 (player impact, deterministic invariants, empty and error
states, accessibility, licence and sound, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-25
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-25; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the announcement texts given word for word for a phase change, undo, redo, won run, failed run, level
  change and every refusal code the adapter can return (with the engine's prefix read, and a fallback text for the
  codes that cannot arise from the panel)? [Clarity, Spec §Clarifications Q1; FR-R02G1706-002]
- [x] CHK002 Is it stated whether a revealed hint, choosing a body, pending phase texts, the shown tick and orbit are
  announced? [Coverage, Spec §Clarifications Q1; Edge Cases]
- [x] CHK003 Is the haptic for each outcome stated, including that the run (which always ends the level) plays only its
  outcome and that a phase change never ends the level? [Completeness, Spec §Clarifications Q2]

## Deterministic invariants

- [x] CHK004 Is it stated that plans are pure functions of the old and new core and that no feedback, light or sound
  changes state or digest? [Consistency, Spec §FR-R02G1706-007; Clarifications Q1, Q3]
- [x] CHK005 Are the faded elements, their targets and durations, the clock they ease by (the frame clock, so fades
  finish under Reduce Motion) and the flicker measure stated in numbers? [Measurability, Spec §Clarifications Q3;
  SC-R02G1706-003]
- [x] CHK006 Do FR-004, User Story 2 and the clarification name the same treatment (glow and won look faded through
  `u_won`, the glow gain and the fallback's won level; the halo pulse held under Reduce Motion and Reduce Flashing so
  the sky is still between actions; player-changed elements not faded)? [Consistency, Spec §FR-R02G1706-004; US2;
  Clarifications Q3]

## Empty and error states

- [x] CHK007 Are VoiceOver off, sound off, an unavailable audio session, an uninvolved body's audition and bursts of
  actions defined? [Coverage, Spec §Edge Cases; Clarifications Q4]

## Accessibility

- [x] CHK008 Are the panel's labels, values, adjustable chosen body and pending phase and the summary element defined in
  words? [Completeness, Spec §FR-R02G1706-001; Clarifications Q5]
- [x] CHK009 Are Dynamic Type, Increase Contrast and the iPad width stated? [Coverage, Spec §FR-R02G1706-005;
  Clarifications Q5]

## Licence and sound

- [x] CHK010 Are the audition and ambient recipes stated functions (body tones by index a whole tone apart, the fifth
  or a 3 Hz beat, decay; root by actions share, partials by quarters of the target matched, stage changes, whole-cycle
  loop) with no recorded audio? [Clarity, Spec §Clarifications Q4; Assumptions]

## Simulator proof

- [x] CHK011 Are the host and simulator proofs stated (scripted plans exact, level 1 won through accessibility actions,
  Reduce Motion and Reduce Flashing frames identical, the sound state table)? [Measurability, Spec §SC-R02G1706-001 …
  004]

## Future D1/D2/D3 evidence

- [x] CHK012 Are sound, haptics and VoiceOver on hardware tagged `{device}` and deferred to after
  ImplementationLock-100? [Completeness, Spec §SC-R02G1706-006]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- Every item passed at first reading; the run ending every level simplified CHK003, and Reduce Flashing holding the
  halo pulse (research R3) was settled in the clarification so FR-004 and User Story 2 agree.
