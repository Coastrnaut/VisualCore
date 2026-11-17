# Compositing and Preferences Requirements Quality Checklist: Aurora — Phase 03

**Purpose**: Unit tests for the requirements of A21-P03 (completeness, privacy, ownership, lifecycle, testability,
performance, release constraints)
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer (the lead, under the owner's standing delegation) judged the requirement's quality
satisfied, not that work is done. One item failed and was corrected before this record (CHK007).

## Completeness

- [x] CHK001 Is every saved field listed with its range and default? [Spec Clarifications Q3, data-model] — yes.
- [x] CHK002 Are the transition's duration, easing, interruption and Reduce Motion behaviour stated? [Q1] — yes (2.0 s, smoothstep, restart from the mix, immediate).
- [x] CHK003 Are all refusal codes and their messages stated? [Q4, data-model] — yes.
- [x] CHK004 Is it stated what is deliberately not saved (quality) and why? [Q3, research D4] — yes.

## Clarity and measurability

- [x] CHK005 Is "moves steadily" measurable with sample points and a metric? [Spec §SC-A21-301, Q2] — yes.
- [x] CHK006 Is the cap during a mix justified and measured? [Clarifications facts, contract] — yes (convexity, and a read-back at 11 steps).
- [x] CHK007 Is the precedence between a restored session snapshot and the saved preferences defined? [Gap, data-model] — failed; data-model and the contract now let the snapshot win for the sky and never for the sound choice.

## Lifecycle and ownership

- [x] CHK008 Is every lifecycle event that must leave the sound choice untouched listed? [Spec §FR-A21-305, Q5] — yes.
- [x] CHK009 Is the crossfade's ownership of both skies and its behaviour on a context loss stated? [Clarifications facts, plan lifecycle] — yes.
- [x] CHK010 Is the failed-save path defined (report once, keep in memory)? [Spec §FR-A21-304, Q4] — yes.

## Privacy, release and constraints

- [x] CHK011 Is it explicit that no sound plays in this phase? [Spec §FR-A21-306] — yes.
- [x] CHK012 Are network, accounts and recordings excluded? [Spec §Negative Requirements] — yes.
- [x] CHK013 Is the saved value bounded in size? [Q3] — yes (4,096 bytes).
- [x] CHK014 Are unit tests bounded in time? [Spec §SC-A21-304] — yes.
