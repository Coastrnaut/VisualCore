# Requirements Quality Checklist: R02-G19-05 progression and player teaching

**Purpose**: Unit tests for the teaching and progression requirements (tutorial, hints, failure text, progress and
stars, daily and practice, schema migration, free content, determinism, layout and evidence)
**Created**: 2026-11-26
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-26, following feature 475's checklist. CHK005 was
read twice: a search over every set of up to three changed wells could judge about 10,000 swims; Clarification Q1 bounds
it at min(actions left, 2) actions and 1,200 sets judged, with the certified plan's next placement tried first, and the
item passes. CHK007 was read twice because a split names the largest group: the clarified text also names the coherence
needed, so the reader sees how far it fell short.

## Tutorial

- [x] CHK001 Are the tutorial's levels, its three instructions in words, and the event that advances each stated?
  [Clarity, Spec §FR-R02G1905-001; Clarifications Q2]
- [x] CHK002 Is dismissal defined (ends it for that level; undo never moves it back; shown in every mode)? [Coverage,
  Spec §Edge Cases; Clarifications Q2]

## Hints

- [x] CHK003 Is the hint's source stated (a shortest completion from the current wells within the actions left, the
  certified plan's next placement first) so that following exact hints and then playing the swim wins every certified
  level? [Measurability, Spec §FR-R02G1905-002; Clarifications Q1]
- [x] CHK004 Are the won, failed, already-winning and no-plan cases worded (no hint; undo or retry; play the swim; "No
  way to win was found in the actions left")? [Completeness, Spec §Edge Cases; Clarifications Q1]
- [x] CHK005 Is the hint search bounded (1,200 sets judged, at most two actions) so it never stalls the frame?
  [Clarity, Spec §Edge Cases; Plan §Performance]
- [x] CHK006 Are the three hint levels' texts given exactly (the site or the well to take away; the sense; the exact
  well with slot, site, strength and sense) and is the full-slots case (a move or a removal) covered? [Clarity, Spec
  §Clarifications Q1; Edge Cases]

## Failure explanation

- [x] CHK007 Is a text given for every failure the play records (exit, coherence, coverage, connectedness) with the
  values it names (swimmer from 1, tick, largest group and need, lit and needed counts, the cell by row and column)?
  [Completeness, Spec §FR-R02G1905-003; Clarifications Q5]

## Progress, stars, daily and practice

- [x] CHK008 Are the unlock and star rules numeric (3 at the certified placement count, 2 within + 2, else 1; undone
  placements and removals counted; the play free; best result kept)? [Measurability, Spec §FR-R02G1905-004;
  Clarifications Q3]
- [x] CHK009 Are locked levels and impossible dates refused with named codes (`r02-g19.locked`, `r02-g19.date`)?
  [Coverage, Spec §Edge Cases; Clarifications Q3, Q4]
- [x] CHK010 Is the daily rule a pure function of the date (× 19, wrapped, distinct from the other round-two games) and
  its range and stability measurable over 2026 … 2036? [Measurability, Spec §FR-R02G1905-005; SC-R02G1905-004]
- [x] CHK011 Is practice defined (budget 24, no stars, no unlocks) and consistent with the kernel's budget bound
  (1 … 24)? [Consistency, Spec §Clarifications Q4]

## Versioning, content and determinism

- [x] CHK012 Is the snapshot schema 2 shape and its migration from schema 1 stated, including what is digested and what
  is presentation (shown tick, freeze, drag preview, orbit, hint level)? [Completeness, Spec §FR-R02G1905-007;
  Clarifications Q5]
- [x] CHK013 Is free access to all 100 levels required without payment, advertising, accounts or network? [Consistency,
  Spec §FR-R02G1905-006]
- [x] CHK014 Is the core forbidden to read a clock (the date arrives as an action)? [Consistency, Plan §Constraints]

## Layout, originality and evidence

- [x] CHK015 Is the placement of the new texts on iPhone and iPad stated (wrapping panel text, never over the dish) and
  their accessibility (plain, ordered, VoiceOver panel text, nothing by colour)? [Coverage, Spec §Assumptions]
- [x] CHK016 Are originality and the code-only rule stated (original text and rules; no new art, model or shader)?
  [Consistency, Spec §Negative Requirements]
- [x] CHK017 Is the evidence split stated: simulator proof now (host and simulator tests), device evidence only after
  ImplementationLock-100, no availability before X-R02-G19? [Coverage, Spec §Negative Requirements; Plan §Testing]

## Notes

- `/speckit-implement` reads these markers; it does not change them.
