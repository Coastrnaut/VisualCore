# Device Validation Requirements Checklist: Fractal Explorer — Phase 05

**Purpose**: Unit-test the Phase 05 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release) before tasks.
**Created**: 2026-11-11
**Feature**: [spec.md](../spec.md)

**Ownership**: reviewer-owned. `[x]` means the reviewer judged the requirement-quality criterion satisfied, not that
code is done. Depth: standard; audience: reviewer. Clarifying questions were skipped: the prompt names the focus areas.

## Requirement Completeness

- [x] CHK001 Are all report fields of each app mode named? [Completeness, data model, contract]
- [x] CHK002 Is the ladder fully specified (start point, factor, step count, picture size, judged steps)? [Spec §US1, clarification 1]
- [x] CHK003 Are thermal state and other context the device campaign needs for frame-time runs required in the report? [Gap → amended: US2 AC1]
- [x] CHK004 Are the device rows of the campaign plan named with the exact devices and OS versions? [Spec §US4 AC1]

## Requirement Clarity

- [x] CHK005 Is the precision verdict unambiguous (which steps judged, threshold, clamp vs breakdown)? [Clarity, clarification 1]
- [x] CHK006 Is "frame time" qualified as CPU-side, never GPU time? [Spec §US2 AC1]
- [x] CHK007 Is the bookmark reproduction tolerance quantified (channel ±1; ≥ 99% classes on another shape)? [Spec §US3]

## Requirement Consistency

- [x] CHK008 Is the "reliable" level in the ladder the same rule the app's banner uses? [Consistency, feature 028 PrecisionMode.level]
- [x] CHK009 Do the tour mode's capture size and checks agree with Phase 04's capture rules? [Consistency, Spec §US2 AC2]

## Architecture Ownership

- [x] CHK010 Is the app-mode mechanism owned by VisualCore automation with tests, docs and baseline? [Spec §FR-A03-501]
- [x] CHK011 Is A02's automation guaranteed unaffected? [Plan, canonical override]

## Privacy and Release

- [x] CHK012 Are reports limited to non-identifying device data (model and OS, no device identifiers)? [Gap → amended: Negative requirements]
- [x] CHK013 Is the absence of automation in the shipping build a checked requirement? [Spec §FR-A03-505, SC-A03-505]
- [x] CHK014 Is the trigger restricted to the launch environment (no URL or remote input)? [Spec §Negative requirements]

## iOS Lifecycle and Evidence

- [x] CHK015 Is it explicit that simulator runs are rehearsal and no device run happens before the lock? [Spec §canonical overrides, Negative requirements]
- [x] CHK016 Is behavior for a too-small device render limit specified? [Spec §Edge Cases]

## Testability and Performance

- [x] CHK017 Can each success criterion be checked by an automated host, package, unit or simulator run? [Measurability, SC-A03-501…506]
- [x] CHK018 Is the run length of the tour mode bounded and controllable for rehearsals? [Clarification 3]

## Notes

- Review 2026-11-11 (delegated reviewer, CLAUDE.md §2): CHK003 and CHK012 found gaps; the spec was amended, then the
  items were checked. `/speckit-implement` reads these markers but does not change them.
