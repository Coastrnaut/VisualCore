# Requirements Quality Checklist: R02-F15 conic orbits and eclipses

**Purpose**: Unit tests for the requirements of feature 215 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-19; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is the player-visible promise (bodies on paths, scrubbed time, eclipses and transits) stated as measurable
  positions, phases and verdicts? [Measurability, Spec §SC-R02F15-001…005]

## Deterministic invariants

- [x] CHK002 Are solver tolerances and step bounds stated for each conic kind? [Clarity, Spec §Clarifications Q2]
- [x] CHK003 Is drift-free stepping defined (time from the tick, never accumulated)? [Clarity, Spec §Clarifications Q3]
- [x] CHK004 Is "each passage reported once" defined by half-open spans? [Clarity, Spec §Clarifications Q3]
- [x] CHK005 Are the class thresholds, including touching and nested disks, unambiguous? [Clarity, Spec
  §Clarifications Q4; Edge Cases]

## Empty and error states

- [x] CHK006 Do invalid elements, steps, ticks, disks, observers inside bodies, too-large spans, newer schemas and damaged
  data each have a reason code? [Coverage, Spec §Clarifications Q5] — corrected: span limit and reversed spans added to
  the edge cases.
- [x] CHK007 Is non-finite time given an outcome? [Edge Case, data-model OrbitState]

## Source licence and code-only graphics

- [x] CHK008 Are the formulas' sources (Kepler, Barker, lens area) named, with no body data, asset or GPU work?
  [Consistency, research R1–R8; Spec §Negative Requirements]

## iPad/iPhone layout

- [x] CHK009 Is it stated that drawing, controls and layout belong to the consuming experiences? [Completeness, Spec
  §Assumptions]

## Simulator proof

- [x] CHK010 Is the regression on the simulators required although nothing renders? [Consistency, plan Testing; Spec
  §SC-R02F15-006]

## Future D1/D2/D3 evidence

- [x] CHK011 Is it stated that no device item exists in this slice and frame time is measured by the consumers in the
  device campaign after ImplementationLock-100? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
