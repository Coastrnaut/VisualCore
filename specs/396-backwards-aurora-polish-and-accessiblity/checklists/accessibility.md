# Requirements Quality Checklist: R02-G10-06 polish and accessibility

**Purpose**: Unit tests for the requirements of feature 396 (player impact, deterministic invariants, empty and error
states, accessibility, licence, layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-23
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-23, following feature 386's checklist.

## Player impact

- [x] CHK001 Are the announcement texts given word for word for a reversal, undo, redo, win, failure, level change and
  every refusal code the adapter can return? [Clarity, Spec §Clarifications Q1; FR-R02G1006-002]
- [x] CHK002 Is it stated whether a revealed hint and the freeze preview are announced? [Coverage, Spec
  §Clarifications Q1; Edge Cases]
- [x] CHK003 Is the haptic for each outcome stated, including which one wins when a reversal also ends the play?
  [Completeness, Spec §Clarifications Q2]

## Deterministic invariants

- [x] CHK004 Is it stated that plans are pure functions of the old and new core and that no feedback, light or sound
  changes state or digest? [Consistency, Spec §FR-R02G1006-007; Clarifications Q1, Q3]
- [x] CHK005 Are the faded elements, their targets and durations, and the flicker measure stated in numbers?
  [Measurability, Spec §Clarifications Q3; SC-R02G1006-003]
- [x] CHK006 Does FR-004 name the same faded elements as the clarification (glow, won lift, tear cross and preview, not
  kink crosses)? [Consistency, Spec §FR-R02G1006-004]
- [x] CHK007 Are the periodic motion rates (shimmer, pulses) stated against the 3-per-second limit? [Measurability, Spec
  §Clarifications Q3]

## Empty and error states

- [x] CHK008 Are VoiceOver off, sound off, an unavailable audio session and bursts of actions defined? [Coverage, Spec
  §Edge Cases]

## Accessibility

- [x] CHK009 Are the panel's labels, values, adjustable section ends and summary element defined in words? [Completeness,
  Spec §FR-R02G1006-001; Clarifications Q5]
- [x] CHK010 Are Dynamic Type, Increase Contrast and the iPad width stated? [Coverage, Spec §FR-R02G1006-005;
  Clarifications Q5]

## Licence and sound

- [x] CHK011 Is the sound recipe a stated function (root by worst bend, partials by matched checkpoints, stage changes,
  whole-cycle loop) with no recorded audio? [Clarity, Spec §Clarifications Q4; Assumptions]

## Simulator proof

- [x] CHK012 Are the host and simulator proofs stated (scripted plans exact, level 1 won through accessibility actions,
  Reduce Motion frames identical, the loop's state table)? [Measurability, Spec §SC-R02G1006-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK013 Are sound, haptics and VoiceOver on hardware tagged `{device}` and deferred to after
  ImplementationLock-100? [Completeness, Spec §SC-R02G1006-006]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- Every item passed at first reading.
