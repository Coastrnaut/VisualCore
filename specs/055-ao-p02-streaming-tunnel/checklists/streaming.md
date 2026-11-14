# Streaming Requirements Quality Checklist: Audio Odyssey — Phase 02

**Purpose**: Unit tests for the requirements of A07-P02 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK004).

## Completeness

- [x] CHK001 Are both phase gates (audio-mapped geometry and lighting without hard cuts; comfort-limits fixture) required? [Spec §FR-A07-210, SC-A07-203, 204] — yes.
- [x] CHK002 Are the two VisualCore gaps (streaming window with a bounded pool; free camera and fog) specified with measurable outcomes? [Spec §FR-A07-201, 202; SC-A07-201, 202] — yes.
- [x] CHK003 Are source choice, permission states and fallback specified? [Spec §US3, FR-A07-220] — yes.

## Clarity and consistency

- [x] CHK004 Is the audio-driven geometry change described the same way in the story and in the clarification? [Spec §US1, Clarifications Q4] — failed at first (story said "ripples swell", clarification decided a draw-time radial breathing); story corrected to "widens (breathes outward around the rail)".
- [x] CHK005 Are the response bounds, rest values and per-frame step limits quantified? [Clarifications Q3] — yes.
- [x] CHK006 Are Reduce Motion and Reduce Flashing effects on the response quantified? [Spec §FR-A07-211, Clarifications Q3] — yes (halved ranges and step).

## Architecture ownership

- [x] CHK007 Is the split between VisualCore (window, pool, fog, free camera) and the experience (mapping table, response, UI) explicit, and audio reused rather than rebuilt? [Plan Constitution Check II, Project Structure] — yes.
- [x] CHK008 Are the drawing changes required to be additive, keeping existing pixels identical? [Spec §FR-A07-202, SC-A07-202] — yes.

## iOS lifecycle and privacy

- [x] CHK009 Are source start/stop and microphone release tied to activation and teardown? [Spec §Edge Cases, FR-A07-221, Plan Lifecycle] — yes.
- [x] CHK010 Is it stated that audio is analysed on the device only, never recorded or sent, and that permission is requested only when not determined? [Spec §FR-A07-220, 221] — yes.

## Testability and performance

- [x] CHK011 Is every success criterion tied to a runnable check? [SC-A07-201–206, quickstart] — yes.
- [x] CHK012 Is the streaming bound measurable (pool capacity, builds per step, reuse)? [SC-A07-201] — yes.
- [x] CHK013 Is the snapshot change versioned with a migration path from schema 1? [Plan Technical Context, data-model.md] — yes.

## Release constraints

- [x] CHK014 Are claims about sound measurement and health excluded, and audio barred from moving the camera? [Spec §FR-A07-240, Negative Requirements] — yes.
- [x] CHK015 Is the registration's microphone permission entry required? [Plan Project Structure] — yes (Catalog/registrations.json permissions).

## Notes

- 15 items evaluated on 2026-11-14; CHK004 corrected in spec.md before marking. `/speckit-implement` reads these
  markers and does not change them.
