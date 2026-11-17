# Export Requirements Quality Checklist: Living Wallpapers — Phase 01

**Purpose**: Unit tests for the requirements of A19-P01 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-17 (depth standard, audience reviewer). Two items failed and were corrected
before this record (CHK003, CHK007).

## Completeness

- [x] CHK001 Are the curated scenes, their parameters and presets named exactly, with counts and a provenance record? [Spec §FR-A19-101, Clarifications Q2] — yes (four scenes, three presets of four colours each).
- [x] CHK002 Are the templates listed with exact pixel sizes, both orientations, guides and provenance? [Spec §FR-A19-103, Q3] — yes (nine templates; guides labelled approximate design guides).
- [x] CHK003 Are all project refusals listed consistently between the requirement and the clarification? [Spec §FR-A19-102, Q4] — failed (FR-A19-102 omitted invalid-parameter); corrected.
- [x] CHK004 Is the video decision required with its interface, cost bounds, owner and result, and guarded by a scan? [Spec §FR-A19-106, Q5] — yes.

## Architecture ownership

- [x] CHK005 Are the targets, their dependencies and the direction (core → VisualCore) stated, with no GL, UIKit or SwiftUI in the core? [Q1, plan] — yes.
- [x] CHK006 Is reuse of `ExportGeometry` and the existing still encoder required rather than new fitting or encoding code? [research D2, D4] — yes.

## Consistency and clarity

- [x] CHK007 Is "the same aspect" of the fallback consistent with the even-edge rounding it reuses? [Spec §FR-A19-104, Edge Cases] — failed (FR-A19-104 said "same aspect" without the rounding); corrected to the template's aspect within the even rounding.
- [x] CHK008 Is the exact-size rule for a fitting template (odd edges kept) distinct from the fallback rule? [Q3, data-model] — yes.

## iOS lifecycle and platform

- [x] CHK009 Is it stated that nothing is drawn on screen and the GPU context stays with the host? [Spec §FR-A19-107] — yes.
- [x] CHK010 Are system-wallpaper calls, live-wallpaper wording and private APIs excluded, with how the help may still describe applying an image? [Q5, Negative Requirements] — yes.

## Privacy and release constraints

- [x] CHK011 Is the absence of permissions, storage and network in this phase stated, with storage deferred to A19-P04? [Q4, Negative Requirements] — yes.
- [x] CHK012 Is the colour profile claim limited to what is read back from the file (sRGB only in 0.1)? [Spec §FR-A19-105, Assumptions] — yes.

## Testability and performance

- [x] CHK013 Are the fixture's inputs (every template and orientation that fits, limits 2048, 4096 and 8192) and its zero-mismatch outcome measurable? [SC-A19-102, SC-A19-103, contract] — yes.
- [x] CHK014 Are the test time limits stated and measured claims excluded? [SC-A19-106] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
