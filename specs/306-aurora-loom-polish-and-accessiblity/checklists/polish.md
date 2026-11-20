# Requirements Quality Checklist: R02-G01-06 polish and accessibility

**Purpose**: Unit tests for the requirements of feature 306 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-20
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-20; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is it stated what a VoiceOver player hears after every kind of action (move, undo, redo, win, failure, level
  change, refusal), with exact texts? [Completeness, Spec §FR-R02G0106-002; Clarifications Q1]
- [x] CHK002 Is every native control named with the label and value it must expose? [Completeness, Spec
  §FR-R02G0106-001; Clarifications Q5]

## Deterministic invariants

- [x] CHK003 Is it required that feedback, lights and sound never change the state, its digest or the snapshot?
  [Consistency, Spec §FR-R02G0106-003, 004, 007; Assumptions]
- [x] CHK004 Are the fade durations and the flash-rate limit quantified? [Clarity, Spec §SC-R02G0106-003;
  Clarifications Q3]
- [x] CHK005 Is the ambient recipe defined as a pure function of named inputs, and when it is rebuilt? [Clarity, Spec
  §SC-R02G0106-004; Clarifications Q4]

## Empty and error states

- [x] CHK006 Are VoiceOver off, the haptics switch off, the sound choice off, an unavailable or interrupted audio
  session and bursts of actions each given an outcome? [Coverage, Spec §Edge Cases]
- [x] CHK007 Is the precedence between a move's selection haptic and a win or failure defined? [Edge Case, Spec
  §Clarifications Q2]

## Source licence and code-only graphics

- [x] CHK008 Is it stated that all texts are original, the sound is synthesized and no assets are added? [Consistency,
  Spec §Assumptions]

## iPad/iPhone layout and accessibility

- [x] CHK009 Are the largest Dynamic Type size, scrolling instead of clipping, Increase Contrast and the iPad panel width
  specified? [Completeness, Spec §FR-R02G0106-005; Clarifications Q5]

## Simulator proof

- [x] CHK010 Are the simulator proofs named (recorded announcements and haptics, labels and values, largest text size,
  sound state table) separately from device observations? [Measurability, plan Testing; quickstart]

## Future D1/D2/D3 evidence

- [x] CHK011 Are the device-only observations (hearing the loop, feeling haptics, VoiceOver on hardware) listed and
  deferred to ImplementationLock-100? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
