# Requirements Quality Checklist: R02-G20-08 visual golden and solver regression

**Purpose**: Unit tests for the requirements of feature 498 (solver replay and work bound, named alterations, golden
description contents and digest rules, the regeneration switch, simulator tolerances, memory cycles and isolation, CI
and local command reporting, no wall-clock assertions, player impact, layout scope and device evidence)
**Created**: 2026-11-26
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-26, following feature 488's checklist, after the items
were generated in this skill invocation; failures were corrected in the artifacts.

## Solver regression

- [x] CHK001 Are the per-level checks (fingerprint, witness replay to a win on exactly the final run and not before,
  within the budget, per-action fingerprints and per-action digests, the exact certified actions and the arrangements judged
  one action short) enumerated? [Completeness, Spec §Clarifications Q1]
- [x] CHK002 Is the work check counted (work at most the search's work bound), never timed? [Clarity, Spec
  §Clarifications Q1; Plan research R1]
- [x] CHK003 Are all twelve alteration kinds named with the naming rule for failures? [Completeness, Spec
  §Clarifications Q2]
- [x] CHK004 Is the split into tests of 10 levels stated with its reason so each test stays short? [Non-Functional, Spec
  §Clarifications Q1; Plan research R7; FR-R02G2008-007]
- [x] CHK005 Is the fingerprint list's shape (after begin, after the tutorial on tutorial levels, then one per action)
  stated so the per-action comparison is unambiguous? [Clarity, Spec §Clarifications facts]

## Golden frames

- [x] CHK006 Are the 16 frames, their size and their contents (the floor centre, every cap centre, the moon centre, the first
  gauge track and the first actions bar after all of the witness's actions but not the run at time 0, the element
  counts, the moonlight, the 21 palette colours) specified? [Clarity, Spec §Clarifications Q3; Plan research R6]
- [x] CHK007 Is the shown cycle of a frame defined (half the cycles run, as the feature-493 frame checks), and the
  frame never won (the run not applied)? [Edge Case, Spec §Clarifications Q3; Plan research R6]
- [x] CHK008 Are the digest, the one-quantum fallback and the self-check of pinned digests stated? [Consistency, Spec
  §Clarifications Q3; Plan research R3]
- [x] CHK009 Is regeneration restricted to an explicit switch, and a missing or incomplete manifest a named failure?
  [Edge Case, Spec §Edge Cases; Clarifications Q3]
- [x] CHK010 Are the simulator tolerances (each cap's centre 0.2 brighter than moss, the moon 0.1 from the backdrop, the
  first actions bar with red above blue by 0.08, the first gauge track 0.1 from the backdrop, points 6 px from what is
  drawn after them, the lower-corner patch within 0.06 of the gradient) stated by reference to feature 493? [Measurability,
  Spec §Clarifications facts, Q3]
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
- [x] CHK018 Is the player impact of each part (an unwinnable or non-minimal level, a misdrawn pod, vent, cap or gauge,
  memory growth) stated? [Clarity, Spec §US1–US3]
- [x] CHK019 Is it stated that the feature changes no interface, so iPad and iPhone layout are out of scope, with one
  fixed golden size? [Scope, Spec §Edge Cases "Layout and aspect"]
- [x] CHK020 Are baselines stated to be code-computed descriptions, never pictures or third-party material? [Licensing,
  Plan research R2]
- [x] CHK021 Are device-only measurements (frame time, memory on hardware) deferred to D1–D3 with simulator results
  never counted as device evidence? [Traceability, Spec SC-R02G2008-007]
- [x] CHK022 Is the contention rule stated (no agent's host tests while the lead's baseline or chain runs) so the
  round-two chunks stay inside their limits? [Non-Functional, Plan §Parallel work, Technical Context]

## Notes

- `/speckit-implement` reads checklist state but does not modify markers.
- Every item passed at first reading except CHK006, read twice: the description leaves out droplets and motes because
  they move by time; research R6 states why, and time 0 fixes them anyway. CHK007 uses the half-run shown cycle of this
  game's frame checks, and the frames stop before the run.
