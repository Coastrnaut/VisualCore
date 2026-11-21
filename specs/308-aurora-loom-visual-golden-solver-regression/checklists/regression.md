# Requirements Quality Checklist: R02-G01-08 visual golden and solver regression

**Purpose**: Unit tests for the requirements of feature 308 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-20
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-20; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is the player-facing harm each check prevents stated (an unwinnable level, a wrong best-possible count, a
  misplaced marker, the app being ended for memory)? [Completeness, Spec §US1–US3]
- [x] CHK002 Is it stated that the regression adds checks only and never changes rules, levels or state? [Clarity, Spec
  §FR-R02G0108-007; Assumptions]

## Deterministic invariants

- [x] CHK003 Is the solver bound expressed in counted work with an exact number rather than time? [Measurability, Spec
  §Clarifications Q1; SC-R02G0108-001]
- [x] CHK004 Is the golden description defined precisely enough to be identical on every host (fields, rounding, colour
  depth, serialization, hash)? [Clarity, Spec §Clarifications Q3]
- [x] CHK005 Is the golden set enumerated exactly (levels, tiers, times, the hero frame; 16 frames)? [Completeness, Spec
  §Clarifications Q3; SC-R02G0108-003]
- [x] CHK006 Are the twelve kinds of alteration listed, each with what the failure must name? [Completeness, Spec
  §Clarifications Q2]

## Empty and error states

- [x] CHK007 Is the behaviour defined for a missing, unreadable or incomplete golden manifest? [Edge Case, Spec §Edge
  Cases] (added during this review)
- [x] CHK008 Is an unavailable memory reading defined as a named failure rather than a pass? [Edge Case, Spec
  §Clarifications Q4]
- [x] CHK009 Is a solver exceeding its bound defined as a named failure instead of a hang? [Edge Case, Spec §Edge Cases]
- [x] CHK010 Is deliberate regeneration of a baseline defined as an explicit, never automatic step? [Clarity, Spec
  §FR-R02G0108-004; Edge Cases]

## Source licence and code-only graphics

- [x] CHK011 Is it stated that baselines are computed by code and no stored picture made outside the code is used?
  [Consistency, Spec §Canonical overrides; Plan §Constitution XIII]
- [x] CHK012 Is the provenance of everything compared (own levels, solver, CPU reference) stated, with no third-party
  asset? [Completeness, Spec §Assumptions; Traceability]

## iPad/iPhone layout

- [x] CHK013 Is it explicit that no interface changes and which earlier tests keep covering aspects and panel layouts?
  [Coverage, Spec §Edge Cases] (added during this review)

## Simulator proof

- [x] CHK014 Are the simulator tolerances for rendered frames stated numerically (2 px, 0.12 per channel, 0.05 for the
  background)? [Measurability, Spec §US2]
- [x] CHK015 Is the memory measure defined (12 cycles, what each does, the reading, the 16 MB bound over cycle 1, zero
  live GPU objects)? [Measurability, Spec §Clarifications Q4; SC-R02G0108-004]
- [x] CHK016 Is it defined which parts CI runs and which the local command runs, with one summary? [Clarity, Spec
  §Clarifications Q5; SC-R02G0108-005]

## Future D1/D2/D3 evidence

- [x] CHK017 Are device frame time and memory deferred to ImplementationLock-100 as a {device} criterion?
  [Completeness, Spec §SC-R02G0108-007]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
