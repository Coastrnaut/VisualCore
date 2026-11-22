# Requirements Quality Checklist: R02-G09-06 polish and accessibility

**Purpose**: Unit tests for the requirements of feature 386 (player impact, deterministic invariants, empty and error
states, accessibility, licence, layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-22
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-22; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the announcement texts given word for word for every move kind, undo, redo, win, failure, level change
  and refusal code? [Clarity, Spec §Clarifications Q1; FR-R02G0906-002]
- [x] CHK002 Is it stated whether a revealed hint is announced, so a VoiceOver player can hear it? [Coverage, Spec
  §Clarifications Q1] — corrected 2026-11-22: a revealed hint is announced as `state` with its text.
- [x] CHK003 Is the haptic for each outcome stated, including which one wins when a move also ends the play?
  [Completeness, Spec §Clarifications Q2]

## Deterministic invariants

- [x] CHK004 Is it stated that plans are pure functions of the old and new core and that no feedback, light or sound
  changes state or digest? [Consistency, Spec §FR-R02G0906-007; Clarifications Q1, Q3]
- [x] CHK005 Are the faded elements, their targets and durations, and the flicker measure stated in numbers? [Measurability,
  Spec §Clarifications Q3; SC-R02G0906-003]
- [x] CHK006 Does FR-004 name the same faded elements as the clarification (glow and leak crosses, not shadow cells)?
  [Consistency, Spec §FR-R02G0906-004]

## Empty and error states

- [x] CHK007 Are VoiceOver off, sound off, an unavailable audio session and bursts of actions defined? [Coverage, Spec
  §Edge Cases]

## Accessibility

- [x] CHK008 Are the panel's labels, values, adjustable pickers and summary element defined in words? [Completeness, Spec
  §FR-R02G0906-001; Clarifications Q5]
- [x] CHK009 Are Dynamic Type, Increase Contrast and the iPad width stated? [Coverage, Spec §FR-R02G0906-005;
  Clarifications Q5]

## Licence and sound

- [x] CHK010 Is the sound recipe a stated function (root by sun, partials by blooms, stage changes, whole-cycle loop)
  with no recorded audio? [Clarity, Spec §Clarifications Q4; Assumptions]

## Simulator proof

- [x] CHK011 Are the host and simulator proofs stated (scripted plans exact, level 1 won through accessibility actions,
  Reduce Motion frames identical, the loop's state table)? [Measurability, Spec §SC-R02G0906-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK012 Are sound, haptics and VoiceOver on hardware tagged `{device}` and deferred to after
  ImplementationLock-100? [Completeness, Spec §SC-R02G0906-006]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK002 failed at first reading; the spec's announcement clarification was corrected before the items were judged.
