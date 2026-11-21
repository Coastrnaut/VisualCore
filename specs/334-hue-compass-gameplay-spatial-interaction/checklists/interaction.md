# Requirements Quality Checklist: R02-G04-04 gameplay spatial interaction

**Purpose**: Unit tests for the requirements of feature 334 (swipe-to-turn mapping, hub tap, arbitration, orbit, preview,
panel parity, accessibility, testability, device items)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21; failures were corrected in the artifacts.

## Gestures

- [x] CHK001 Is the swipe's turn defined exactly (centre, angle convention, accumulation, rounding, wrapping, zero)?
  [Clarity, Spec §Clarifications Q1]
- [x] CHK002 Is the dead zone's effect on a swipe that passes through or ends in the centre defined? [Edge Case, Spec
  §Edge Cases] — corrected: dead-zone points add no angle and the gathered angle stands.
- [x] CHK003 Are the tap distance, hub size and the double-tap reset area quantified? [Clarity, Spec §Clarifications Q2]
- [x] CHK004 Is every arbitration case (second finger, cancel, not playing, tap outside the hub) given an outcome?
  [Coverage, Spec §Edge Cases; Q2]

## Camera and preview

- [x] CHK005 Are orbit limits, rates and reset defined, and is the orbit kept out of the digest and snapshot? [Clarity,
  Spec §Clarifications Q3; FR-R02G0404-004]
- [x] CHK006 Is the preview's appearance and description defined, and is it clear the real needle moves only when the
  turn is accepted? [Completeness, Spec §Clarifications Q4]

## Accessibility and parity

- [x] CHK007 Is every gesture's effect reachable from labelled panel controls, with the mapping of a turn to panel presses
  stated? [Coverage, Spec §FR-R02G0404-005; Q4]
- [x] CHK008 Is the choice to keep selection in the panel stated with its reason? [Assumption, Spec §Assumptions]

## Verification and device

- [x] CHK009 Are the swipe test's sample sizes, seeds and independent computation stated? [Measurability, Spec
  §SC-R02G0404-001; Q5]
- [x] CHK010 Is the 100-level panel win stated as a measurable criterion? [Measurability, Spec §SC-R02G0404-004]
- [x] CHK011 Are touch feel and latency separated as {device} after ImplementationLock-100? [Scope, Spec
  §SC-R02G0404-006]

## Notes

- `/speckit-implement` reads these markers and does not change them.
