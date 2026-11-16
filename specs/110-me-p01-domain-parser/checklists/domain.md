# Domain and Parser Requirements Quality Checklist: Molecular Explorer — Phase 01

**Purpose**: Unit tests for the requirements of A15-P01 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); two items failed and were corrected
before this record (CHK008, CHK013).

## Completeness

- [x] CHK001 Are all three Phase 01 gates (curated library with attributions, parser regression fixture, host owns the context) required with measurable outcomes? [Spec §Canonical overrides, SC-A15-102, SC-A15-104] — yes.
- [x] CHK002 Are the supported elements, their stored quantities, units and values enumerated? [FR-A15-101, Clarifications Q1] — yes.
- [x] CHK003 Is the source and license of every element value and every molecule stated, with the allowed licenses? [FR-A15-101, 130, Clarifications Q1, Q2] — yes.
- [x] CHK004 Are the experience's state, actions, refusals and fixtures specified? [FR-A15-131, 132, Clarifications Q5] — yes.

## Clarity and consistency

- [x] CHK005 Are every parser limit and every refusal reason quantified and named, with inclusive limits? [FR-A15-120, Clarifications Q3] — yes.
- [x] CHK006 Is the bond-inference rule quantified (sum of covalent radii plus 0.4 Å, overlap limit 0.4 Å) and its validation defined against recorded bonds? [FR-A15-111, SC-A15-103, Clarifications Q4] — yes.
- [x] CHK007 Is the formula order defined so its output is testable? [FR-A15-112] — yes (Hill order).
- [x] CHK008 Are the text-encoding edge cases (line endings, trailing spaces, final newline, byte-order mark) all decided? [Spec §Edge Cases] — failed (the byte-order mark was undecided); the edge case now accepts and ignores it.

## Architecture ownership

- [x] CHK009 Is the core free of rendering and UI dependencies, and the adapter named so it does not shadow its module? [Plan Dependency direction] — yes.
- [x] CHK010 Is reuse of the UV sphere, the lit mesh renderer, the depth pass and the orbit camera required with no upstream change, and is the VisualCore line-reader assessment recorded? [Plan, research D3] — yes.

## iOS lifecycle and edge cases

- [x] CHK011 Are GPU objects' creation, rebuild after context recreation and release together specified? [Plan Lifecycle] — yes.
- [x] CHK012 Are count mismatch, unknown or mis-cased symbols, extra columns, the comment line, overlapping atoms, single atoms and exact limits addressed? [Spec §Edge Cases] — yes.

## Accessibility and privacy

- [x] CHK013 Is information that colour carries (element identity) also given in words, with a canvas description? [FR-A15-131] — failed (no canvas description was required); FR-A15-131 now requires one naming the molecule, formula, counts and elements.
- [x] CHK014 Are no network, no import, no textures, no unlicensed data and no safety or medical claims stated? [Negative Requirements, constitution A15] — yes.

## Testability and performance

- [x] CHK015 Can every success criterion be checked without a device, with the regression fixtures named? [SC-A15-101–105, FR-A15-121, quickstart] — yes.
- [x] CHK016 Are atom, bond, mesh and pair-check counts bounded and no performance figures claimed? [Plan Technical Context, Clarifications Q4] — yes.

## Notes

- 16 items evaluated on 2026-11-15; two corrected. `/speckit-implement` reads these markers and does not change them.
