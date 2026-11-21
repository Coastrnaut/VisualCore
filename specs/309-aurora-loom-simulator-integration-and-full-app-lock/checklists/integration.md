# Requirements Quality Checklist: R02-G01-09 simulator integration and full app lock

**Purpose**: Unit tests for the requirements of feature 309 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-20
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-20; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is the end-to-end journey a tester or player follows inside the app stated step by step (open, win, stars,
  next level, relaunch, replay)? [Completeness, Spec §US1]
- [x] CHK002 Is the finding that panel-only players could not win level 1 stated with its numbers and its resolution?
  [Clarity, Spec §Amendment; FR-R02G0109-008]
- [x] CHK003 Is it measurable that every level can be won with the panel alone in its certified shortest moves?
  [Measurability, Spec §SC-R02G0109-007]

## Deterministic invariants

- [x] CHK004 Is the order in which Apply commits pending changes defined (ribbon order, wave before phase)? [Clarity,
  Spec §FR-R02G0109-008]
- [x] CHK005 Are the stored migration examples defined exactly (fields, seed, expected restore)? [Completeness, Spec
  §Clarifications Q3; data-model]
- [x] CHK006 Is it stated that moves, stars and the allowance are unchanged by the pending-step design? [Consistency,
  Spec §Amendment]

## Empty and error states

- [x] CHK007 Are Apply's behaviours with nothing pending, past the allowance and after a win defined? [Edge Case, Spec
  §Edge Cases] (added during this review)
- [x] CHK008 Is the behaviour defined when the level, mode or play changes while steps are pending? [Edge Case, Spec
  §FR-R02G0109-008]
- [x] CHK009 Is the candidate's behaviour without the testing argument defined (not listed, not openable)? [Coverage,
  Spec §FR-R02G0109-006; Clarifications Q5]

## Source licence and code-only graphics

- [x] CHK010 Is it stated that nothing visual changes and no asset is added (identifiers and pending steps only)?
  [Consistency, Spec §Overrides; Plan §Constitution]
- [x] CHK011 Is the exclusion of test-only code from release builds stated with the symbols that prove it? [Clarity,
  Spec §Clarifications Q4]

## iPad/iPhone layout

- [x] CHK012 Are the layout constraints for the new Apply and Clear buttons stated (320-point iPhone, largest text,
  520-point iPad width)? [Coverage, Spec §Edge Cases] (added during this review)
- [x] CHK013 Is the announcement text for pending steps defined? [Clarity, Spec §Edge Cases] (added during this review)

## Simulator proof

- [x] CHK014 Are the interface tests, their launch arguments, chunk and 60-second bound defined? [Measurability, Spec
  §Clarifications Q2; SC-R02G0109-001]
- [x] CHK015 Are the debug and release builds and the symbol check named as evidence? [Completeness, Spec
  §FR-R02G0109-004; SC-R02G0109-003]
- [x] CHK016 Is the all-level solvability evidence named (feature 308's regression re-run)? [Traceability, Spec
  §FR-R02G0109-005]

## Future D1/D2/D3 evidence

- [x] CHK017 Are the device journeys deferred to ImplementationLock-100 as a {device} criterion? [Completeness, Spec
  §SC-R02G0109-006]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
