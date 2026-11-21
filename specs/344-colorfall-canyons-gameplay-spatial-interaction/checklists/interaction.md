# Requirements Quality Checklist: R02-G05-04 gameplay spatial interaction

**Purpose**: Unit tests for the requirements of feature 344 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.

## Player impact

- [x] CHK001 Is it stated what each gesture does for the player (drag carves, tap toggles a valve, two fingers orbit,
  double tap resets)? [Clarity, Spec §US1–US3; Clarifications Q1–Q4]

## Deterministic invariants

- [x] CHK002 Are the distances (tap 10, drag 16, minimum target 22 points), the double-tap window (0.35 s) and the
  orbit bounds stated numerically? [Clarity, Spec §Clarifications Q1–Q4]
- [x] CHK003 Is picking defined so one touch has exactly one result, ties included? [Clarity, Spec §FR-R02G0504-003;
  Clarifications Q2]
- [x] CHK004 Is it stated that the orbit never enters the digest, snapshot or kernel? [Completeness, Spec
  §FR-R02G0504-004]

## Empty and error states

- [x] CHK005 Are cancels, second fingers, short drags and non-playing stages covered? [Coverage, Spec §Edge Cases]
- [x] CHK006 Is "send nothing" consistent with the view reset being allowed in every stage? [Consistency, Spec
  §SC-R02G0504-002; Clarifications Q3] — corrected: SC-R02G0504-002 now says no game action, and only the view may reset.

## Accessibility

- [x] CHK007 Is every gesture available through the panel, including winning every level? [Coverage, Spec
  §FR-R02G0504-006; SC-R02G0504-004]

## Source licence and code-only graphics

- [x] CHK008 Is the highlight drawn in code with no assets? [Consistency, Spec §Clarifications Q5]

## iPad/iPhone layout

- [x] CHK009 Is the orbit framing required for aspects 0.4 … 2.5? [Coverage, Spec §FR-R02G0504-004]

## Simulator proof

- [x] CHK010 Are host scripted gestures and simulator wiring tests both required, with sample sizes? [Measurability, Spec
  §SC-R02G0504-001; Clarifications Q5]

## Future D1/D2/D3 evidence

- [x] CHK011 Is touch feel and latency deferred to devices after ImplementationLock-100? [Completeness, Spec
  §SC-R02G0504-006]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
