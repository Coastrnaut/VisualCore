# Requirements Quality Checklist: R02-G21-05 progression and player teaching

**Purpose**: Unit tests for the teaching and progression requirements (tutorial, hints, failure text, progress and
stars, daily and practice, schema migration, free content, determinism, layout and evidence)
**Created**: 2026-11-27
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-27, following feature 495's checklist, after the
items were generated in this skill invocation. CHK001 was read against the certified witnesses (1, 2, 3, 3 and 4
arrangement actions by band; levels 1 … 3 are band 1, one action): the first instruction names every kind of change
(orbit drag, ring drag, brightness pip, tilt dial, panel), so it fits any single-action witness, and the second advances
on a second action or the level's end, so a one-action win still reaches `done`. CHK003 was read twice because
witnesses reach 4 actions, more than the two-action search: Clarification Q1 makes the witness's next remaining action
the hint while every control holds its starting or certified value and the actions left cover the rest, so exact hints
from the start replay the witness.

## Tutorial

- [x] CHK001 Are the tutorial's levels, its three instructions in words, and the event that advances each stated, and
  does each instruction fit the tutorial levels' certified solutions? [Clarity, Spec §FR-R02G2105-001; Clarifications
  Q2]
- [x] CHK002 Is dismissal defined (ends it for that opening; undo, redo and `clock.show` never move it back; shown in
  every mode)? [Coverage, Spec §User Story 1; Clarifications Q2]

## Hints

- [x] CHK003 Is the hint's source stated (the witness's remaining actions while every control is on its way, else a
  shortest completion within min(actions left, 2)) so that following exact hints and then running the cycle wins every
  certified level? [Measurability, Spec §FR-R02G2105-002; SC-R02G2105-002; Clarifications Q1]
- [x] CHK004 Are the won, failed, not-playing, already-winning and no-plan cases worded (no hint; undo or retry; run the
  cycle; "No way to win was found in the actions left")? [Completeness, Spec §Clarifications Q1]
- [x] CHK005 Is the hint search bounded (2,000 arrangements judged, at most two actions, above the 650 two-action
  maximum) and counted rather than timed? [Clarity, Spec §FR-R02G2105-009; Plan §Performance]
- [x] CHK006 Are the three hint levels' texts given exactly (the kind; which star and which way, with the phase
  direction rule (target − current) mod 48 in 1 … 24; the exact ring, phase, luminosity or tilt) with stars and rings
  numbered from 1? [Clarity, Spec §Clarifications Q1]

## Failure explanation

- [x] CHK007 Is a text given for every failure the play records (frozen, scorched, unstable, wilted, bleached) with the
  values it names (world from 1, tick in the level's words, the window and ticks required, the total and bloom band),
  including the E = 0, w = 0 and singular wordings? [Completeness, Spec §FR-R02G2105-003; Clarifications Q5]

## Progress, stars, daily and practice

- [x] CHK008 Are the unlock and star rules numeric (3 at the certified action count, 2 within + 2, else 1; undone
  actions counted; the run free; best result kept, never replaced by a worse)? [Measurability, Spec §FR-R02G2105-004;
  Clarifications Q3]
- [x] CHK009 Are locked levels, a missing next level and impossible dates refused with named codes (`r02-g21.locked`,
  `r02-g21.date`), and is `level.next`'s former wrap from 100 to 1 explicitly withdrawn? [Coverage, Spec
  §Clarifications Q3, Q4, Q6]
- [x] CHK010 Is the daily rule a pure function of the date (× 13, wrapped, distinct from the other round-two games) and
  its range, stability and 100-day coverage measurable over 2026 … 2036? [Measurability, Spec §FR-R02G2105-005;
  SC-R02G2105-004]
- [x] CHK011 Is practice defined (budget 24 on a copy of the level, no stars, no unlocks) and consistent with the
  kernel's budget bound (1 … 24)? [Consistency, Spec §Clarifications Q4]

## Versioning, content and determinism

- [x] CHK012 Is the snapshot schema 2 shape and its migration from schema 1 stated, including the digest domain v2, what
  is digested and what is presentation (shown tick, preview, orbit, inspected world, hint level)? [Completeness, Spec
  §FR-R02G2105-007; Clarifications Q5]
- [x] CHK013 Is free access to all 100 levels required without payment, advertising, accounts or network, with "locked"
  meaning not yet won? [Consistency, Spec §FR-R02G2105-006; Clarifications Q3]
- [x] CHK014 Is the core forbidden to read a clock or random source (the date arrives as an action)? [Consistency, Spec
  §FR-R02G2105-009; Plan §Constraints]
- [x] CHK015 Are the existing tests that may change named, with every other test unchanged? [Traceability, Spec
  §Clarifications Q6; SC-R02G2105-006]

## Layout, originality and evidence

- [x] CHK016 Is the placement of the new texts on iPhone and iPad stated (wrapping panel text, never over the scene)
  and their accessibility (plain, ordered, VoiceOver panel text, nothing by colour)? [Coverage, Spec §FR-R02G2105-008;
  Assumptions]
- [x] CHK017 Are originality and the code-only rule stated (original text and rules; no new art, model or shader)?
  [Consistency, Spec §Negative Requirements]
- [x] CHK018 Is the evidence split stated: simulator proof now (host and simulator tests), device evidence only after
  ImplementationLock-100, no availability before X-R02-G21? [Coverage, Spec §Negative Requirements; Plan §Testing]

## Notes

- `/speckit-implement` reads these markers; it does not change them.
