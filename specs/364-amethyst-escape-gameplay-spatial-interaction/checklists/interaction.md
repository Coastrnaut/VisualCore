# Requirements Quality Checklist: R02-G07-04 gameplay spatial interaction

**Purpose**: Unit tests for the requirements of feature 364 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-22
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-22; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is each design control (drag a shell bezel, tap to advance, double tap to isolate) mapped to exactly one
  gesture with its outcome? [Clarity, Spec §US1–US3; Clarifications Q1–Q3]
- [x] CHK002 Is the drag preview (drawn turn and its description) specified before release? [Completeness, Spec
  §FR-R02G0704-006; Clarifications Q5]

## Deterministic invariants

- [x] CHK003 Are thresholds (10, 16, 22 points; 0.35 s, 0.5 s from event timestamps) given in numbers? [Clarity, Spec
  §Clarifications Q1–Q3]
- [x] CHK004 Is the swept angle's rounding and shortest-equivalent reduction defined, including its sign convention
  against the kernel's +1? [Clarity, Spec §Clarifications Q1]
- [x] CHK005 Is it stated that orbit, isolation and preview never enter the digest, snapshot or kernel? [Consistency,
  Spec §FR-R02G0704-003, 005; SC-R02G0704-003]

## Empty and error states

- [x] CHK006 Are second fingers, cancels, finished plays, budget refusals and travel between 10 and 16 points covered?
  [Coverage, Spec §Edge Cases — the last two added 2026-11-22]
- [x] CHK007 Are refusals required to be shown and logged with their reason code? [Completeness, Spec §FR-R02G0704-008]

## Accessibility

- [x] CHK008 Does every gesture have a labelled panel equivalent, including isolation and view reset? [Coverage, Spec
  §FR-R02G0704-007]

## Source licence and code-only graphics

- [x] CHK009 Is it stated that the preview and isolation reuse generated geometry and existing programs (no assets, no
  new GLSL)? [Consistency, Plan §Constitution XIII; Research R3, R6]

## iPad/iPhone layout

- [x] CHK010 Are orbit bounds and framing defined for aspects 0.4 … 2.5? [Coverage, Spec §FR-R02G0704-005]

## Simulator proof

- [x] CHK011 Are the scripted host cases (500 seeded gestures, independent pick and angle) and the simulator wiring
  stated? [Measurability, Spec §SC-R02G0704-001; Clarifications Q5]

## Future D1/D2/D3 evidence

- [x] CHK012 Is touch feel and latency tagged `{device}` and deferred to after ImplementationLock-100? [Completeness,
  Spec §SC-R02G0704-007]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK006 failed at first reading (travel between 10 and 16 points and pearl taps on a finished play were not stated);
  the spec's Edge Cases were corrected before the items were judged.
