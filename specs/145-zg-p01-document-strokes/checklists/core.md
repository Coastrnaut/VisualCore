# Core Requirements Quality Checklist: Digital Zen Garden — Phase 01

**Purpose**: Unit tests for the requirements of A20-P01 (completeness, privacy, architecture ownership, lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-17 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK008).

## Completeness

- [x] CHK001 Are the document's contents (tray, tone, stones, strokes) and its coordinate space defined? [Spec §FR-A20-101, Q1] — yes (normalized, 4:3, tray widths).
- [x] CHK002 Are every refusal code and its trigger listed? [Spec §FR-A20-102, data-model] — yes (nine codes).
- [x] CHK003 Are the caps quantified (points, strokes, stones, bytes)? [Spec §Q2] — yes (512, 400, 24, 262,144).
- [x] CHK004 Are both rake styles and all five stone kinds defined with their numbers? [Spec §FR-A20-104, Q3] — yes.
- [x] CHK005 Are the command kinds and what each records for an exact undo defined? [Spec §Q4] — yes.

## Clarity and measurability

- [x] CHK006 Is "no gap" quantified with the spacing and a numeric tolerance? [Spec §SC-A20-102, Q2] — yes (0.004 + 1e-9).
- [x] CHK007 Is "within tolerance" for the rebuilt sand quantified? [Spec §SC-A20-103, Q4] — yes (1e-6 per cell).

## Edge cases

- [x] CHK008 Are stone commands on missing ids and out-of-range stone values covered? [Spec §Edge Cases] — failed (only unknown kinds were); the edge cases now refuse missing ids and out-of-range position, rotation and scale.
- [x] CHK009 Are single-point, repeated-point, non-finite and out-of-tray inputs covered? [Spec §Edge Cases, Q2] — yes.
- [x] CHK010 Are empty undo and empty redo covered? [Spec §Edge Cases] — yes.

## Architecture ownership

- [x] CHK011 Is it stated that the rules stay app-local and VisualCore is unchanged, with the reason? [Spec §Overrides, plan II, research D2] — yes.
- [x] CHK012 Is the dependency direction stated (core → VisualCore products only)? [Plan §Project Structure] — yes.

## Privacy, lifecycle and release constraints

- [x] CHK013 Are network, clock and GPU calls excluded from the core? [Spec §FR-A20-107] — yes.
- [x] CHK014 Is the absence of timestamps in the document stated, so no time is stored? [Spec §Q4] — yes.
- [x] CHK015 Is it stated that nothing is registered or visible in this phase? [Spec §Overrides, Q5] — yes.

## Testability and performance

- [x] CHK016 Is every success criterion tied to a runnable check with a time bound? [Spec §SC-A20-101–105, quickstart] — yes (each test under 10 s).
- [x] CHK017 Is the replay's worst-case size bounded by arithmetic? [Plan §Technical Context] — yes (51,200 footprints).

## Notes

- `/speckit-implement` reads these markers and does not change them.
