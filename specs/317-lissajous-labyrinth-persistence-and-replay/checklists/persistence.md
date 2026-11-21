# Requirements Quality Checklist: R02-G02-07 persistence and replay

**Purpose**: Unit tests for the requirements of feature 317 (atomic save reliance, round-trip identity, migrations
1 → 2 → 3, reconcilable scores and edited saves, frontier semantics, replay rules and refusal codes, determinism,
device-only deferrals)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21.

## Saving and identity

- [x] CHK001 Is the reliance on the shared store (atomic write, quarantine, newer-schema refusal) stated rather than
  re-specified? [Consistency, Spec §Canonical overrides; Assumptions]
- [x] CHK002 Is round-trip identity defined measurably (equal digest, progress, mode, tutorial step)? [Measurability, Spec
  §US1, SC-R02G0207-001]
- [x] CHK003 Are the snapshot schema 3 fields enumerated? [Completeness, Spec §Key Entities]

## Migration

- [x] CHK004 Are both steps (1 → 2, 2 → 3) and what each adds specified? [Clarity, Spec §Clarifications Q3]
- [x] CHK005 Are damaged and newer payloads given named outcomes? [Exception Flow, Spec §Edge Cases; Clarifications Q3]

## Reconcilable scores

- [x] CHK006 Is a result's content (best actions, stars, trace, verified) and its replacement rule stated? [Clarity, Spec
  §Clarifications Q1]
- [x] CHK007 Is the reconciliation rule exact (replay wins in exactly the recorded actions with the recorded stars)?
  [Clarity, Spec §Clarifications Q2]
- [x] CHK008 Are untraced results, the dropped count and its announcement specified? [Completeness, Spec §Clarifications
  Q2]
- [x] CHK009 Is the frontier's restore rule explicit and justified? [Consistency, Spec §Clarifications Q2; Plan research
  R4]
- [x] CHK010 Are the edited-save cases (stars, actions, trace step) measurable? [Measurability, Spec §SC-R02G0207-003]

## Replay

- [x] CHK011 Are the replay actions, their preconditions and all refusal codes stated? [Completeness, Spec
  §Clarifications Q4]
- [x] CHK012 Is it stated that replay never changes progress, and what the tutorial does in replay? [Consistency, Spec
  §Clarifications Q4]
- [x] CHK013 Is replay's panel and announcement behaviour stated? [Coverage, Spec §Assumptions]

## Determinism and scope

- [x] CHK014 Are all inputs of the state named, with no clock or random source? [Clarity, Spec §Clarifications Q5;
  FR-R02G0207-005]
- [x] CHK015 Is the hardware observation of a save surviving termination deferred to D1–D3? [Traceability, Spec
  §Canonical overrides]
- [x] CHK016 Are test duration limits and the regression stated? [Non-Functional, Spec §SC-R02G0207-005]

## Notes

- `/speckit-implement` reads checklist state but does not modify markers.
