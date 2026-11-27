# Requirements Quality Checklist: R02-G20-09 simulator integration and full app lock

**Purpose**: Unit tests for the requirements of feature 499 (identifiers and their pinned list, interface journeys and
chunk, level 1 constants, schema examples, release configuration, candidate availability, solvability evidence, test
time bounds)
**Created**: 2026-11-26
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-26, following feature 489's checklist, after the items were generated in this skill invocation.

## Identifiers and journeys

- [x] CHK001 Is every panel control the tests use named with its exact identifier and the shared prefix, and is the full
  list required to be pinned and unique? [Completeness, Spec §Clarifications Q1; FR-R02G2009-001]
- [x] CHK002 Is the end-to-end journey stated step by step (open, dismiss tutorial, choose the pod's slot and site, Place,
  toggle the vent, Run, win, stars, next level open, relaunch, replay, stop)? [Completeness, Spec §US1;
  Clarifications Q2]
- [x] CHK003 Is what the tests read named (the canvas description phrase "Every colony stayed in its
  band.", the `stars` text "Best: 3 of 3 stars", the `actions` text, the slot and site controls' values and
  the vent toggle's value)? [Clarity, Spec §Clarifications Q1, Q2]
- [x] CHK004 Is the save point before a relaunch addressed (background before terminate)? [Edge Case, Spec §Edge Cases]

## Level 1 constants

- [x] CHK005 Is the source of the pinned level 1 certified actions (a pod at row 2, column 5 in slot 0 and vent 0
  closed from the certified witness, then the run) named, and is a drift between them and the Core required to fail? [Consistency, Spec §Clarifications Q2;
  research R2]

## Schema examples

- [x] CHK006 Are both earlier schemas (1 and 2) covered with their contents and the expected restore result?
  [Completeness, Spec §FR-R02G2009-003; data-model]
- [x] CHK007 Is the registration comment ("Snapshot schema 1, so no earlier example is stored yet" since feature 493)
  required to be corrected? [Consistency, Spec §Clarifications Q3]

## Release and availability

- [x] CHK008 Is release exclusion of test-only code stated with the symbols and the check that proves it?
  [Measurability, Spec §FR-R02G2009-004; Clarifications Q4]
- [x] CHK009 Are both sides of candidate availability defined (unavailable without the testing argument, openable with
  it, listed in candidates and not in `all`)? [Coverage, Spec §FR-R02G2009-006; Clarifications Q5]

## Evidence and bounds

- [x] CHK010 Is all-level solvability tied to a named regression with a measurable result (100 of 100)? [Measurability,
  Spec §SC-R02G2009-004]
- [x] CHK011 Is each interface test bounded in time (under 90 s) and placed in a named serial chunk? [Clarity, Spec
  §SC-R02G2009-001; Clarifications Q2]
- [x] CHK012 Are device-only journeys separated as {device} with their later feature? [Scope, Spec §SC-R02G2009-006]
- [x] CHK013 Are both build configurations (debug and release) named as required evidence? [Completeness, Spec
  §SC-R02G2009-003]
- [x] CHK014 Is the reference regression part of the evidence? [Completeness, Spec §SC-R02G2009-005]
- [x] CHK015 Is the interface chunk key required to be unique among the release checks' keys, so no group is silently
  dropped? [Consistency, Spec §Clarifications Q2]
- [x] CHK016 Is the way each certified action is made stated (move the slot and site by their controls' values,
  then tap Place; toggle the vent until it reads closed; reading the actions-left count before and after and counting a
  press only when it moves; then Run), and is it stated that choosing the slot and site spends no action? [Clarity, Spec
  §Clarifications Q2; §Edge Cases "A lost tap"; research R2]

## Scope

- [x] CHK017 Is it stated that this feature adds no visuals (identifiers, tests, examples only), so code-only graphics
  and licensing are unchanged from features 493 and 496? [Scope, Spec §Assumptions]
- [x] CHK018 Is the layout scope stated (the existing panel of feature 496 on iPhone and iPad simulators, no new
  layout)? [Scope, Spec §Assumptions]
- [x] CHK019 Does every pinned identifier name exactly one element of the panel, including the failure explanation that
  used to share `failure`? [Consistency, Spec §Clarifications Q1; Plan research R5]

## Notes

- `/speckit-implement` reads these markers and does not change them.
- The interface namespace is `MW` (unused) and the chunk key `c4` (unused; Spec §Clarifications, facts checked).
- CHK019 carries over from features 479 and 489: the failure explanation has its own identifier `explanation` from the
  start, so no two texts share one.
- Every item passed at first reading; the identifier list is pinned from the panel as built in features 493 … 497.
