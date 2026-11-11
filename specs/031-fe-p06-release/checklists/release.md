# Release Requirements Checklist: Fractal Explorer — Phase 06

**Purpose**: Unit-test the Phase 06 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release) before tasks.
**Created**: 2026-11-11
**Feature**: [spec.md](../spec.md)

**Ownership**: reviewer-owned. `[x]` means the reviewer judged the requirement-quality criterion satisfied, not that
code is done. Depth: release gate; audience: reviewer. Clarifying questions were skipped: the prompt names the focus.

## Requirement Completeness

- [x] CHK001 Are all release artifacts enumerated (manifest, icon, licenses, version, documents, checklist)? [Spec §US2, contract]
- [x] CHK002 Is the export-compliance declaration required? [Gap → amended: US2 AC1]
- [x] CHK003 Are owner-only store items (privacy policy URL, support URL, EULA choice, screenshots upload) listed as owner steps? [Gap → amended: Assumptions]
- [x] CHK004 Are data migration rules for future schema changes stated? [Spec §clarification 3]

## Requirement Clarity

- [x] CHK005 Is "privacy manifest from the scan" precise about categories and reasons? [Spec §US1 AC1, research R1]
- [x] CHK006 Are the forbidden claim words or rules for copy tests stated? [Research R4, Spec §US4 AC2]
- [x] CHK007 Is the icon's provenance defined well enough to re-create it? [Clarification 1]

## Requirement Consistency

- [x] CHK008 Is the Photos usage consistent with features 029 (share sheet only, never requested by the app)? [Spec §Edge Cases]
- [x] CHK009 Do crash-recovery rules agree with DocumentStore's actual leftover handling? [Clarification 2]

## Architecture Ownership

- [x] CHK010 Is it explicit that no VisualCore change is needed and which shared tools are reused? [Spec canonical overrides, plan]

## Privacy

- [x] CHK011 Are stored data after a session bounded to the bookmarks the person saved? [Spec §US1 AC2]
- [x] CHK012 Is the no-network requirement backed by a check? [Spec §US1 AC3, FR-A03-606]

## iOS Lifecycle and Release

- [x] CHK013 Are launch-time cleanup and killed-session behavior specified? [Spec §US3]
- [x] CHK014 Are device rows required to remain pending, with owner steps marked? [Spec §US4 AC3]

## Testability and Performance

- [x] CHK015 Can every success criterion be checked by an automated test or tool on the Mac? [SC-A03-601…605]
- [x] CHK016 Is any performance claim forbidden until measured on devices? [Spec §Negative requirements]

## Notes

- Review 2026-11-11 (delegated reviewer, CLAUDE.md §2): CHK002 and CHK003 found gaps; the spec was amended, then the
  items were checked. `/speckit-implement` reads these markers but does not change them.
