# Navigation and Bookmarks Requirements Checklist: Fractal Explorer — Phase 03

**Purpose**: Unit-test the Phase 03 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release) before tasks.
**Created**: 2026-11-11
**Feature**: [spec.md](../spec.md)

**Ownership**: reviewer-owned. `[x]` means the reviewer judged the requirement-quality criterion satisfied, not that
code is done. Depth: standard; audience: reviewer (code-related). Clarifying questions were skipped: the prompt names
the focus areas.

## Requirement Completeness

- [x] CHK001 Are all fields a bookmark must keep listed, including the precision mode's parts? [Completeness, Spec §FR-A03-303, Data model]
- [x] CHK002 Are requirements defined for a failed bookmark write (disk full, write error)? [Gap → amended: Edge Cases]
- [x] CHK003 Are the library operations (save, rename, favorite, duplicate, delete, reload) all specified with outcomes? [Completeness, Spec §FR-A03-302]
- [x] CHK004 Is the empty state of the bookmark list specified? [Gap → amended: Edge Cases]

## Requirement Clarity

- [x] CHK005 Is "exact return" quantified (bit-exact center, 1e-12 span)? [Clarity, Spec §US2 AC1, SC-A03-301]
- [x] CHK006 Is the Go to zoom unambiguously defined relative to the spoken zoom? [Clarity, Clarifications Q1]
- [x] CHK007 Is the precision note's trigger and lifetime defined? [Clarity, Clarifications Q2]
- [x] CHK008 Are the valid ranges and error messages for Go to input stated? [Clarity, Spec §US4 AC2, research R4]

## Requirement Consistency

- [x] CHK009 Do the span-keeping resize (FR-A03-306) and the bookmark framing (FR-A03-301) use the same definition of span? [Consistency]
- [x] CHK010 Is the precision clamp on open consistent with the Phase 02 clamp (same advisor and banner text)? [Consistency, Spec §US3 AC2]
- [x] CHK011 Are the name rules identical to A01's library (60 characters, "Untitled")? [Consistency, Spec §FR-A03-302]

## Architecture Ownership

- [x] CHK012 Is every reusable piece assigned to a VisualCore module with docs, tests and a baseline entry? [Spec §FR-A03-301/302, plan]
- [x] CHK013 Is it explicit that the bookmark schema and validation stay app-local? [Spec §FR-A03-303]
- [x] CHK014 Is the decision not to change A01 now, and its follow-up, recorded? [Spec §FR-A03-302, plan Migration]
- [x] CHK015 Is EGL/context ownership kept in the VisualCore host for the aspect fixture? [Spec canonical overrides, research R5]

## Privacy and Release

- [x] CHK016 Is the storage location, and the absence of network, sharing and sync, stated? [Spec §FR-A03-303, Negative requirements]
- [x] CHK017 Is the required-reason API used by the store (file attributes, FileTimestamp) traced to the release phase's privacy manifest? [Gap → amended: Assumptions]
- [x] CHK018 Are claims about reproducing a picture on other devices excluded? [Spec §Negative requirements]

## iOS Lifecycle

- [x] CHK019 Are rotation and split-view resizes covered by the regression fixture requirement? [Spec §Edge Cases, FR-A03-306]
- [x] CHK020 Is the behavior of a library change while the sheet is open, or after relaunch, specified? [Spec §US2 AC3; Clarifications Q3 — reload on sheet open]

## Testability and Performance

- [x] CHK021 Can each success criterion be checked by an automated host, unit or UI test? [Measurability, SC-A03-301…306]
- [x] CHK022 Is a scale assumption stated for the list (≤ 500 bookmarks, lazy list)? [Spec §Edge Cases, plan Performance]
- [x] CHK023 Are damaged, newer-version and invalid-field files covered with expected outcomes? [Coverage, Spec §Edge Cases]

## Notes

- Review 2026-11-11 (delegated reviewer, CLAUDE.md §2): CHK002, CHK004 and CHK017 found gaps; the spec was amended
  (Edge Cases and Assumptions), then the items were checked. `/speckit-implement` reads these markers but does not
  change them.
