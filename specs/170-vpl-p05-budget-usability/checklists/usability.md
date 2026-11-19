# Budget and Usability Requirements Checklist: Visual Programming Lab — Phase 05

**Purpose**: Unit tests for the requirements of A23-P05 (completeness, privacy, architecture ownership, lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md)

`[x]` means the reviewer (the lead, under the owner's standing delegation) found the requirement-quality criterion
satisfied; it does not mean the work is done.

## Requirement Completeness

- [x] CHK001 Is a stress cycle defined step by step, with the cycle count and the warm-up rule? [Completeness, Spec §Clarifications Q1, FR-A23-501]
- [x] CHK002 Are the pass counts stated for each fixture graph? [Completeness, Spec §Clarifications Q2, SC-A23-502]
- [x] CHK003 Are all five preview states named for the rebuild requirement? [Completeness, Spec §Clarifications Q3, FR-A23-503]
- [x] CHK004 Are the device rows named per device, with the pending state? [Completeness, Spec §Clarifications Q5, FR-A23-505]

## Requirement Clarity

- [x] CHK005 Is "no growth" defined by a measurable level (live objects per kind and bytes) and a zero leak count? [Clarity, Spec §SC-A23-501]
- [x] CHK006 Is the interface journey specified with its identifiers and launch options? [Clarity, Spec §Clarifications Q4, contracts/tests.md]
- [x] CHK007 Is it stated why a mismatched choice is possible in the list form and what happens? [Clarity, Spec §Clarifications Q4 (corrected)]

## Requirement Consistency

- [x] CHK008 Do the pass counts agree with the compiler of A23-P03 (values add no pass, Blur two)? [Consistency, Spec §Clarifications Q2]
- [x] CHK009 Is the device-plan gap closing as a plan consistent with the A22-P05 precedent and the device guard? [Consistency, Spec §Clarifications Q5, Canonical overrides]

## Acceptance Criteria Quality

- [x] CHK010 Are the success criteria countable (50 cycles, 2 and 6 passes, 10 × 5 rebuilds, 60 s per interface test)? [Measurability, Spec §SC-A23-501–506]

## Architecture Ownership and Lifecycle

- [x] CHK011 Are rebuilds required to go through the host, with a pending compile happening once after? [Coverage, Spec §Clarifications Q3, Edge Cases]
- [x] CHK012 Is it stated that fixes stay inside the experience, with no VisualCore change? [Dependency, plan Project Structure, Negative Requirements]

## Privacy, Performance and Release

- [x] CHK013 Is the absence of any device figure, audit run or network stated? [Coverage, Spec §Negative Requirements]
- [x] CHK014 Are long or soak runs excluded (short cycles only)? [Non-Functional, Spec §SC-A23-501, owner rule]
- [x] CHK015 Is the relaunch journey's dependence on atomic writes stated? [Coverage, Spec §Edge Cases]
- [x] CHK016 Is the candidate (not available) status kept? [Coverage, Spec §Canonical overrides]

## Notes

- One correction during evaluation: clarification Q4 now says the list form offers every other node's outputs, so a
  mismatched choice is possible and refused like a drag.
