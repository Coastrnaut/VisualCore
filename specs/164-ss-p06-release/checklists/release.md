# Requirements Quality Checklist: Shader Studio — Phase 06 release

**Purpose**: Unit tests for the Phase 06 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-18
**Feature**: [spec.md](../spec.md), [plan.md](../plan.md), [data-model.md](../data-model.md),
[contracts/release.md](../contracts/release.md)

`[x]` means the reviewer judged the requirement's writing satisfactory (evaluated by the lead under the owner's
standing delegation, 2026-11-18); it does not mean the work is done.

## Requirement Completeness

- [x] CHK001 Are all stored data kinds, their place and their removal listed? [Completeness, Spec §FR-A22-601, Clarifications]
- [x] CHK002 Are the refused source APIs enumerated? [Completeness, Spec §FR-A22-602, Clarifications]
- [x] CHK003 Are the refused copy words and the required "not a sandbox" phrase enumerated? [Completeness, Spec §FR-A22-605, Clarifications]
- [x] CHK004 Are the sample files and each expected outcome listed? [Completeness, data-model]
- [x] CHK005 Is accessibility's release status defined, with audits deferred to the device campaign? [Completeness, Spec §FR-A22-606]

## Requirement Clarity and Consistency

- [x] CHK006 Are the checklist statuses defined with what evidence each needs? [Clarity, Clarifications]
- [x] CHK007 Is the recovery seam defined as test-only, once, self-clearing? [Clarity, data-model]
- [x] CHK008 Is the copy consistent with the constitution's A22 no-sandbox rule and with the shared denylist? [Consistency, Clarifications]

## Scenario and Edge Case Coverage

- [x] CHK009 Are damaged index, newer schema and oversized file cases covered? [Edge Case, Spec §Edge Cases, data-model]
- [x] CHK010 Is the first-session journey defined with exact identifiers? [Coverage, Spec §US4, Clarifications]

## Non-Functional, Architecture and Lifecycle

- [x] CHK011 Is privacy proved by a page and a scan, not by assertion? [Privacy, Spec §FR-A22-601, 602]
- [x] CHK012 Is ownership unchanged (no VisualCore change, the seam internal to the experience)? [Architecture, plan]
- [x] CHK013 Are owner-only steps (signing, archive, upload) kept as owner actions? [Release, Spec §Canonical overrides]
- [x] CHK014 Are test durations bounded and no measured performance claimed? [Performance, Spec §SC-A22-604, Negative Requirements]
- [x] CHK015 Are device rows kept pending and named by their campaign ids? [Release, Spec §FR-A22-606]

## Notes

- CHK005 failed at first; the accessibility status (verified automated evidence, audits `pending-campaign-ii`) was added
  to FR-A22-606 before marking.
- `/speckit-implement` reads checklist state; it does not change the markers.
