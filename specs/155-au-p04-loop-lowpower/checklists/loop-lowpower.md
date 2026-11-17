# Loop and Low-Power Requirements Quality Checklist: Aurora — Phase 04

**Purpose**: Unit tests for the requirements of A21-P04 (completeness, privacy, ownership, lifecycle, testability,
performance, release constraints)
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer (the lead, under the owner's standing delegation) judged the requirement's quality
satisfied, not that work is done. One item failed and was corrected before this record (CHK004).

## Completeness

- [x] CHK001 Are the recipe's bounds, the sample rate and the seamless rule stated? [Spec Clarifications Q1, data-model] — yes.
- [x] CHK002 Are every event that stops the player and its session category stated? [Q1, contracts/loop.md] — yes.
- [x] CHK003 Are the still view, reduced flash, fallback and target release each given a measurable test? [Q2–Q5, contracts/lowpower.md] — yes.
- [x] CHK004 Is it defined how volume is applied and that the VisualCore change is additive? [Gap, data-model] — failed; data-model now applies volume on the player node and keeps the API change additive.

## Ownership and VisualCore obligations

- [x] CHK005 Is the split between VisualCore (the loop) and the experience (low power) explicit, with its reason? [Spec overrides, research D2] — yes.
- [x] CHK006 Are rule 13's obligations (documentation, API baseline, READMEs, tests, reference regression in two chunks) all required? [Spec §FR-A21-405, 406; plan] — yes.

## Lifecycle and edge cases

- [x] CHK007 Are the silent switch, a non-finite volume and the still view with Reduce Motion covered? [Spec §Edge Cases] — yes.
- [x] CHK008 Is the fallback's own failure path defined (the clear colour, never grey)? [Q4] — yes.
- [x] CHK009 Is the clock's behaviour in the still view defined? [Q3] — yes (it holds).

## Privacy, release and constraints

- [x] CHK010 Are the microphone, permissions, recordings and the network excluded? [Spec §Negative Requirements] — yes.
- [x] CHK011 Is it explicit that the experience plays no sound in this phase? [Spec §FR-A21-407] — yes.
- [x] CHK012 Are the reduced-flash step and frame rate quantified? [Q2] — yes (< 0.02 at 30 frames per second).
- [x] CHK013 Is every test bounded in time? [Spec §SC-A21-404] — yes.
