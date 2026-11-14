# Journey Requirements Quality Checklist: Audio Odyssey — Phase 01

**Purpose**: Unit tests for the requirements of A07-P01 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK008).

## Completeness

- [x] CHK001 Are both phase gates (three environments on a rail; watertight joins with bounded time) required? [Spec §FR-A07-110, SC-A07-104] — yes.
- [x] CHK002 Are the two VisualCore gaps of this phase, and the two deferred to A07-P02, named? [Spec overrides, FR-A07-101–103] — yes.
- [x] CHK003 Are pause, resume and world switching specified with what stays unchanged (position, speed)? [Spec §US1 AC2, US2 AC2] — yes.

## Clarity

- [x] CHK004 Are the comfort numbers (speed, acceleration, turn rate, sway, roll, reduced-motion values, time-step cap) quantified? [Clarifications Q2] — yes.
- [x] CHK005 Is "watertight" defined with a tolerance and, for the star corridor, an equivalent rule? [SC-A07-104, Clarifications Q4] — yes.
- [x] CHK006 Is "precise near the camera" quantified for long flights? [SC-A07-103, Clarifications Q3] — yes.

## Architecture ownership

- [x] CHK007 Is the split between VisualCore (rail, comfort, rebasing) and the experience (worlds, state, UI) explicit? [Plan Constitution Check II, Project Structure] — yes.
- [x] CHK008 Are module, target, product and type names consistent and free of collisions? [Plan Project Structure, contracts/api.md] — failed at first (the adapter type `AudioOdysseyCore` shadowed the Core target's module); corrected to `OdysseyCore` with the targets named as `check_experience_packages.py` requires.
- [x] CHK009 Is drawing restricted to the host's existing pass, with no context of the experience's own? [Spec §FR-A07-121, Clarifications Q5] — yes.

## iOS lifecycle

- [x] CHK010 Are suspend/resume and large time steps after suspension specified? [Spec §Edge Cases, Plan Lifecycle] — yes.

## Privacy and release constraints

- [x] CHK011 Is it stated that the phase adds no data, permission or network use? [Spec §FR-A07-130, Plan Constitution Check VIII] — yes.
- [x] CHK012 Is the candidate (not available) registration and the absence of comfort claims specified? [Spec §FR-A07-120, 130] — yes.

## Testability and performance

- [x] CHK013 Is every success criterion tied to a runnable check? [SC-A07-101–105, quickstart] — yes.
- [x] CHK014 Is the generation-time bound measurable without a wall-clock assertion on CI? [SC-A07-104, Plan Technical Context] — yes (measured median on the host, recorded; not asserted on CI).
- [x] CHK015 Are determinism requirements (same inputs → same poses and pieces) stated for both VisualCore and the experience? [Spec §FR-A07-104, 111] — yes.

## Notes

- 15 items evaluated on 2026-11-14; CHK008 corrected in plan.md, contracts/api.md and quickstart.md before marking.
  `/speckit-implement` reads these markers and does not change them.
