# Requirements Quality Checklist: R02-G08-06 polish and accessibility

**Purpose**: Unit tests for the requirements of feature 376 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-22
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-22.

## Player impact

- [x] CHK001 Is every announcement given word for word with its kind, including the unannounced preview choices and
  every refusal code? [Clarity, Spec §Clarifications Q1]
- [x] CHK002 Is the haptic for every action, and the outcome-over-selection rule for a cut that ends the play, stated?
  [Completeness, Spec §Clarifications Q2]

## Deterministic invariants

- [x] CHK003 Are announcement texts defined as a pure function of the old and new core, so tests can compare them
  exactly? [Measurability, Spec §Clarifications Q1]
- [x] CHK004 Is it stated that lights, sound and feedback never change the state, digest or snapshot? [Consistency, Spec
  §FR-R02G0806-004, 007; Assumptions]

## Empty and error states

- [x] CHK005 Are VoiceOver off, haptics off, sound off, an unavailable audio session and rate-limited bursts covered?
  [Coverage, Spec §Edge Cases]

## Reduce Flashing and Reduce Motion

- [x] CHK006 Are fade durations (0.15 s / 0.45 s), the no-reversal rule, the 3-per-second bound and the measuring method
  stated numerically? [Measurability, Spec §Clarifications Q3; SC-R02G0806-003]
- [x] CHK007 Is the dispersion shimmer rate stated below 3 cycles per second and still under Reduce Motion? [Clarity, Spec
  §Clarifications Q3]

## Source licence and code-only audio

- [x] CHK008 Is the sound recipe given numerically (root, ratios per piece, octave, halved gains, loop
  length) and synthesized,
  with no recorded audio? [Completeness, Spec §Clarifications Q4; Negative Requirements]

## iPad/iPhone layout

- [x] CHK009 Are Dynamic Type up to the largest accessibility size, wrapping rows, scrolling and the iPad readable width
  (520 points) stated? [Coverage, Spec §Clarifications Q5; FR-R02G0806-005]

## Simulator proof

- [x] CHK010 Are the recorded-sink proofs (announcements, haptics), the Reduce Motion frame comparison and the loop's
  state table stated as simulator or host checks? [Measurability, Spec §SC-R02G0806-001 … 004; Quickstart]

## Future D1/D2/D3 evidence

- [x] CHK011 Are listening, feeling and VoiceOver use on hardware tagged `{device}` and deferred to after
  ImplementationLock-100? [Completeness, Spec §SC-R02G0806-006]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- No item failed at first reading.
