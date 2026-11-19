# Requirements Quality Checklist: Graphics Benchmark Lab — Phase 01 core

**Purpose**: Unit tests for the Phase 01 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md), [plan.md](../plan.md), [data-model.md](../data-model.md),
[contracts/core.md](../contracts/core.md)

`[x]` means the reviewer judged the requirement's writing satisfactory (evaluated by the lead under the owner's
standing delegation, 2026-11-19); it does not mean the work is done.

## Requirement Completeness

- [x] CHK001 Are the three built-in cases specified with every configuration value, cap and run plan? [Spec §FR-A24-101, Clarifications Q1] — yes.
- [x] CHK002 Is the percentile rule defined precisely enough to compute fixtures by hand, including minimum counts? [Spec §FR-A24-103, Clarifications Q2] — yes.
- [x] CHK003 Are every sample field, its unit and its cap specified? [Spec §Key Entities, Clarifications Q3] — yes.
- [x] CHK004 Are the run file's kind, version, size cap and every refusal code specified? [Spec §FR-A24-105, Clarifications Q4] — yes.
- [x] CHK005 Is the meaning of a dropped frame, and who decides it, specified? [Spec §Edge Cases] — yes, after a correction (see Notes).

## Requirement Clarity and Consistency

- [x] CHK006 Is it unambiguous when a GPU percentile appears (every measured sample has a GPU time)? [Spec §FR-A24-104] — yes.
- [x] CHK007 Are the interval of the first frame and the warm-up and cool-down exclusions consistent between the edge cases and the sample definition? [Spec §Edge Cases, Clarifications Q3] — yes.
- [x] CHK008 Is "fingerprint" defined (domain and covered fields) so a change is detectable? [Spec §FR-A24-101, Clarifications Q1] — yes.

## Acceptance Criteria Quality

- [x] CHK009 Are the success criteria numeric (100% of fixtures, three distinct fingerprints, unchanged host counts, under 10 s)? [Spec §SC-A24-101–106] — yes.
- [x] CHK010 Is the example 1 … 100 ms → p50 50, p95 95, p99 99 consistent with the rule and the minimum counts? [Spec §US2, Clarifications Q2] — yes (n = 100).

## Edge Cases

- [x] CHK011 Are empty, single, tied, unsorted, warm-up-only and non-finite inputs addressed? [Spec §Edge Cases, US3] — yes.
- [x] CHK012 Is a stored summary that disagrees with its samples addressed? [Clarifications Q4] — yes (`damaged`).

## Non-Functional, Architecture and Release

- [x] CHK013 Is the core's independence from graphics, clocks and interface frameworks stated and provable? [Spec §FR-A24-107, Clarifications Q5] — yes.
- [x] CHK014 Are caps bounding run length and file size stated, with no performance target or benchmark number? [Spec §Assumptions, Negative Requirements] — yes.
- [x] CHK015 Is privacy unaffected (no device data, no network) in this phase? [Spec §Negative Requirements] — yes.
- [x] CHK016 Is the experience kept unregistered (a pending core only)? [Spec §Canonical overrides] — yes.

## Notes

- CHK005 failed at first: the spec counted dropped frames but did not say who decides that a frame was dropped; the
  edge case now says the A24-P03 runner sets the flag by a rule it documents, and the core only reads it.
- `/speckit-implement` reads checklist state; it does not change the markers.
