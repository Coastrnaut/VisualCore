# Release Requirements Quality Checklist: Aurora — Phase 06

**Purpose**: Unit tests for the requirements of A21-P06 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-17 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK002).

## Completeness

- [x] CHK001 Are all stored data named (snapshot, saved choices) and is the absence of temporary files stated? [Spec §FR-A21-601, Clarifications] — yes.
- [x] CHK002 Are the place and the removal of the stored data specified? [Spec §FR-A21-601] — corrected: FR-A21-601 now names the experience's storage (replaced on each change) and removal when the app is deleted.
- [x] CHK003 Are the refused APIs of the source scan listed? [Spec §Q3, FR-A21-602] — yes.
- [x] CHK004 Are the refused words of the claims scan listed, with the shared denylist's role? [Spec §Q2, FR-A21-605] — yes.
- [x] CHK005 Are the checklist statuses and the device rows' campaign names specified? [Spec §Q1, FR-A21-606] — yes (AU-D1 … AU-D8).

## Clarity and measurability

- [x] CHK006 Is "unchanged after a failure" measurable? [Spec §SC-A21-602, Q4] — yes (byte-identical `prefs.v1`, reopen with the saved preset and sound).
- [x] CHK007 Is each sample's expected outcome stated with its code? [Spec §Q4, contracts/release.md] — yes.
- [x] CHK008 Are the first-session defaults enumerated? [Spec §US4, Q5] — yes (Polar night; sound, still, reduced flashing off).
- [x] CHK009 Are time limits stated? [Spec §SC-A21-604] — yes (10 s, 60 s).

## Consistency

- [x] CHK010 Do the spec and plan agree that `copyCheck.allow` is empty? [Spec §Clarifications, data-model] — yes.
- [x] CHK011 Is the iOS 26.x half of G-RELEASE consistently deferred to X-A21? [Spec §Canonical overrides, Plan §Constraints] — yes.

## Scenario and edge coverage

- [x] CHK012 Are newer, damaged and out-of-range stored values covered? [Spec §Edge Cases, Q4] — yes.
- [x] CHK013 Is copy about health, sleep and the sound's wording covered? [Spec §Edge Cases] — yes.
- [x] CHK014 Are device-only checks kept pending and never claimed? [Spec §Edge Cases, FR-A21-606] — yes.

## Privacy, ownership and release

- [x] CHK015 Is "no permission" consistent with the registration? [Spec §Assumptions, Clarifications] — yes (permissions `[]`).
- [x] CHK016 Are owner-only steps (signing, archive, upload) excluded and recorded? [Spec §Canonical overrides, Negative Requirements] — yes.
- [x] CHK017 Is no VisualCore change required? [Plan §Constitution Check] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
