# Release checklist (requirements quality): Interactive Anatomy — Phase 06

**Purpose**: unit tests for the requirements of privacy, credits, recovery, copy, the release checklist and the
interface tests (feature 129).
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it does not mean the work is done.
Evaluated by the lead under the owner's standing delegation on 2026-11-16. Failing items were corrected in the
artifacts before they were ticked.

## Completeness and Clarity

- [x] CHK001 Are the stored file, its deletion, "nothing is sent" and the full license inventory specified? [Spec §FR-A17-601, Q5]
- [x] CHK002 Are permission requests and usage-description strings addressed? [Spec §FR-A17-601; corrected: A17 adds none]
- [x] CHK003 Are the refused words listed exactly, with the allowed exceptions and their reasons? [Spec §Q2]
- [x] CHK004 Are the scanned APIs listed exactly? [Spec §Q3]
- [x] CHK005 Are the checklist statuses and their evidence rules specified? [Spec §Q1]

## Scenario Coverage

- [x] CHK006 Are recovery after a drawing failure and every stored view schema covered? [Spec §Story 2, Q5]
- [x] CHK007 Are the interface journeys named with their steps and limits? [Spec §Story 4, Q4]
- [x] CHK008 Is copy for features that may not show (labels skipped on a small canvas) addressed? [Spec §Edge Cases]

## Release and Ownership

- [x] CHK009 Are signing, archive, upload and the clinical review recorded as owner actions, never done here? [Spec §Overrides, Q1]
- [x] CHK010 Are device results excluded and deferred to the campaign rows? [Spec §Negative Requirements, Q1]
- [x] CHK011 Are the test time limits stated? [Spec §SC-A17-604]

## Notes

- `/speckit-implement` reads this checklist's state; it does not change the markers.
