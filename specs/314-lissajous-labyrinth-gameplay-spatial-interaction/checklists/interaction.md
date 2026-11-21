# Requirements Quality Checklist: R02-G02-04 spatial interaction

**Purpose**: Unit tests for the requirements of feature 314 (gesture-to-world mapping, arbitration, camera limits and
framing, selection, pending values and Apply order, panel accessibility, determinism and presentation-only state,
testability)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21; failures were corrected in the artifacts
(noted per item).

## Gesture-to-world mapping

- [x] CHK001 Are the ring positions, sizes and order stated numerically relative to a named reference? [Clarity, Spec
  §Clarifications Q1; Plan research R1, R2]
- [x] CHK002 Are the angle ↔ value mappings (step angles, rounding, clamping for frequencies, wrapping for phases) stated?
  [Clarity, Spec §Clarifications Q1; FR-R02G0204-002]
- [x] CHK003 Is the reference the rings are laid out against independent of the dials, so handles do not move while
  turning? [Consistency, Plan research R1] (added to the plan during this review)
- [x] CHK004 Is it stated how a turn past half a revolution is counted? [Edge Case, Plan research R3]
- [x] CHK005 Is the minimum touch radius given by reference to a defined source? [Clarity, Spec §FR-R02G0204-001]

## Arbitration

- [x] CHK006 Are the gesture states and every transition (second finger, cancel, lift) specified? [Completeness, Spec
  §Clarifications Q2; Plan research R5]
- [x] CHK007 Is it stated that one gesture sends at most one action and none when the value is unchanged? [Clarity, Spec
  §FR-R02G0204-002]
- [x] CHK008 Are paused, won, failed and refused cases covered with stated outcomes? [Coverage, Spec §SC-R02G0204-002]

## Camera limits and framing

- [x] CHK009 Are the orbit limits and drag rates stated numerically? [Clarity, Spec §Clarifications Q3]
- [x] CHK010 Does the framing requirement include the dial rings, not only the figure? [Consistency, Spec
  §FR-R02G0204-004, SC-R02G0204-003] (corrected during this review)
- [x] CHK011 Are the tested aspects enumerated? [Measurability, Spec §SC-R02G0204-003] (corrected during this review)
- [x] CHK012 Is the camera declared presentation only (not saved, not in the digest)? [Completeness, Spec §Clarifications Q3]

## Selection

- [x] CHK013 Are the initial selection, the outline and the description text specified? [Clarity, Spec §Clarifications Q4;
  FR-R02G0204-005]
- [x] CHK014 Is the single owner of the selection stated (gesture or stepper)? [Consistency, Plan research R8]

## Pending values and Apply

- [x] CHK015 Is the Apply order stated, including the frequency swap and the case where no order is coprime? [Clarity,
  Spec §FR-R02G0204-006; Plan research R7]
- [x] CHK016 Are the events that drop pending values enumerated? [Completeness, Spec §FR-R02G0204-006] (corrected during
  this review)
- [x] CHK017 Is the panel-only win criterion measurable over all 100 levels, and is its feasibility established? [Measurability,
  Spec §SC-R02G0204-004; Plan research R7]
- [x] CHK018 Is the behaviour on a refusal during Apply (announce, stop, drop the rest) stated? [Exception Flow, Spec
  §FR-R02G0204-006] (corrected during this review)

## Panel accessibility

- [x] CHK019 Are the announcement texts for pending values and the selection given? [Clarity, Spec §Clarifications Q4]
- [x] CHK020 Are accessibility labels and the visibility rule for Apply and Clear required? [Coverage, Spec
  §FR-R02G0204-006] (corrected during this review)
- [x] CHK021 Is the boundary with full accessibility (R02-G02-06) stated? [Scope, Spec §Assumptions]

## Determinism and testability

- [x] CHK022 Is gesture logic required to be testable without a screen, with scripted inputs and an independent oracle?
  [Measurability, Spec §FR-R02G0204-007; Clarifications Q5]
- [x] CHK023 Are pending values and gesture state excluded from the snapshot and the digest? [Consistency, Spec §Key
  Entities] (corrected during this review)
- [x] CHK024 Are device-only claims tagged and deferred to ImplementationLock-100? [Traceability, Spec §SC-R02G0204-007]
- [x] CHK025 Are test duration limits stated? [Non-Functional, Spec §SC-R02G0204-006]

## Notes

- `/speckit-implement` reads checklist state but does not modify markers.
