# Review and device QA checklist: Interactive Anatomy — Phase 05

**Purpose**: unit tests for the requirements of the review record, the review lines, the list-only fixture and the
device campaign (feature 128).
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it does not mean the work is done.
Evaluated by the lead under the owner's standing delegation on 2026-11-16. Failing items were corrected in the
artifacts before they were ticked.

## Requirement Completeness and Clarity

- [x] CHK001 Are the record's location, envelope, fields and content-version binding specified? [Spec §FR-A17-501, Q1]
- [x] CHK002 Is every refusal of the record named with its reason? [Spec §FR-A17-502, Q2]
- [x] CHK003 Are the exact review lines and the model statement given as text? [Spec §FR-A17-503, 504, Q3]
- [x] CHK004 Is the boundary between editorial (engineer) and clinical (owner) review stated so no clinical claim can be made by the engineer? [Spec §Overrides, Q2, Negative Requirements]

## Scenario and Edge Case Coverage

- [x] CHK005 Is the behaviour stated when the bundled record fails validation? [Spec §Edge Cases; corrected: degrade to the not-reviewed label]
- [x] CHK006 Are a later clinical entry and a record of another content version covered? [Spec §Edge Cases]
- [x] CHK007 Is the list-only path defined so that it needs no pointer event, and compared with a tap selection? [Spec §FR-A17-505, Q5]

## Release and Device QA

- [x] CHK008 Does the device campaign name each {device} check with a pass criterion and device class? [Spec §FR-A17-507, Q5]
- [x] CHK009 Is the generated review document's failing check specified? [Spec §FR-A17-506, Q4]
- [x] CHK010 Are the test limits stated, and are device runs and audits excluded from this phase? [Spec §SC-A17-504, Negative Requirements]

## Notes

- `/speckit-implement` reads this checklist's state; it does not change the markers.
