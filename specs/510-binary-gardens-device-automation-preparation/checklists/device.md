# Requirements Quality Checklist: R02-G21-10 device automation preparation

**Purpose**: Unit tests for the requirements of feature 510 (device rows, scenario set, definition, rows check, release
step, owner steps, no device contact)
**Created**: 2026-11-27
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-27, following feature 500's checklist, after the
items were generated in this skill invocation; failures were corrected in the artifacts.

## Rows and coverage

- [x] CHK001 Is every device row named with its id, title and the earlier tasks it covers (BG-D1 … BG-D8)?
  [Completeness, Spec §Clarifications Q1]
- [x] CHK002 Is every open {device} task of features 501–509 named and mapped to at least one row? [Coverage, Spec
  §User Story 1]
- [x] CHK003 Is the non-gating row (VoiceOver) identified with its reason? [Clarity, Spec §Clarifications Q1; P-08]
- [x] CHK004 Does the touch-feel row name every gesture of feature 504 (world inspect, star select, pip and dial taps,
  gauge tap and scrub, ring and phase drags with ghost previews, luminosity and tilt drags, double tap, orbit)?
  [Consistency, Spec §Clarifications Q1]
- [x] CHK005 Does each row quote the right player-facing text (the panel's win text for the journeys, 506's spoken
  announcements for sound and VoiceOver)? [Clarity, Spec §Clarifications Q1]

## Scenario set and definition

- [x] CHK006 Is the device scenario set listed by name, with the reason the other scenarios stay simulator-only?
  [Completeness, Spec §Clarifications Q2]
- [x] CHK007 Are the definition's location, schema and every row field defined, including the fixed status value?
  [Clarity, Spec §Clarifications Q3; Key Entities]
- [x] CHK008 Is the agreement between the written plan and the definition assigned to a named check or review step?
  [Measurability, Spec §User Story 2]

## Check and release step

- [x] CHK009 Are the check's failure cases defined with named reasons, and is the release step that runs it named?
  [Completeness, Spec §Clarifications Q4; FR-R02G2110-006]
- [x] CHK010 Is it measurable that removals make the check fail (four or more self-tests)? [Measurability, Spec
  §SC-R02G2110-002]
- [x] CHK011 Are pass conditions tied to stated budgets or to "recorded" or a stated observation? [Clarity, Spec
  §Clarifications Q5]

## Owner steps and device contact

- [x] CHK012 Are owner-only device steps listed per row and recorded as BLOCKED_OWNER_ACTION when needed? [Coverage,
  Spec §FR-R02G2110-004]
- [x] CHK013 Is it stated that no device is contacted and no device number is claimed before the campaign, and is D3's
  operating system rule (iPadOS 26.5, never updated) stated? [Scope, Spec §Canonical overrides; Edge Cases]
- [x] CHK014 Are the prerequisites (505 … 509 recorded) and the effect of a later change to their {device} tasks
  stated? [Dependency, Spec §Edge Cases; Assumptions]
- [x] CHK015 Is it stated that this feature adds no app code, visuals or layout? [Consistency, Spec §Negative
  Requirements]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK005 and CHK008 failed at first reading and were corrected in the spec: BG-D8 did not say which completion text it
  reads (the panel's, while 506 plans a spoken one), and the plan-to-definition agreement had no named check; it is now
  a lead review step, as for feature 500.
