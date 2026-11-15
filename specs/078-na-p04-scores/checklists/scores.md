# Scores Requirements Quality Checklist: Neon Arcade — Phase 04

**Purpose**: Unit tests for the requirements of A10-P04 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK011).

## Completeness

- [x] CHK001 Are the Phase 04 gates (configurable touch sensitivity; high score survives abrupt termination; context ownership in the host) required with acceptance scenarios? [Spec §US1, §US2, FR-A10-401, 411] — yes.
- [x] CHK002 Are the five steps and their reaches given in numbers, with a default? [Clarifications Q1] — yes.
- [x] CHK003 Are the table's fields, limits, ordering, tie rule and dedupe rule defined? [Clarifications Q2, FR-A10-410, 412] — yes.
- [x] CHK004 Are the announcement texts, triggers and rate defined? [Clarifications Q4, FR-A10-420] — yes.

## Clarity and measurability

- [x] CHK005 Is "not corrupted" made measurable with a defined interrupted-save setup? [Clarifications Q3, SC-A10-402] — yes.
- [x] CHK006 Is "ordered gentle → sharp" measurable for the same offset? [SC-A10-401] — yes.
- [x] CHK007 Are the UI test journeys named? [Clarifications Q5, FR-A10-422] — yes.

## Exception and recovery flows

- [x] CHK008 Are damaged, newer and refused-storage cases specified with what the person sees? [Spec §US2 AC3, Edge Cases] — yes.
- [x] CHK009 Is migration of schema-3 (and older) saved games specified with defaults? [Clarifications Q1, Edge Cases] — yes.

## Architecture ownership

- [x] CHK010 Is it stated that all of this is app-local and VisualCore is unchanged? [Spec overrides, plan] — yes.

## Privacy and release constraints

- [x] CHK011 Is it stated where the scores are stored, what they contain and how they are removed? [Spec §Edge Cases, Clarifications Q2] — failed at first (contents and "no personal data" were stated, removal was not); an edge case now names the experience's own storage, removal by the app's reset and the A10-P06 privacy document.
- [x] CHK012 Are network, accounts, online leaderboards and personal data excluded? [Negative Requirements, Out of Scope] — yes.

## Accessibility

- [x] CHK013 Are labels, values, Dynamic Type, spoken state and native alternatives required? [FR-A10-402, 421] — yes.
- [x] CHK014 Is announcement flooding bounded? [SC-A10-404] — yes (≤ 1 per second, pickups silent).

## Testability and performance

- [x] CHK015 Is every success criterion tied to a runnable check with time bounds (UI tests < 60 s)? [SC-A10-401–406, quickstart, plan] — yes.
- [x] CHK016 Is storage I/O bounded and kept off the step and render path? [plan Lifecycle and Performance] — yes (one read per open, one write per finished run, ≤ 2 KB).

## Notes

- 16 items evaluated on 2026-11-14; CHK011 corrected in spec.md before marking. `/speckit-implement` reads these markers
  and does not change them.
