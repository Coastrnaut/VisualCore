# Experience Requirements Quality Checklist: Ambient Clock — Phase 02

**Purpose**: Unit tests for the requirements of A18-P02 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-16 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK012).

## Completeness

- [x] CHK001 Are every action, its values and its ranges specified? [Clarification Q2, data-model] — yes.
- [x] CHK002 Are the theme's palette, noise parameters and motion rule specified? [Clarification Q3, research D3–D4] — yes.
- [x] CHK003 Is the overlay layout (sizes, fit, date style) specified? [Clarification Q4, research D5] — yes.

## Architecture ownership

- [x] CHK004 Is it stated that the experience core holds numbers only and that locale and zone enter only in the presenter? [Clarification Q1, research D1] — yes.
- [x] CHK005 Is the presenter's ownership of the shader scene through the host's context stated, with no context code in the experience? [Spec §Overrides, plan lifecycle] — yes.
- [x] CHK006 Is the frame-rate cap's absence explained and assigned (G-FRAMERATE, A18-P04)? [Spec §FR-A18-208, Clarification facts] — yes.

## iOS lifecycle

- [x] CHK007 Are the monitor's start and stop and the tick task's cancellation tied to setup, teardown and the overlay's lifetime? [plan lifecycle] — yes.
- [x] CHK008 Are a failed draw and a lost context addressed with the time staying correct? [Spec §Edge Cases] — yes.
- [x] CHK009 Is the time-zone regression fixture described with its inputs and expected output? [Spec §US2, contracts/experience.md] — yes.

## Accessibility and privacy

- [x] CHK010 Are the contrast threshold, Dynamic Type sizing, the canvas label and Reduce Motion each specified measurably? [Spec §FR-A18-204, 205, 207] — yes.
- [x] CHK011 Is the absence of permissions, network, keep-awake and brightness change stated? [Spec §Negative Requirements] — yes.

## Measurability

- [x] CHK012 Are the fixtures behind "100 % of the fixtures" named? [Spec §SC-A18-201] — failed (the fixtures were not named); SC-A18-201 now lists the zones, hour cycles, seconds and date settings.
- [x] CHK013 Are the budgets per level stated in numbers? [Clarification Q3, data-model] — yes (octaves 5 and 3, resolution shares 1 and 0.5, one draw).
- [x] CHK014 Is every success criterion tied to a runnable check under the 10-second bound? [SC-A18-201–205, quickstart] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
