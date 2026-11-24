# Requirements Quality Checklist: R02-G15-08 visual golden and solver regression

**Purpose**: Unit tests for the requirements of feature 448 (solver replay and work bound, named alterations, golden
description contents and digest rules, the regeneration switch, simulator tolerances, memory cycles and isolation, CI
and local command reporting, no wall-clock assertions, player impact, layout scope and device evidence)
**Created**: 2026-11-24
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-24, following feature 438's checklist; failures
were corrected in the artifacts.

## Solver regression

- [x] CHK001 Are the per-level checks (fingerprint, witness replay to a win on exactly the last turn and not before,
  within the budget, per-action fingerprints and per-action digests, the exact certified turns and the states reached
  one turn short) enumerated? [Completeness, Spec §Clarifications Q1]
- [x] CHK002 Is the work check counted (work at most the search's work bound), never timed? [Clarity, Spec
  §Clarifications Q1; Plan research R1]
- [x] CHK003 Are all eleven alteration kinds named with the naming rule for failures? [Completeness, Spec
  §Clarifications Q2]
- [x] CHK004 Is the split into tests of 5 levels stated with its reason so each test stays short? [Non-Functional, Spec
  §Clarifications Q1; Plan research R7; FR-R02G1508-007]
- [x] CHK005 Is the fingerprint list's shape (after begin, after the tutorial on tutorial levels, then one per turn)
  stated so the per-action comparison is unambiguous? [Clarity, Spec §Clarifications facts]

## Golden frames

- [x] CHK006 Are the 16 frames, their size and their contents (cube centres, hinge mark centres, target cell centres,
  the first covered pip and the first moves bar after all of the witness's turns but the last at time 0, the element
  counts, the palette colours) specified? [Clarity, Spec §Clarifications Q3; Plan research R6]
- [x] CHK007 Is the frame state of a one-turn witness defined (no turn applied, still not won)? [Edge Case, Plan
  research R6] — corrected 2026-11-24: research R6 did not say; it now states a one-turn witness applies no turn.
- [x] CHK008 Are the digest, the one-quantum fallback and the self-check of pinned digests stated? [Consistency, Spec
  §Clarifications Q3; Plan research R3]
- [x] CHK009 Is regeneration restricted to an explicit switch, and a missing or incomplete manifest a named failure?
  [Edge Case, Spec §Edge Cases; Clarifications Q3]
- [x] CHK010 Are the simulator tolerances (a cube centre 0.25 brighter than the night, the chosen hinge with red above
  blue by 0.08, the first moves bar 0.1 from the night, the corners within 0.05 of night, points 6 px from what is drawn
  after them) stated by reference to feature 443? [Measurability, Spec §Clarifications facts, Q3]
- [x] CHK011 Is an off-screen projected point given a defined representation in a description? [Edge Case, Plan
  data-model]

## Memory

- [x] CHK012 Are the cycle steps, the count, the 16 MB bound and the cycle-1 reference stated? [Clarity, Spec
  §Clarifications Q4]
- [x] CHK013 Is the isolation rule for the footprint bound stated with its reason? [Consistency, Spec §Clarifications
  Q4; Plan research R4]
- [x] CHK014 Is an unavailable footprint a named failure rather than a pass? [Exception Flow, Spec §Clarifications Q4]

## Reporting, scope and limits

- [x] CHK015 Are CI's named step and the local command's summary and exit code specified? [Completeness, Spec
  §Clarifications Q5]
- [x] CHK016 Is it stated that nothing is timed against the wall clock (work, not seconds)? [Consistency, Spec §Edge
  Cases; Plan research R1]
- [x] CHK017 Is the test-only golden code kept out of the Release binary? [Coverage, Plan research R5]
- [x] CHK018 Is the player impact of each part (an unwinnable or non-minimal level, a misdrawn cube or gauge, memory
  growth) stated? [Clarity, Spec §US1–US3]
- [x] CHK019 Is it stated that the feature changes no interface, so iPad and iPhone layout are out of scope, with one
  fixed golden size? [Scope, Spec §Edge Cases "Layout and aspect"]
- [x] CHK020 Are baselines stated to be code-computed descriptions, never pictures or third-party material?
  [Licensing, Plan research R2]
- [x] CHK021 Are device-only measurements (frame time, memory on hardware) deferred to D1–D3 with simulator results
  never counted as device evidence? [Traceability, Spec SC-R02G1508-007]

## Notes

- `/speckit-implement` reads checklist state but does not modify markers.
- CHK007 failed at first reading; research R6 was corrected before the item was judged (the correction was already in
  R6's last sentence when this checklist was committed).
