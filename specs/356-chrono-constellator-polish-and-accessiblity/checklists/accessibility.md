# Requirements Quality Checklist: R02-G06-06 polish and accessibility

**Purpose**: Unit tests for the requirements of feature 356 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is every announcement text and kind stated for each accepted action, outcome, level change and refusal
  code? [Completeness, Spec §Clarifications Q1; FR-R02G0606-002]
- [x] CHK002 Is the haptic for each outcome stated, with the actions that play none? [Clarity, Spec §Clarifications Q2]

## Deterministic invariants

- [x] CHK003 Are announcement and haptic plans defined as pure functions of the old and new state (testable exactly)?
  [Measurability, Spec §Clarifications Q1]
- [x] CHK004 Is it stated that lights, sound and feedback never enter the state, digest or snapshot? [Consistency, Spec
  §FR-R02G0606-004, 007; Assumptions]
- [x] CHK005 Are the fade durations, the shimmer rate and amplitude, the glow cap and the flicker measure numeric?
  [Clarity, Spec §Clarifications Q3; SC-R02G0606-003]

## Empty and error states

- [x] CHK006 Are rate-limited bursts, previews, level-ending steps, VoiceOver off, an unavailable audio session and the
  sound choice off covered? [Coverage, Spec §Edge Cases]

## Source licence and code-only graphics

- [x] CHK007 Is the sound synthesized and all text original, with no assets? [Consistency, Spec §Assumptions]

## iPad/iPhone layout

- [x] CHK008 Are the largest text size on the smallest iPhone and the iPad's readable width covered? [Coverage, Spec
  §Edge Cases; Clarifications Q5]

## Simulator proof

- [x] CHK009 Are the recorded-sink, flicker-sampling and loop state-table proofs and the accessibility-action playthrough
  required? [Measurability, Spec §SC-R02G0606-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK010 Are hearing the sound, feeling haptics and using VoiceOver on hardware deferred to D1–D3 after
  ImplementationLock-100? [Completeness, Spec §Canonical overrides; Assumptions]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
