# Release checklist (requirements quality): Living Wallpapers — Phase 06

**Purpose**: unit tests for the requirements of privacy, credits, the source scan, recovery, stored samples, copy,
the release checklist and the interface journey (feature 143).
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it does not mean the work is done.
Evaluated by the lead under the owner's standing delegation on 2026-11-17. Failing items were corrected in the
artifacts before they were ticked.

## Completeness and Clarity

- [x] CHK001 Are the stored data (session snapshot, `history.json`), their place and removal, "nothing is sent" and the license inventory specified? [Spec §FR-A19-601]
- [x] CHK002 Is the lifetime of the temporary export file specified? [Spec §FR-A19-601; corrected: at most one, replaced by the next export]
- [x] CHK003 Are the permission request and its usage string addressed, including who asks and when? [Spec §FR-A19-601, Story 1: the system share sheet's Save Image]
- [x] CHK004 Are the refused words listed exactly, with whole-word, case-insensitive matching, the scanned files and the one allowance (`share`)? [Spec §Q2]
- [x] CHK005 Are the scanned APIs listed exactly, including the idle timer and the brightness write? [Spec §Q3, FR-A19-602]
- [x] CHK006 Are the checklist statuses and their evidence rules specified? [Spec §Q1]

## Scenario Coverage

- [x] CHK007 Is recovery after a drawing failure specified with the file that must stay unchanged and the reopened state? [Spec §Story 2, Q4]
- [x] CHK008 Are every stored snapshot schema (1, 2, newer, damaged) and every history case (current, newer, damaged) covered? [Spec §Q4]
- [x] CHK009 Is the interface journey named with its steps and time limit? [Spec §Story 4, Q5, SC-A19-604]
- [x] CHK010 Are copy that implies the app applies the wallpaper and a declined Photos prompt addressed? [Spec §Edge Cases]

## Non-Functional (performance, heat, accessibility)

- [x] CHK011 Are size limit, colour, heat, memory and accessibility results specified as device rows (LW-D1 … LW-D8), never claimed from the simulator? [Spec §FR-A19-606, Q1]
- [x] CHK012 Are measured-performance, size and video claims excluded from the copy? [Spec §Negative Requirements, Q2]

## Release and Ownership

- [x] CHK013 Are signing, archive and upload recorded as owner actions with their steps, never done here? [Spec §Overrides, Q1]
- [x] CHK014 Is the gap closed by this phase (G-RELEASE) named with its parts? [Spec §Overrides]
- [x] CHK015 Are the test time limits stated? [Spec §SC-A19-604]

## Notes

- `/speckit-implement` reads this checklist's state; it does not change the markers.
