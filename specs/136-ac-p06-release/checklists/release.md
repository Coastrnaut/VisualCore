# Release checklist (requirements quality): Ambient Clock — Phase 06

**Purpose**: unit tests for the requirements of privacy, credits, the source scan, recovery, stored samples, copy,
the release checklist and the interface journey (feature 136).
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it does not mean the work is done.
Evaluated by the lead under the owner's standing delegation on 2026-11-16. Failing items were corrected in the
artifacts before they were ticked.

## Completeness and Clarity

- [x] CHK001 Are the stored data (settings snapshot, `favourites.json`), their place and removal, "nothing is sent" and the license inventory specified? [Spec §FR-A18-601]
- [x] CHK002 Are permission requests and usage-description strings addressed? [Spec §FR-A18-601, Negative Requirements: none is asked]
- [x] CHK003 Is the keep-awake rule (opt-in, one named file) specified for both the page and the scan? [Spec §FR-A18-601, FR-A18-602, Q3]
- [x] CHK004 Are the refused words listed exactly, with whole-word, case-insensitive matching and the scanned files? [Spec §Q2]
- [x] CHK005 Are the scanned APIs listed exactly, including the brightness write? [Spec §Q3]
- [x] CHK006 Are the checklist statuses and their evidence rules specified? [Spec §Q1]

## Scenario Coverage

- [x] CHK007 Is recovery after a drawing failure specified with the file that must stay unchanged and the reopened state? [Spec §Story 2, Q4]
- [x] CHK008 Are every stored snapshot schema (1, 2, 3, newer, damaged) and every favourites case (current, newer, damaged) covered? [Spec §Q4]
- [x] CHK009 Is the interface journey named with its steps and time limit? [Spec §Story 4, Q5, SC-A18-604]
- [x] CHK010 Is copy that would imply the screen always stays on addressed? [Spec §Edge Cases]

## Non-Functional (performance, heat, accessibility)

- [x] CHK011 Are performance, heat and accessibility results specified as device rows, never claimed from the simulator? [Spec §FR-A18-606; corrected: the AC-D rows are named]
- [x] CHK012 Are measured-performance claims excluded from the copy? [Spec §Negative Requirements, Q2]

## Release and Ownership

- [x] CHK013 Are signing, archive and upload recorded as owner actions with their steps, never done here? [Spec §Overrides, Q1]
- [x] CHK014 Is the gap closed by this phase (G-RELEASE) named with its parts? [Spec §Overrides]
- [x] CHK015 Are the test time limits stated? [Spec §SC-A18-604]

## Notes

- `/speckit-implement` reads this checklist's state; it does not change the markers.
