# Requirements Quality Checklist: R02-G12-09 simulator integration and full app lock

**Purpose**: Unit tests for the requirements of feature 419 (identifiers and their pinned list, interface journeys and
chunk, level 1 constants, schema examples, release configuration, candidate availability, solvability evidence, test
time bounds)
**Created**: 2026-11-23
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-23, following feature 409's checklist.

## Identifiers and journeys

- [x] CHK001 Is every panel control the tests use named with its exact identifier and the shared prefix, and is the full
  list required to be pinned and unique? [Completeness, Spec §Clarifications Q1; FR-R02G1209-001]
- [x] CHK002 Is the end-to-end journey stated step by step (open, dismiss tutorial, step the string and peg steppers,
  Tune, Test, win, stars, next level open, relaunch, replay, stop)? [Completeness, Spec §US1; Clarifications Q2]
- [x] CHK003 Is what the tests read named (canvas description phrases "The crossing holds in every step", "Stars: 3 of
  3")? [Clarity, Spec §Clarifications Q1, Q2]
- [x] CHK004 Is the save point before a relaunch addressed (background before terminate)? [Edge Case, Spec §Edge Cases]

## Level 1 constants

- [x] CHK005 Is the source of the pinned level 1 certified actions and the panel's opening choice (string 0 at its
  current peg) named, and is a drift between them and the Core required to fail? [Consistency, Spec §Clarifications Q2;
  research R2]

## Schema examples

- [x] CHK006 Are both earlier schemas (1 and 2) covered with their contents and the expected restore result?
  [Completeness, Spec §FR-R02G1209-003; data-model]
- [x] CHK007 Is the stale registration comment ("Snapshot schema 1") required to be corrected? [Consistency, Spec
  §Clarifications Q3]

## Release and availability

- [x] CHK008 Is release exclusion of test-only code stated with the symbols and the check that proves it?
  [Measurability, Spec §FR-R02G1209-004; Clarifications Q4]
- [x] CHK009 Are both sides of candidate availability defined (unavailable without the testing argument, openable with
  it, listed in candidates and not in `all`)? [Coverage, Spec §FR-R02G1209-006; Clarifications Q5]

## Evidence and bounds

- [x] CHK010 Is all-level solvability tied to a named regression with a measurable result (100 of 100)? [Measurability,
  Spec §SC-R02G1209-004]
- [x] CHK011 Is each interface test bounded in time (under 90 s) and placed in a named serial chunk? [Clarity, Spec
  §SC-R02G1209-001; Clarifications Q2]
- [x] CHK012 Are device-only journeys separated as {device} with their later feature? [Scope, Spec §SC-R02G1209-006]
- [x] CHK013 Are both build configurations (debug and release) named as required evidence? [Completeness, Spec
  §SC-R02G1209-003]
- [x] CHK014 Is the reference regression part of the evidence? [Completeness, Spec §SC-R02G1209-005]
- [x] CHK015 Is the interface chunk key required to be unique among the release checks' keys, so no group is silently
  dropped? [Consistency, Spec §Clarifications Q2]
- [x] CHK016 Is the way each certified action is played stated (step the string and peg steppers to the tuning, reading
  each value and counting a press only when it moves, then Tune; finally Test)? [Clarity, Spec §Clarifications Q2;
  §Edge Cases "A lost tap"; research R2]

## Scope

- [x] CHK017 Is it stated that this feature adds no visuals (identifiers, tests, examples only), so code-only graphics
  and licensing are unchanged from features 413 and 416? [Scope, Spec §Assumptions]
- [x] CHK018 Is the layout scope stated (the existing panel of feature 416 on iPhone and iPad simulators, no new
  layout)? [Scope, Spec §Assumptions]

## Notes

- `/speckit-implement` reads these markers and does not change them.
- The interface namespace is `HB` (unused by any UI test class) and the chunk key `u3` (unused; Spec §Clarifications,
  facts checked).
- Every item passed at first reading.
