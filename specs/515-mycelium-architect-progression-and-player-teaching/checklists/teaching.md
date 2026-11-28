# Requirements Quality Checklist: R02-G22-05 progression and player teaching

**Purpose**: Unit tests for the teaching and progression requirements (tutorial, hints, failure text, progress and
stars, daily and practice, schema migration, free content, determinism, layout and evidence)
**Created**: 2026-11-27
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-27, following feature 505's checklist, after the
items were generated in this skill invocation. CHK001 was read against the certified witnesses of the tutorial levels
(docs/games/mycelium-architect/levels/001 … 003: level 1 `seed(east)`, levels 2 and 3 one `nutrient`, then the run):
the first instruction names placing a nutrient or blocker and seeding from the root, so it fits each, and the second
advances on a second action or the level's end, so a one-action win still reaches `done`. CHK003 was read twice
because witnesses reach 4 actions, more than the two-action search: Clarification Q1 makes the witness's next
remaining action the hint while the arrangement lies on the way and the actions left cover the rest, so exact hints
from the start replay the witness.

## Tutorial

- [x] CHK001 Are the tutorial's levels, its three instructions in words, and the event that advances each stated, and
  does each instruction fit the tutorial levels' certified solutions? [Clarity, Spec §FR-R02G2205-001; Clarifications
  Q2]
- [x] CHK002 Is dismissal defined (ends it for that opening; undo, redo and `growth.show` never move it back; shown in
  every mode)? [Coverage, Spec §User Story 1; Clarifications Q2]

## Hints

- [x] CHK003 Is the hint's source stated (the witness's remaining actions while the arrangement is on its way, else a
  shortest completion within min(actions left, 2)) so that following exact hints and then running the growth wins every
  certified level? [Measurability, Spec §FR-R02G2205-002; SC-R02G2205-002; Clarifications Q1]
- [x] CHK004 Are the won, failed, not-playing, already-winning and no-plan cases worded (no hint; undo or retry; run the
  growth; "No way to win was found in the actions left")? [Completeness, Spec §Clarifications Q1]
- [x] CHK005 Is the hint search bounded (2,000 arrangements judged, at most two actions, above the 1,190 two-action
  maximum) and counted rather than timed? [Clarity, Spec §FR-R02G2205-009; Plan §Performance]
- [x] CHK006 Are the three hint levels' texts given exactly (the kind; the quadrant of a cell or the side of a
  direction, with the quadrant rule stated; the exact cell in the level's words or the compass name)? [Clarity, Spec
  §Clarifications Q1]
- [x] CHK007 Is "on the way" defined for every part of the arrangement (placed nutrients, placed blockers and seeds)
  and is "done" defined for each kind of witness action (placement, clear, seed, unseed)? [Clarity, Spec
  §Clarifications Q1]

## Failure explanation

- [x] CHK008 Is a text given for every failure the play records (toxic, starved, unreached, overweight) with the
  values it names (tip or terminal from 1, cell, pulse, weight and its bound, numbers grouped)? [Completeness, Spec
  §FR-R02G2205-003; Clarifications Q5]

## Progress, stars, daily and practice

- [x] CHK009 Are the unlock and star rules numeric (3 at the certified action count, 2 within + 2, else 1; undone
  actions counted; the run free; best result kept, never replaced by a worse)? [Measurability, Spec §FR-R02G2205-004;
  Clarifications Q3]
- [x] CHK010 Are locked levels, a missing next level and impossible dates refused with named codes (`r02-g22.locked`,
  `r02-g22.date`), and is `level.next`'s former wrap from 100 to 1 explicitly withdrawn? [Coverage, Spec
  §Clarifications Q3, Q4, Q5]
- [x] CHK011 Is the daily rule a pure function of the date (× 11, wrapped, distinct from the other round-two games) and
  its range, stability and 100-day coverage measurable over 2026 … 2036? [Measurability, Spec §FR-R02G2205-005;
  SC-R02G2205-004]
- [x] CHK012 Is practice defined (budget 24 on a copy of the level, no stars, no unlocks) and consistent with the
  kernel's budget bound (1 … 24)? [Consistency, Spec §Clarifications Q4]

## Versioning, content and determinism

- [x] CHK013 Is the snapshot schema 2 shape and its migration from schema 1 stated, including the digest domain v2,
  what is digested and what is presentation (shown pulse, tool, preview, orbit, inspected cell, hint level)?
  [Completeness, Spec §FR-R02G2205-007; Clarifications Q5]
- [x] CHK014 Is free access to all 100 levels required without payment, advertising, accounts or network, with
  "locked" meaning not yet won? [Consistency, Spec §FR-R02G2205-006; Clarifications Q3]
- [x] CHK015 Is the core forbidden to read a clock or random source (the date arrives as an action)? [Consistency, Spec
  §FR-R02G2205-009; Plan §Constraints]
- [x] CHK016 Are the existing tests that may change named, with every other test unchanged? [Traceability, Spec
  §Clarifications Q5; SC-R02G2205-006]

## Layout, originality and evidence

- [x] CHK017 Is the placement of the new texts on iPhone and iPad stated (wrapping panel text, never over the scene)
  and their accessibility (plain, ordered, VoiceOver panel text, nothing by colour)? [Coverage, Spec §FR-R02G2205-008;
  Assumptions]
- [x] CHK018 Are originality and the code-only rule stated (original text and rules; no new art, model or shader)?
  [Consistency, Spec §Negative Requirements]
- [x] CHK019 Is the evidence split stated: simulator proof now (host and simulator tests), device evidence only after
  ImplementationLock-100, no availability before X-R02-G22? [Coverage, Spec §Negative Requirements; Plan §Testing]

## Notes

- `/speckit-implement` reads these markers; it does not change them.
- No item failed; the spec needed no change.
