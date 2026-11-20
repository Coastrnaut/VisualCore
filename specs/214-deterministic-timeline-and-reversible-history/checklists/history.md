# Requirements Quality Checklist: R02-F14 reversible timeline

**Purpose**: Unit tests for the requirements of feature 214 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-19; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is the player-visible promise (scrub back and forth, edit the past, same result every time) stated as
  measurable seeks and edits? [Measurability, Spec §SC-R02F14-001, 002]

## Deterministic invariants

- [x] CHK002 Is the command timing (before step s → s + 1, insertion order) stated? [Clarity, Spec §Clarifications Q2]
- [x] CHK003 Is the replay hash defined exactly (domain, byte order, chaining)? [Clarity, Spec §Clarifications Q4]
- [x] CHK004 Is how a non-deterministic simulation is detected and reported defined? [Gap → Spec §Edge Cases] —
  corrected: snapshot or stored hash mismatch, `r2-f14.hash-mismatch`, timeline unchanged.

## Empty and error states

- [x] CHK005 Are negative and too-large steps, full logs, bad ring settings, missing commands, newer and damaged stored
  runs each given a reason code? [Coverage, Spec §Clarifications Q5]
- [x] CHK006 Are an empty log and a dropped snapshot given outcomes? [Edge Case, Spec §Edge Cases]

## Source licence and code-only graphics

- [x] CHK007 Is the hash's source (SHA-256 through the existing helper) named, and is there no asset or GPU work?
  [Consistency, research R3; Spec §Negative Requirements]

## iPad/iPhone layout

- [x] CHK008 Is it stated that scrubbing controls and layout belong to the consuming experiences? [Completeness, Spec
  §Assumptions]

## Simulator proof

- [x] CHK009 Is the regression on the simulators required although nothing renders? [Consistency, plan Testing; Spec
  §SC-R02F14-006]

## Future D1/D2/D3 evidence

- [x] CHK010 Is the device-only item (rewind time of a long run) named and deferred to after ImplementationLock-100?
  [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
