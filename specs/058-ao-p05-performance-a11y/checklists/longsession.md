# Long-session Requirements Quality Checklist: Audio Odyssey — Phase 05

**Purpose**: Unit tests for the requirements of A07-P05 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK005).

## Completeness

- [x] CHK001 Are both phase gates (persisted presets with the journey; precision at long distance) required? [Spec §FR-A07-510, 530] — yes.
- [x] CHK002 Are both VisualCore and experience gaps (streaming budget; journey announcements) specified with outcomes? [Spec §FR-A07-501, 520; SC-A07-501, 504] — yes.
- [x] CHK003 Are the three quality levels' values specified? [Clarifications Q1] — yes (ahead 8/6/4, behind 2/2/1, 110/80/50, 1/0.6/0.35).

## Clarity

- [x] CHK004 Is "long distance" quantified and the precision tolerance stated? [Spec §SC-A07-502, Clarifications Q2] — yes (10^9 units; 1e-6 domain, 1e-3 drawn).
- [x] CHK005 Is the behaviour of the streaming window on a quality level change specified? [Spec §Edge Cases, plan Lifecycle] — failed at first (the plan said "lifecycle unchanged"); the plan now states the window replacement, retirement at once and builds at most two per frame.
- [x] CHK006 Are the announcement events, interval and VoiceOver condition specified? [Clarifications Q4] — yes.

## Architecture ownership

- [x] CHK007 Is the budget placed in VisualCore and the announcer in the experience, with the reason for not sharing A06's gate? [Clarifications Q1, Q4] — yes.
- [x] CHK008 Is the VisualCore change tied to the reference regression at X-A07? [Plan Constitution Check II-a] — yes.

## iOS lifecycle and privacy

- [x] CHK009 Is persistence across close and reopen specified with the exact fields compared? [Clarifications Q5] — yes.
- [x] CHK010 Does the phase add no data collection, permission or network use? [Spec §FR-A07-540] — yes.

## Testability and performance

- [x] CHK011 Is the long session measured briefly with an arithmetic bound instead of a soak? [Spec overrides, Clarifications Q3] — yes.
- [x] CHK012 Are performance claims limited to what is measured, with device numbers deferred? [Spec §FR-A07-540, Out of Scope] — yes.
- [x] CHK013 Is every success criterion tied to a runnable check? [SC-A07-501–506, quickstart] — yes.

## Accessibility and release

- [x] CHK014 Are accessibility audits explicitly deferred to the device campaign while announcements are tested here? [Spec overrides] — yes.
- [x] CHK015 Is the quality tier registration in the catalog required? [Plan Project Structure] — yes.

## Notes

- 15 items evaluated on 2026-11-14; CHK005 corrected in plan.md before marking. `/speckit-implement` reads these
  markers and does not change them.
