# Requirements Quality Checklist: R02-G17-05 progression and player teaching

**Purpose**: Unit tests for the teaching and progression requirements (tutorial, hints, failure text, progress and
stars, daily and practice, schema migration, free content, determinism)
**Created**: 2026-11-25
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-25, following feature 455's checklist. Every item
passed at first reading; CHK006 was read twice because the shorter way around an orbit can tie on an even period, and
the clarification settles it (forward on a tie).

## Tutorial

- [x] CHK001 Are the tutorial's levels, its three instructions in words, and the event that advances each stated?
  [Clarity, Spec §FR-R02G1705-001; Clarifications Q2]
- [x] CHK002 Is dismissal defined (ends it for that level; undo never moves it back; shown in every mode)? [Coverage,
  Spec §Edge Cases; Clarifications Q2]

## Hints

- [x] CHK003 Is the hint's source stated (the minimal plan from the current phases within the actions left) so that
  following exact hints and then running the clock wins every certified level? [Measurability, Spec §FR-R02G1705-002;
  Clarifications Q1]
- [x] CHK004 Are the won, failed, already-in-order and no-plan cases worded (no hint; undo or retry; run the clock; "No
  way to win was found in the actions left")? [Completeness, Spec §Edge Cases; Clarifications Q1]
- [x] CHK005 Is the hint search bounded (the solver's work limit and change limit) so it never stalls the frame?
  [Clarity, Spec §Edge Cases; Plan §Performance]
- [x] CHK006 Are the three hint levels' texts given exactly (the planet; the way and distance, the shorter way with a
  tie rule; the exact phase)? [Clarity, Spec §Clarifications Q1]

## Failure explanation

- [x] CHK007 Is a text given for every failure the run records (unwanted, window, horizon) with the values it names
  (planets, ticks, target number, window)? [Completeness, Spec §FR-R02G1705-003; Clarifications Q5]

## Progress, stars, daily and practice

- [x] CHK008 Are the unlock and star rules numeric (3 at the witness's change count, 2 within + 2, else 1; undone
  changes counted; the run free; best result kept)? [Measurability, Spec §FR-R02G1705-004; Clarifications Q3]
- [x] CHK009 Are locked levels and impossible dates refused with named codes (`r02-g17.locked`, `r02-g17.date`)?
  [Coverage, Spec §Edge Cases; Clarifications Q3, Q4]
- [x] CHK010 Is the daily rule a pure function of the date (× 29, wrapped) and its range and stability measurable over
  2026 … 2036? [Measurability, Spec §FR-R02G1705-005; SC-R02G1705-004]
- [x] CHK011 Is practice defined (budget 24, no stars, no unlocks) and consistent with the kernel's budget bound
  (1 … 24)? [Consistency, Spec §Clarifications Q4]

## Versioning, content and determinism

- [x] CHK012 Is the snapshot schema 2 shape and its migration from schema 1 stated, including what is digested and what
  is presentation (chosen body, shown tick, pending phase, hint level)? [Completeness, Spec §FR-R02G1705-007;
  Clarifications Q5]
- [x] CHK013 Is free access to all 100 levels required without payment, advertising, accounts or network? [Consistency,
  Spec §FR-R02G1705-006]
- [x] CHK014 Is the core forbidden to read a clock (the date arrives as an action)? [Consistency, Plan §Constraints]

## Notes

- `/speckit-implement` reads these markers; it does not change them.
