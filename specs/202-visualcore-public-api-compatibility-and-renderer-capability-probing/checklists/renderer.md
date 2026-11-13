# Requirements Quality Checklist: R02-F02 — renderer capability probing and API compatibility

**Purpose**: Unit tests for the requirements of R02-F02
**Created**: 2026-11-13
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement text adequate. Evaluated 2026-11-13 by the lead under the
owner's standing delegation; a failed item was corrected in the specification first and the correction is named.

## Completeness
- [x] CHK001 Is every value the source asks for (entry points, extensions, draw-buffer formats, MSAA, shader versions, instrumentation) mapped to a requirement or marked superseded? [Spec §FR-R02F02-001…006, Overrides]
- [x] CHK002 Are requirements defined for the context-recreation path, not only for creation? [Spec §FR-R02F02-003/004]
- [x] CHK003 Is the behaviour defined when a query fails? [Spec §FR-R02F02-002]
- [x] CHK004 Is the evidence placement of the report defined, including old evidence files? [Spec §FR-R02F02-006, Clarifications]
- [x] CHK005 Are the ES 3.0 minimum values the floor check uses written down? [Plan research R3]

## Clarity
- [x] CHK006 Is "absent" distinguished from zero for unreported values? [Spec §FR-R02F02-002]
- [x] CHK007 Is it clear that multisampling is reported, not enabled? [Spec §FR-R02F02-009]
- [x] CHK008 Is "compatible" defined measurably for the public API (added lines only, documented)? [Spec §FR-R02F02-008, SC-R02F02-005]

## Consistency
- [x] CHK009 Are the floor-check consequences consistent between the runner (record, not fail) and the success criteria? [Clarifications, SC-R02F02-001]
- [x] CHK010 Do the dependency rules allow the planned placement of the pure record and the mapping? [Clarifications, Plan]

## Acceptance criteria
- [x] CHK011 Does every success criterion carry a count? [Spec §SC-R02F02-001…005]
- [x] CHK012 Is the decoding of a pre-feature report a stated, testable criterion? [Spec §SC-R02F02-003]

## Scenarios and edge cases
- [x] CHK013 Are context loss during the query, unknown future fields, and below-minimum values addressed? [Spec §Edge Cases]
- [x] CHK014 Is the thread on which the query runs stated? [Spec §Edge Cases, Plan constitution III]

## Non-functional, boundaries, device split
- [x] CHK015 Is it stated which values are simulator values and that device values come from the device campaign? [Spec §Overrides, Assumptions]
- [x] CHK016 Is the content of the evidence record bounded so that no device identifier can enter it? [Spec §FR-R02F02-006] — failed first; corrected: the record holds strings and numbers only, never a device identifier.
- [x] CHK017 Is accessibility addressed (no UI; stated as not applicable)? [Spec §Edge Cases]
- [x] CHK018 Are the superseded source items (price range, Round 2 lock, R2-F01) listed with their replacement? [Spec §Overrides]
- [x] CHK019 Is the ADR-0002 boundary (no window MSAA or depth) stated? [Spec §FR-R02F02-009]

## Traceability
- [x] CHK020 Does each new report value name a consumer? [Spec §Assumptions]

## Notes
- `/speckit-implement` reads these markers and does not change them.
