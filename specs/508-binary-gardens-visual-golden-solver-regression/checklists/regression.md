# Requirements Quality Checklist: R02-G21-08 visual golden and solver regression

**Purpose**: Unit tests for the requirements of feature 508 (solver checks, alterations, golden frames, memory, CI,
timing of the baseline, player impact, licensing, future D1/D2/D3 evidence)
**Created**: 2026-11-27
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-27, following feature 498's checklist, after the
items were generated in this skill invocation; failures were corrected in the artifacts.

## Solver checks

- [x] CHK001 Are the per-level checks (generated level equal to the witness level, witness replay to a win on exactly
  the final run and not before, the plan at the band's length equal to the witness actions with its depth counts,
  nearest miss and work) stated for all 100 levels? [Completeness, Spec §Clarifications Q1]
- [x] CHK002 Is the work check counted (work at most 5,000), never timed? [Clarity, Spec §Clarifications Q1]
- [x] CHK003 Are all thirteen alteration kinds named, the levels they apply to and the naming rule for failures?
  [Completeness, Spec §Clarifications Q2]
- [x] CHK004 Is the split into tests of 10 levels stated with its reason so each test stays short? [Non-Functional,
  Spec §Clarifications Q1]
- [x] CHK005 Is the fingerprint list's shape (after begin, after the tutorial on tutorial levels, then one per action)
  stated? [Clarity, Spec §Clarifications Q1]

## Golden frames

- [x] CHK006 Are the 17 frames, their size, camera, shown tick and contents (positions, counts, controls, integrals and
  windows, the whole palette and material table) stated, with the reason for level 25? [Completeness, Spec
  §Clarifications Q3]
- [x] CHK007 Is regeneration restricted to an explicit switch, and a missing or incomplete baseline a named failure?
  [Clarity, Spec §Clarifications Q3]
- [x] CHK008 Are the simulator tolerances taken from feature 503's frame checks, and is level 25's frame named as new
  ground? [Measurability, Spec §Clarifications Q3; Plan]

## Memory

- [x] CHK009 Are the cycle steps, the count (12), the 16 MB bound and the cycle-1 reference stated, with the isolation
  rule for the footprint bound? [Clarity, Spec §Clarifications Q4]

## CI and timing

- [x] CHK010 Are CI's named step, its half and the local command with its options and exit code specified?
  [Completeness, Spec §Clarifications Q5]
- [x] CHK011 Do the overrides and Q6 agree on when the solver regression may be written and when the baseline is
  pinned and the gate recorded? [Consistency, Spec §Canonical overrides; Clarifications Q6; FR-R02G2108-009]
- [x] CHK012 Is the test-only golden code kept out of the Release binary? [Coverage, Plan]

## Player impact, licensing and evidence

- [x] CHK013 Is the player impact of each part (an unwinnable or non-minimal level, a misdrawn star, world or gauge, a
  leak) stated? [Coverage, Spec §User Scenarios]
- [x] CHK014 Are baselines stated to be code-computed descriptions, never pictures or third-party material? [Licensing,
  Spec §Negative Requirements]
- [x] CHK015 Are device-only measurements deferred to D1–D3 after ImplementationLock-100 with simulator results never
  counted as device evidence? [Completeness, Spec §SC-R02G2108-007]
- [x] CHK016 Are the code names the spec cites real (`heroTick(_:)` an extension function, the palette module-internal)?
  [Traceability, Spec §Context]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK011 failed at first reading: the overrides said the feature is implemented only after 504 … 507 are recorded
  while Q6 lets the solver regression be written earlier; the overrides now restrict only the baseline and the record.
  CHK016 failed at first reading: the spec named `BinaryGardensScenarios.heroTick` (no such type) and called the
  palette public; both are corrected. Every other item passed at first reading.
