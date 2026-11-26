# Requirements Quality Checklist: R02-G18-05 progression and player teaching

**Purpose**: Unit tests for the teaching and progression requirements (tutorial, hints, failure text, progress and
stars, daily and practice, schema migration, free content, determinism)
**Created**: 2026-11-25
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-25, following feature 465's checklist. CHK007
failed at first reading: the failure texts said "x %" and "r units" without saying how precisely a share (tenths of a
percent) and a distance (twentieths of a unit) are written; Clarification Q5 now names the level's words (one decimal
of a percent, hundredths of a unit) and the item passes. CHK006 was read twice because turning the periapsis direction
can tie at 12 steps; the clarification settles it (counterclockwise on a tie).

## Tutorial

- [x] CHK001 Are the tutorial's levels, its three instructions in words, and the event that advances each stated?
  [Clarity, Spec §FR-R02G1805-001; Clarifications Q2]
- [x] CHK002 Is dismissal defined (ends it for that level; undo never moves it back; shown in every mode)? [Coverage,
  Spec §Edge Cases; Clarifications Q2]

## Hints

- [x] CHK003 Is the hint's source stated (the minimal plan from the current orbit within the actions left) so that
  following exact hints and then playing the revolution wins every certified level? [Measurability, Spec
  §FR-R02G1805-002; Clarifications Q1]
- [x] CHK004 Are the won, failed, already-winning and no-plan cases worded (no hint; undo or retry; play the
  revolution; "No way to win was found in the actions left")? [Completeness, Spec §Edge Cases; Clarifications Q1]
- [x] CHK005 Is the hint search bounded (the solver's work limit and at most two tunings) so it never stalls the frame?
  [Clarity, Spec §Edge Cases; Plan §Performance]
- [x] CHK006 Are the three hint levels' texts given exactly (the lever; the way and distance with a tie rule for the
  direction and unchanged parts left out; the exact setting)? [Clarity, Spec §Clarifications Q1]

## Failure explanation

- [x] CHK007 Is a text given for every failure the play records (contact, order, share, apsis sector, apsis distance)
  with the values it names and their written precision? [Completeness, Spec §FR-R02G1805-003; Clarifications Q5]

## Progress, stars, daily and practice

- [x] CHK008 Are the unlock and star rules numeric (3 at the witness's tuning count, 2 within + 2, else 1; undone
  tunings counted; the play free; best result kept)? [Measurability, Spec §FR-R02G1805-004; Clarifications Q3]
- [x] CHK009 Are locked levels and impossible dates refused with named codes (`r02-g18.locked`, `r02-g18.date`)?
  [Coverage, Spec §Edge Cases; Clarifications Q3, Q4]
- [x] CHK010 Is the daily rule a pure function of the date (× 23, wrapped) and its range and stability measurable over
  2026 … 2036? [Measurability, Spec §FR-R02G1805-005; SC-R02G1805-004]
- [x] CHK011 Is practice defined (budget 24, no stars, no unlocks) and consistent with the kernel's budget bound
  (1 … 24)? [Consistency, Spec §Clarifications Q4]

## Versioning, content and determinism

- [x] CHK012 Is the snapshot schema 2 shape and its migration from schema 1 stated, including what is digested and what
  is presentation (shown tick, pending orbit, drag preview, hint level)? [Completeness, Spec §FR-R02G1805-007;
  Clarifications Q5]
- [x] CHK013 Is free access to all 100 levels required without payment, advertising, accounts or network? [Consistency,
  Spec §FR-R02G1805-006]
- [x] CHK014 Is the core forbidden to read a clock (the date arrives as an action)? [Consistency, Plan §Constraints]

## Notes

- `/speckit-implement` reads these markers; it does not change them.
