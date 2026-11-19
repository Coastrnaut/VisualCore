# Requirements Quality Checklist: Effects Composer — Phase 05 colour, export and robustness

**Purpose**: Unit tests for the requirements of feature 184 (completeness, privacy, ownership, lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-19; failures were corrected in the artifacts
(noted per item).

## Requirement Completeness

- [x] CHK001 Are the export formats, size and quality all stated? [Completeness, Spec §FR-A25-501, Clarification Q2]
- [x] CHK002 Is every export refusal and failure named with a code and message? [Completeness, data-model ExportRefusal]
- [x] CHK003 Is the colour domain of every one of the five effects stated? [Completeness, Clarification Q1]
- [x] CHK004 Are the intermediate formats for both precision paths and for source and result stated? [Completeness, Spec §FR-A25-504]
- [x] CHK005 Is the device measurement plan's content defined (what, where, limits)? [Completeness, Clarification Q5]

## Requirement Clarity

- [x] CHK006 Is "matches the preview" quantified per format? [Clarity, Spec §SC-A25-501]
- [x] CHK007 Is "linear light" made testable with numeric expectations (ramp, mid-grey, edge 188 ± 3)? [Clarity, Spec §SC-A25-503]
- [x] CHK008 Are the export limits defined by a stated rule rather than "too large"? [Clarity, Clarification Q2]
- [x] CHK009 Is the grade formula's pivot in linear light stated? [Clarity, research R2, contracts/color.md]

## Requirement Consistency

- [x] CHK010 Are the export size limit and the import limit consistent (both min(texture limit, 2,048))? [Consistency, Spec §Clarifications]
- [x] CHK011 Do the pool cap and the targets an export needs agree? [Consistency, plan Technical Context: cap raised to 5]
- [x] CHK012 Is "the chain document is unchanged" consistent with fixed per-effect colour domains? [Consistency, data-model ColorDomain]

## Acceptance Criteria Quality

- [x] CHK013 Is every functional requirement traced to a success criterion or acceptance scenario? [Traceability, Spec §Traceability]
- [x] CHK014 Are test durations bounded (unit < 10 s, journey < 60 s)? [Measurability, Spec §SC-A25-505]

## Scenario Coverage

- [x] CHK015 Are recovery requirements defined for a context loss during editing and during export? [Recovery, Spec §US3]
- [x] CHK016 Are requirements defined for a repeated export request and for a second export's file handling? [Alternate, Spec §FR-A25-508]
- [x] CHK017 Is behaviour defined when the app goes to the background during an export? [Gap → corrected: Spec §Edge Cases]

## Edge Case Coverage

- [x] CHK018 Are empty-chain, test-picture and import-in-progress exports addressed? [Edge Case, Spec §Edge Cases]
- [x] CHK019 Is the case of a restored session with an earlier export addressed? [Gap → corrected: Spec §Edge Cases]

## Non-Functional Requirements

- [x] CHK020 Is privacy stated: only the share sheet the person opens, no library permission, temporary files removed? [Privacy, Spec §Canonical overrides, §Negative Requirements]
- [x] CHK021 Is graphics-context ownership stated for export as for preview? [Ownership, plan Lifecycle, Constitution III]
- [x] CHK022 Is peak memory bounded by arithmetic and are device timings deferred to {device} rows? [Performance, plan Technical Context]
- [x] CHK023 Are accessibility labels stated for every new control? [Accessibility, contracts/export.md]

## Dependencies & Assumptions

- [x] CHK024 Are all VisualCore APIs used listed and verified in code? [Dependency, plan Technical Context, Clarification facts]
- [x] CHK025 Is the assumption that the preview is drawn at full size recorded with its consequence for export? [Assumption, Spec §Assumptions]

## Release Constraints

- [x] CHK026 Is it stated that release work (G-RELEASE) is A25-P06 and that no device run happens before ImplementationLock-100? [Scope, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
