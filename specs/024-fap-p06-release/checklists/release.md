# Requirements Quality Checklist: Fluid Art Playground Phase 06 — privacy, packaging, recovery and release

**Purpose**: Unit tests for the Phase 06 requirements: completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance and release constraints.

**Created**: 2026-11-11

**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

**Ownership**: `[x]` means the reviewer judged that requirements-quality criterion satisfied. It does not mean the
implementation is complete. `/speckit-implement` reads these markers but never changes them.

## Requirement Completeness

- [x] CHK001 Are all manual Phase 06 deliverables (privacy strings, accessibility, assets/credits, migration, device tests, crash recovery, build/archive) mapped to requirements? [Completeness, Spec §Traceability]
- [x] CHK002 Is every owner-only release step (signing, store name, screenshots, privacy URL, App Store Connect, version bumps) listed with its owner and exact steps? [Completeness, Spec §Assumptions, FR-A02-607]
- [x] CHK003 Are the contents of each release document specified (what privacy-and-credits, store-listing, build-and-archive and the checklist must contain)? [Completeness, Spec §FR-A02-607]
- [x] CHK004 Is the behavior of captures written at the old location (before this build) specified? [Gap, Plan §Migration]

## Requirement Clarity

- [x] CHK005 Is "no personal data stored" defined as checkable facts (no app defaults keys; no files outside the capture folder)? [Clarity, Spec §FR-A02-606]
- [x] CHK006 Is the icon's provenance quantified (seed, palette, frames, size, tolerance)? [Clarity, Clarification 2, SC-A02-602]
- [x] CHK007 Is the required-reason declaration rule unambiguous (exactly the Release scan, with source-checked reasons)? [Clarity, Clarification 4, FR-A02-601]

## Requirement Consistency

- [x] CHK008 Are the capture lifetime rules consistent between feature 022 ("only the latest capture exists; removed on close") and FR-A02-605 (launch cleanup)? [Consistency]
- [x] CHK009 Do the store-claim rules (clarification 5) agree with FR-A02-609 and the home copy? [Consistency]

## Acceptance Criteria Quality

- [x] CHK010 Can "the checklist is complete" be judged mechanically (known statuses, evidence or steps per row)? [Measurability, SC-A02-605]
- [x] CHK011 Is the crash-recovery criterion measurable (3 stale files → 0; outside files untouched)? [Measurability, SC-A02-603]

## Scenario and Edge Case Coverage

- [x] CHK012 Is a missing or empty license bundle covered (what the Acknowledgements screen shows)? [Edge Case, Gap]
- [x] CHK013 Are a missing or unreadable capture folder and non-capture files in it covered? [Edge Case, Spec §Edge Cases]
- [x] CHK014 Is the Release-versus-Debug difference in the privacy scan addressed? [Edge Case, Spec §Edge Cases]

## Non-Functional: Privacy, Lifecycle, Performance, Release

- [x] CHK015 Is it stated that Debug-only automation reports are not shipped and are outside the release privacy statement? [Privacy, Gap]
- [x] CHK016 Is the launch-cleanup timing (before any scene, including automation launches) specified? [Lifecycle, Plan §Lifecycle]
- [x] CHK017 Are performance claims explicitly excluded until device evidence, with checklist rows pending? [Performance, Spec §FR-A02-609, US4]
- [x] CHK018 Are accessibility requirements extended to the new Acknowledgements screen at the largest text size? [Accessibility, Spec §US2 AC3, Edge Cases]
- [x] CHK019 Is the license and attribution scope (ANGLE, VisualCore, app, re-implemented algorithms) defined by the shared inventory, not by hand? [Licensing, Clarification 3]

## Dependencies and Assumptions

- [x] CHK020 Is the reuse of A01's source-checked reasons for ANGLE justified by the same pinned reference? [Assumption, Research R3]
- [x] CHK021 Is A01's deferred adoption of `TemporaryFolder` recorded as debt with an owner? [Dependency, Clarification 1]

## Notes

Reviewed 2026-11-11 under the owner's delegated approval (CLAUDE.md §2). The first pass found gaps in these items:
- CHK004: old-location captures;
- CHK008: capture lifetime across features 022 and 024;
- CHK012: a missing license bundle;
- CHK015: Debug-only automation reports;
- CHK016: launch-cleanup timing;
- CHK021: A01 reuse debt.

The spec was amended:
- two edge cases were added;
- FR-A02-605 now states the timing and the link to feature 022;
- a negative requirement on automation reports was added.

CHK021 is satisfied by clarification 1, and the contract records it at T-A02-610. After these amendments, 21/21 are
satisfied.
