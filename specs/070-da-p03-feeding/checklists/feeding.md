# Feeding Requirements Quality Checklist: Digital Aquarium — Phase 03

**Purpose**: Unit tests for the requirements of A09-P03 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); three items failed and were
corrected in the spec before this record (CHK005, CHK012, CHK016).

## Completeness

- [x] CHK001 Are both manual Phase 03 gates (tap-to-feed with decoration placement gestures; background/resume without fast-forward) required with acceptance scenarios? [Spec §US1–US3, FR-A09-301–322] — yes.
- [x] CHK002 Are the pellet lifecycle steps (drop, sink, eat, floor removal) each specified? [Spec §FR-A09-301–302] — yes.
- [x] CHK003 Are all three gestures and their actions defined? [Spec §FR-A09-311, Clarifications Q1] — yes.
- [x] CHK004 Is a native alternative named for every gesture action? [Spec §FR-A09-312, Clarifications Q2] — yes.
- [x] CHK005 Are refusal reasons defined for every editing action? [Spec §FR-A09-310] — failed (only the feed had one); corrected: `a09.decor-full`, `a09.no-such-decor`.

## Clarity and measurability

- [x] CHK006 Are the pellet numbers quantified (per feed, limit, sink pace, eat distance, seek range)? [Spec §FR-A09-301–303] — yes.
- [x] CHK007 Are the gesture thresholds stated (tap 0.3 s, long press 0.5 s, movement 10 points)? [Clarifications facts, Q1] — yes.
- [x] CHK008 Is "a feed beside a school" measurable? [Spec §SC-A09-302, Clarifications Q5] — yes.
- [x] CHK009 Is the position mapping (tank fractions, clamping) defined? [Clarifications Q2] — yes.

## Consistency

- [x] CHK010 Is the move gesture consistent with the arbiter's one-owner rule? [Clarifications Q1, US2-2] — yes (drag a piece).
- [x] CHK011 Are the pause and suspension behaviours consistent with Phases 01–02? [Spec §Edge Cases, FR-A09-321] — yes.
- [x] CHK012 Does the saved-state requirement say how damaged new fields are handled? [Spec §FR-A09-320] — failed; corrected: out-of-range kind or > 12 pellets refused.

## Edge cases and recovery

- [x] CHK013 Are taps on the gravel, overlapping decor, removing while dragging, two fingers and in-between holds covered? [Spec §Edge Cases] — yes.
- [x] CHK014 Is the habitat change rule for pellets, decor and the chosen kind defined? [Spec §Edge Cases, Clarifications Q4] — yes.
- [x] CHK015 Are older saves (Phases 01 and 02) migration rules defined? [Spec §FR-A09-320] — yes.

## Accessibility, architecture and lifecycle

- [x] CHK016 Is the feed or edit result perceivable without sight? [Gap] — failed; corrected: FR-A09-313 (description names pellets and decor counts).
- [x] CHK017 Is gesture arbitration owned by the shared VisualCore arbiter rather than new recognizers? [Spec §FR-A09-311] — yes.
- [x] CHK018 Is graphics-context ownership kept in the host? [Spec §Canonical overrides, Negative Requirements] — yes.
- [x] CHK019 Is the no-catch-up rule after a suspension explicit? [Spec §FR-A09-321, Negative Requirements] — yes.

## Privacy, performance and release

- [x] CHK020 Does the phase add no data collection, permission or network? [Spec §Negative Requirements] — yes.
- [x] CHK021 Is per-step work bounded (12 pellets × 24 fish)? [Spec §FR-A09-301, plan] — yes.
- [x] CHK022 Are test durations bounded? [Spec §SC-A09-306] — yes.
- [x] CHK023 Are care or nutrition claims excluded? [Spec §Negative Requirements] — yes.

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
