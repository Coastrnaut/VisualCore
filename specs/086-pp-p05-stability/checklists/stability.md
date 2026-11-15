# Stability Requirements Quality Checklist: Physics Playground — Phase 05

**Purpose**: Unit tests for the requirements of A11-P05 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK006).

## Completeness

- [x] CHK001 Are both Phase 05 gates (presets under stress; deterministic replay) required with measurable outcomes? [Spec §Canonical overrides, SC-A11-501, 502] — yes.
- [x] CHK002 Are the stress scenes defined (seeds, body and spring counts, flings, level changes, length)? [Clarifications Q3] — yes.
- [x] CHK003 Are the sleep thresholds, duration and every wake trigger stated? [Clarifications Q1, contracts/stability.md] — yes.
- [x] CHK004 Is the work budget stated as countable limits, separate from host timings? [Clarifications Q2, FR-A11-503] — yes.

## Architecture ownership and lifecycle

- [x] CHK005 Is it explicit that sleep, budgets and drawing levels are app-local and that the core stores no quality tier? [Spec §Canonical overrides, Clarifications Q4] — yes.
- [x] CHK006 Is it defined whether sleeping bodies look different to the person? [Spec §Edge Cases] — failed at first (unspecified); an Edge Cases bullet now says they are drawn exactly like awake ones and the panel and description do not change.
- [x] CHK007 Are world schema 4, state schema 5 and their migration defaults required? [Clarifications Q1, plan Migration] — yes.
- [x] CHK008 Is Low Power Mode's effect (lowest drawing level, physics unchanged) specified? [Spec §Edge Cases, Clarifications Q4] — yes.

## Truthful claims and release constraints

- [x] CHK009 Are the summary text, the capability → test rule and the refused words listed? [Clarifications Q5, contracts/stability.md] — yes.
- [x] CHK010 Are performance and thermal claims excluded until device measurements, with a device plan of named rows? [Spec §Negative Requirements, FR-A11-531] — yes.
- [x] CHK011 Are declared, drawn and registered quality levels required to agree? [FR-A11-520, SC-A11-505] — yes.

## Testability and performance

- [x] CHK012 Are the stress tolerances (0 non-finite, 0 outside, ≤ 1 % energy rise per second) stated? [SC-A11-501] — yes.
- [x] CHK013 Are replay conditions (repeats, three pacings, three levels, drawn or not) enumerated? [SC-A11-502, FR-A11-510] — yes.
- [x] CHK014 Are the sleep outcomes (asleep within 3 s, 0 pair tests, same-tick wake) measurable? [SC-A11-503] — yes.
- [x] CHK015 Are wall-clock assertions on CI excluded and test durations bounded (< 10 s)? [Spec §Negative Requirements, SC-A11-506] — yes.

## Privacy

- [x] CHK016 Is it restated that no data leaves the device and no permission is added? [Spec §Negative Requirements; constitution A11] — yes.

## Notes

- 16 items evaluated on 2026-11-15; CHK006 corrected in spec.md before marking. `/speckit-implement` reads these markers
  and does not change them.
