# Requirements Quality Checklist: R02-F08 curves, ribbons and tubes

**Purpose**: Unit tests for the requirements of feature 208 (completeness, determinism, compatibility, testability,
performance)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-19; failures were corrected in the artifacts.

## Requirement Completeness

- [x] CHK001 Are all four deliverables and batching mapped to requirements? [Traceability, Spec §Traceability]
- [x] CHK002 Are the control-point counts of each curve family stated? [Completeness, data-model]
- [x] CHK003 Are ribbon winding and orientation defined? [Gap → corrected: data-model Ribbon mesh]
- [x] CHK004 Are refusals named for every bad input (points, tolerance, width, budget)? [Completeness, Spec §Edge Cases]

## Requirement Clarity

- [x] CHK005 Is the adaptive test (5 interior points, depth 20) stated precisely? [Clarity, Clarifications Q2]
- [x] CHK006 Is the collapse threshold scale-aware and numeric? [Clarity, Clarifications Q3]
- [x] CHK007 Is the closed-seam repeat rule a formula? [Clarity, Clarifications Q4]

## Determinism

- [x] CHK008 Is identical output for identical input required? [Determinism, Spec §US1 AS4]
- [x] CHK009 Is the initial normal rule deterministic when no hint is given? [Determinism, Clarifications Q3]

## Compatibility

- [x] CHK010 Is it stated that the existing tube and camera rail are unchanged? [Compatibility, Spec §FR-R02F08-007]

## Testability

- [x] CHK011 Are the reference curves and tolerances enumerated (6 × 3)? [Measurability, Spec §SC-R02F08-001]
- [x] CHK012 Are reversal and repeated-point cases part of the frame criteria? [Coverage, Spec §SC-R02F08-002]
- [x] CHK013 Is the batch draw measurable (one call, every part visible)? [Measurability, Clarifications Q5]

## Performance

- [x] CHK014 Is cost bounded by sample and mesh budgets rather than a clock? [Performance, plan Technical Context]

## Assumptions

- [x] CHK015 Is the build-on-change (not per frame) assumption stated? [Assumption, Spec §Assumptions]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
