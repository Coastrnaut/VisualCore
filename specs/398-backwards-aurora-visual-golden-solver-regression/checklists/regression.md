# Requirements Quality Checklist: R02-G10-08 visual golden and solver regression

**Purpose**: Unit tests for the requirements of feature 398 (solver replay and work bound, named alterations, golden
description contents and digest rules, the regeneration switch, simulator tolerances, memory cycles and isolation, CI
and local command reporting, no wall-clock assertions, player impact, layout scope and device evidence)
**Created**: 2026-11-23
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-23, following feature 388's checklist.

## Solver regression

- [x] CHK001 Are the per-level checks (fingerprint, witness replay with per-reversal digests and fingerprints within
  the budget, the exact certified reversals and smallest reversal count equal to the lower bound's) enumerated?
  [Completeness, Spec §Clarifications Q1]
- [x] CHK002 Is the work check counted (work at most the solver's work bound), never timed? [Clarity,
  Spec §Clarifications Q1; Plan research R1]
- [x] CHK003 Are all ten alteration kinds named with the naming rule for failures? [Completeness, Spec
  §Clarifications Q2]
- [x] CHK004 Is the split into tests of 10 levels stated so each test stays short? [Non-Functional, Spec
  §Clarifications Q1; FR-R02G1008-007]

## Golden frames

- [x] CHK005 Are the 16 frames, their size and their contents (ribbon sample points and checkpoint ring centres after the
  witness's first min(smallest − 1, 2) reversals at time 0, the kink count, the tear seam, the gauge's spent and total
  counts, the ten palette colours) specified?
  [Clarity, Spec §Clarifications Q3; Plan research R6]
- [x] CHK006 Are the digest, the one-quantum fallback and the self-check of pinned digests stated? [Consistency, Spec
  §Clarifications Q3; Plan research R3]
- [x] CHK007 Is regeneration restricted to an explicit switch, and a missing or incomplete manifest a named failure?
  [Edge Case, Spec §Edge Cases; Clarifications Q3]
- [x] CHK008 Are the simulator tolerances (sample points within 3 px of a ribbon pixel 0.15 cooler and
  0.15 from the ground, ghost points near a lilac pixel 0.1 from the ground, the first gauge bar 0.1 from the ground,
  corners within 0.05) stated by reference to feature 393? [Measurability,
  Spec §US2; Clarifications Q3]
- [x] CHK009 Is an off-screen projected point given a defined representation in a description? [Edge Case, Plan
  data-model]

## Memory

- [x] CHK010 Are the cycle steps, the count, the 16 MB bound and the cycle-1 reference stated? [Clarity, Spec
  §Clarifications Q4]
- [x] CHK011 Is the isolation rule for the footprint bound stated with its reason? [Consistency, Spec §Clarifications
  Q4; Plan research R4]
- [x] CHK012 Is an unavailable footprint a named failure rather than a pass? [Exception Flow, Spec §Clarifications Q4]

## Reporting, scope and limits

- [x] CHK013 Are CI's named step and the local command's summary and exit code specified? [Completeness, Spec
  §Clarifications Q5]
- [x] CHK014 Is it stated that nothing is timed against the wall clock (work, not seconds)? [Consistency, Spec §Edge
  Cases; Plan research R1]
- [x] CHK015 Is the test-only golden code kept out of the Release binary? [Coverage, Plan research R5]
- [x] CHK016 Is the player impact of each part (a misdrawn sample or checkpoint misleads about the match, drift, memory) stated? [Clarity,
  Spec §US1–US3]
- [x] CHK017 Is it stated that the feature changes no interface, so iPad and iPhone layout are out of scope, with one
  fixed golden size? [Scope, Spec §Layout and aspect]
- [x] CHK018 Are baselines stated to be code-computed descriptions, never pictures or third-party material? [Licensing,
  Plan research R2]
- [x] CHK019 Are device-only measurements (frame time, memory on hardware) deferred to D1–D3 with simulator results never
  counted as device evidence? [Traceability, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads checklist state but does not modify markers.
