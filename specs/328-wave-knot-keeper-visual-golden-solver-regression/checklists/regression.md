# Requirements Quality Checklist: R02-G03-08 visual golden and solver regression

**Purpose**: Unit tests for the requirements of feature 328 (solver replay and work bound, named alterations, golden
description contents and digest rules, the regeneration switch, simulator tolerances, memory cycles and isolation, CI
and local command reporting, no wall-clock assertions)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21.

## Solver regression

- [x] CHK001 Are the per-level checks (fingerprint, witness replay with fingerprints, exact shortest, work equal to
  the certified work) enumerated? [Completeness, Spec §Clarifications Q1]
- [x] CHK002 Is the work bound a counted number with its derivation (3,661 ropes expanded: 1 + 60 + 3,600)? [Clarity, Spec
  §Clarifications Q1]
- [x] CHK003 Are all twelve alteration kinds named with the naming rule for failures? [Completeness, Spec
  §Clarifications Q2]

## Golden frames

- [x] CHK004 Are the 16 frames, their size and their contents (control points, midpoints, handles, gates,
  crossings, colours) specified?
  [Clarity, Spec §Clarifications Q3]
- [x] CHK005 Are the digest, the one-quantum fallback and the self-check of pinned digests stated? [Consistency, Spec
  §Clarifications Q3; Plan research R3]
- [x] CHK006 Is regeneration restricted to an explicit switch, and a missing or incomplete manifest a named failure?
  [Edge Case, Spec §Edge Cases; Clarifications Q3]
- [x] CHK007 Are the simulator tolerances (2 px, 0.12 per channel, background 0.05) stated? [Measurability, Spec §US2]

## Memory

- [x] CHK008 Are the cycle steps, the count, the 16 MB bound and the warm-up rule stated? [Clarity, Spec
  §Clarifications Q4]
- [x] CHK009 Is the isolation rule for the footprint bound stated with its reason? [Consistency, Spec §Clarifications
  Q4; Plan research R4]
- [x] CHK010 Is an unavailable footprint a named failure rather than a pass? [Exception Flow, Spec §Clarifications Q4]

## Reporting and limits

- [x] CHK011 Are CI's named step and the local command's summary and exit code specified? [Completeness, Spec
  §Clarifications Q5]
- [x] CHK012 Is it stated that nothing is timed against the wall clock (work, not seconds)? [Consistency, Spec §Edge
  Cases; Plan research R1]
- [x] CHK013 Is the test-only golden code kept out of the Release binary? [Coverage, Plan research R5]
- [x] CHK014 Are device-only measurements deferred to D1–D3? [Traceability, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads checklist state but does not modify markers.
