# Requirements Quality Checklist: Graphics Benchmark Lab — Phase 06 release

**Purpose**: Unit tests for the Phase 06 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md), [plan.md](../plan.md), [data-model.md](../data-model.md),
[contracts/release.md](../contracts/release.md)

`[x]` means the reviewer judged the requirement's writing satisfactory (evaluated by the lead under the owner's
standing delegation, 2026-11-19); it does not mean the work is done.

## Requirement Completeness

- [x] CHK001 Are all stored data kinds (snapshot, saved results, index, export files), their place and their removal listed? [Completeness, Spec §FR-A24-601, Clarifications]
- [x] CHK002 Are the refused source APIs enumerated, with the one allowed place of the share sheet? [Completeness, Spec §FR-A24-602, Clarifications]
- [x] CHK003 Are the refused copy words and the required "does not rank devices" phrase enumerated? [Completeness, Spec §FR-A24-605, Clarifications]
- [x] CHK004 Are the sample files and each expected outcome listed? [Completeness, data-model]
- [x] CHK005 Is accessibility's release status defined, with audits deferred to the device campaign? [Completeness, Spec §FR-A24-606]

## Requirement Clarity and Consistency

- [x] CHK006 Are the checklist statuses defined with what evidence each needs? [Clarity, Clarifications]
- [x] CHK007 Is the recovery seam defined as test-only, once, self-clearing? [Clarity, data-model]
- [x] CHK008 Is the copy consistent with the shared denylist ("share" allowed for the real export) and with the experience's real limits (three cases, 12 results, GPU time only where the timer exists, a hot device ends a run)? [Consistency, Spec §FR-A24-606, Clarifications]
- [x] CHK009 Is the explanation's exclusion from the claims scan justified, and is it still covered by another check? [Consistency, Clarifications, research R2]

## Scenario and Edge Case Coverage

- [x] CHK010 Are damaged index, newer schema and oversized file cases covered? [Edge Case, Spec §Edge Cases, data-model]
- [x] CHK011 Is the first-session journey defined with exact identifiers? [Coverage, Spec §US4, Clarifications]
- [x] CHK012 Is the fate of export files left by a killed session specified? [Edge Case, Spec §Edge Cases]

## Non-Functional, Architecture and Lifecycle

- [x] CHK013 Is privacy proved by a page and a scan, not by assertion, including the device facts' public sources? [Privacy, Spec §FR-A24-601, 602]
- [x] CHK014 Is ownership unchanged (no VisualCore change, the seam internal to the experience)? [Architecture, plan]
- [x] CHK015 Are owner-only steps (signing, archive, upload) kept as owner actions? [Release, Spec §Canonical overrides]
- [x] CHK016 Are test durations bounded and no measured performance, ranking or benchmark number claimed? [Performance, Spec §SC-A24-604, Negative Requirements]
- [x] CHK017 Are device rows kept pending and named by their campaign ids? [Release, Spec §FR-A24-606]

## Notes

- All items passed on evaluation; CHK009 and CHK012 were added for this experience's share sheet and explanation.
- `/speckit-implement` reads checklist state; it does not change the markers.
