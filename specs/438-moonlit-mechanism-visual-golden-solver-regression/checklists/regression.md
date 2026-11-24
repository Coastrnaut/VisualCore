# Requirements Quality Checklist: R02-G14-08 visual golden and solver regression

**Purpose**: Unit tests for the requirements of feature 438 (solver replay and work bound, named alterations, golden
description contents and digest rules, the regeneration switch, simulator tolerances, memory cycles and isolation, CI
and local command reporting, no wall-clock assertions, player impact, layout scope and device evidence)
**Created**: 2026-11-24
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-24, following feature 428's checklist; failures were corrected in the artifacts.

## Solver regression

- [x] CHK001 Are the per-level checks (fingerprint, witness replay to a win in exactly its action count within the
  budget, per-action fingerprints and per-action digests, the exact certified turns, lamp steps and re-seats, smaller-vectors count and
  norm) enumerated? [Completeness, Spec §Clarifications Q1]
- [x] CHK002 Is the work check counted (work at most the solver's work bound), never timed? [Clarity, Spec
  §Clarifications Q1; Plan research R1]
- [x] CHK003 Are all thirteen alteration kinds named with the naming rule for failures? [Completeness, Spec
  §Clarifications Q2]
- [x] CHK004 Is the split into tests of 10 levels stated so each test stays short? [Non-Functional, Spec §Clarifications
  Q1; FR-R02G1408-007]

## Golden frames

- [x] CHK005 Are the 16 frames, their size and their contents (cast-cell centres, gear centres and rim check points, card
  centres, the first alignment pip, the lamp and the first moves bar after the witness's turns, re-seats and lamp steps
  and before its run at time 0 with key frame 0 shown, the element counts, the palette colours) specified? [Clarity, Spec §Clarifications Q3; Plan research R6]
- [x] CHK006 Are the digest, the one-quantum fallback and the self-check of pinned digests stated? [Consistency, Spec
  §Clarifications Q3; Plan research R3]
- [x] CHK007 Is regeneration restricted to an explicit switch, and a missing or incomplete manifest a named failure?
  [Edge Case, Spec §Edge Cases; Clarifications Q3]
- [x] CHK008 Are the simulator tolerances (a cast cell 0.25 darker than the paper, a rim point with red
  above blue by 0.08, the first moves bar 0.1 from the paper, the backdrop within 0.05 of night, points 6 px from what is
  drawn over them) stated by reference to feature 433? [Measurability, Spec §US2; Clarifications Q3]
- [x] CHK009 Is an off-screen projected point given a defined representation in a description? [Edge Case, Plan
  data-model] — corrected 2026-11-24: the data model did not say; a point behind the eye is now recorded as null.

## Memory

- [x] CHK010 Are the cycle steps, the count, the 16 MB bound and the cycle-1 reference stated? [Clarity, Spec
  §Clarifications Q4]
- [x] CHK011 Is the isolation rule for the footprint bound stated with its reason? [Consistency, Spec §Clarifications Q4;
  Plan research R4]
- [x] CHK012 Is an unavailable footprint a named failure rather than a pass? [Exception Flow, Spec §Clarifications Q4]

## Reporting, scope and limits

- [x] CHK013 Are CI's named step and the local command's summary and exit code specified? [Completeness, Spec
  §Clarifications Q5]
- [x] CHK014 Is it stated that nothing is timed against the wall clock (work, not seconds)? [Consistency, Spec §Edge
  Cases; Plan research R1]
- [x] CHK015 Is the test-only golden code kept out of the Release binary? [Coverage, Plan research R5]
- [x] CHK016 Is the player impact of each part (a misdrawn shadow or gauge misleads about what the machine casts, drift, memory)
  stated? [Clarity, Spec §US1–US3]
- [x] CHK017 Is it stated that the feature changes no interface, so iPad and iPhone layout are out of scope, with one
  fixed golden size? [Scope, Spec §Edge Cases "Layout and aspect"]
- [x] CHK018 Are baselines stated to be code-computed descriptions, never pictures or third-party material? [Licensing,
  Plan research R2]
- [x] CHK019 Are device-only measurements (frame time, memory on hardware) deferred to D1–D3 with simulator results never
  counted as device evidence? [Traceability, Spec SC-R02G1408-007]

## Notes

- `/speckit-implement` reads checklist state but does not modify markers.
- CHK009 failed at first reading; the data model was corrected before the item was judged.
