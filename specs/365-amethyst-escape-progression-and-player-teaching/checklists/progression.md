# Requirements Quality Checklist: R02-G07-05 progression and player teaching

**Purpose**: Unit tests for the requirements of feature 365 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-22
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-22.

## Player impact

- [x] CHK001 Are the three tutorial instructions given word for word with the event that advances each? [Clarity, Spec
  §Clarifications Q2]
- [x] CHK002 Is what each hint level reveals (what, which shell, which exact turn or advance) stated? [Clarity, Spec
  §Clarifications Q1]

## Deterministic invariants

- [x] CHK003 Is the hint defined as the first action of a shortest escape within the moves left, so following hints
  provably wins whenever any escape fits? [Consistency, Spec §FR-R02G0705-002; Research R1]
- [x] CHK004 Are the star thresholds, unlock rule and daily formula (× 61, wrapped negative days) stated numerically?
  [Measurability, Spec §Clarifications Q3, Q4]
- [x] CHK005 Is it stated that the core reads no clock (the date arrives as an action)? [Completeness, Plan §Technical
  Context; Spec §Clarifications Q4]

## Empty and error states

- [x] CHK006 Are hints on won and failed plays, and with no escape left, defined with their texts? [Coverage, Spec §Edge
  Cases; Clarifications Q1]
- [x] CHK007 Are locked levels and impossible dates refused with named codes? [Coverage, Spec §Clarifications Q3, Q4]
- [x] CHK008 Are both failure explanations (blocked wedge, budget) given word for word? [Clarity, Spec §Clarifications
  Q5]

## Persistence and migration

- [x] CHK009 Is the schema 2 payload named field by field with the migration from schema 1? [Completeness, Spec
  §FR-R02G0705-007; Clarifications Q5]

## Source licence and code-only graphics

- [x] CHK010 Is it stated that all text and rules are original and no art, model or shader is added? [Consistency, Spec
  §Negative Requirements]

## iPad/iPhone layout

- [x] CHK011 Is it stated where the tutorial, hint and failure text appear on both device classes (wrapping panel text,
  never over the crystal)? [Coverage, Spec §Assumptions]

## Simulator proof and future D1/D2/D3 evidence

- [x] CHK012 Are the host proofs (100 levels by hints, 200 seeded states, 500 failures, 100-level progress script) and
  the simulator panel check stated, with no device item needed (no device-only behaviour in this feature)?
  [Measurability, Spec §SC-R02G0705-001 … 005; Quickstart]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- No item failed at first reading.
