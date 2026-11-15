# Experiments Requirements Quality Checklist: Physics Playground — Phase 04

**Purpose**: Unit tests for the requirements of A11-P04 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK011).

## Completeness

- [x] CHK001 Are both Phase 04 gates (pause, step, time scale and reset restoring the experiment; bounded spring energy) required with measurable outcomes? [Spec §Canonical overrides, SC-A11-401, 404] — yes.
- [x] CHK002 Are the three presets and free play specified with their bodies, springs, sizes and settings? [Clarifications Q1] — yes.
- [x] CHK003 Are both tutorials specified step by step with the condition that completes each step? [Clarifications Q4] — yes.
- [x] CHK004 Are the saved file's name, schema, fields and refusal reasons specified? [Clarifications Q3, contracts/experiments.md] — yes.

## Architecture ownership

- [x] CHK005 Is it explicit that presets, tutorials and the store are app-local over ExperienceStorage and the shell's restore, with no VisualCore change? [Spec §Canonical overrides, plan] — yes.
- [x] CHK006 Is the split between replayable actions (preset, tutorial) and storage operations outside the replay (save, open, clear) stated? [Clarifications Q2, research D3] — yes.

## iOS lifecycle and persistence

- [x] CHK007 Are schema 4, its fields and the 3 → 4 migration defaults required? [Clarifications Q5, FR-A11-430] — yes.
- [x] CHK008 Is the behaviour for damaged, truncated, newer and empty slots defined, with files left untouched? [FR-A11-403, SC-A11-402] — yes.
- [x] CHK009 Is a failed or unavailable storage write defined to change nothing? [Spec §Edge Cases] — yes.

## Privacy

- [x] CHK010 Is it stated that experiments stay in the experience's own storage, with no network, account or sharing, and how they are removed (clearing a slot)? [Spec §Negative Requirements, FR-A11-403] — yes.

## Edge cases and UX

- [x] CHK011 Is it defined how the person learns that opening a preset replaces unsaved edits? [Spec §Edge Cases] — failed at first ("is told before" was undefined); the preset picker now always shows a note that opening a preset replaces the current experiment and to save first, with no dialog.
- [x] CHK012 Are grabs and selections excluded from saved experiments, and slot names bounded? [Spec §Edge Cases] — yes.

## Accessibility and licenses

- [x] CHK013 Are tutorial steps spoken and every new control labelled? [Clarifications Q4, Spec §Edge Cases] — yes.
- [x] CHK014 Are presets and tutorial texts required in the content license document? [FR-A11-431] — yes.

## Testability and performance

- [x] CHK015 Are the energy tolerances (0.5 %/s rise, end below start; 5 % band) and run lengths (1,200 and 600 ticks) stated? [SC-A11-404, Clarifications Q5] — yes.
- [x] CHK016 Are the fixtures named and per-test duration bounded (< 10 s)? [research D5, SC-A11-405] — yes.

## Notes

- 16 items evaluated on 2026-11-15; CHK011 corrected in spec.md before marking. `/speckit-implement` reads these markers
  and does not change them.
