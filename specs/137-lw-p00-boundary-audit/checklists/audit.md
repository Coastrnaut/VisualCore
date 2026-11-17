# Audit Requirements Quality Checklist: Living Wallpapers — Phase 00

**Purpose**: Unit tests for the requirements of A19-P00 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-17 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK013).

## Completeness

- [x] CHK001 Are all inventory areas of the manual's Phase 00 deliverable required (products, host, thread, shaders and resources, build steps, ownership, regression)? [Spec §FR-A19-001] — yes.
- [x] CHK002 Are all five brainstorm capabilities and six version 0.1 features required in the matrix, and are the six features named somewhere a reviewer can read? [Spec §FR-A19-002, SC-A19-001, research D2] — yes.
- [x] CHK003 Is the stop/go decision required with the conditions that force "stop"? [Spec §US4 AC2, FR-A19-006] — yes (a missing host, or no offscreen render-and-read-back path over the existing renderer).

## Architecture ownership

- [x] CHK004 Does every gap name an owning module and phase? [Spec §FR-A19-003, SC-A19-002, research D4] — yes.
- [x] CHK005 Is the rule for "available" defined so that ownership is not claimed from another experience's code? [Clarifications Q2, Edge Cases] — yes (the five experiences' `ShareLink` paths named as experience-only).
- [x] CHK006 Are the expected gaps enumerated: backgrounds and presets, templates and guides, offscreen output, size limits and fallback, encoding with a colour profile, video feasibility, export job and history, saving and sharing, applying instructions, rebuild? [Spec §FR-A19-003] — yes.
- [x] CHK007 Is reuse of existing products required rather than left implicit (`renderOffscreen`, `maxRenderSize`, `StillImage`, `StillImageEncoder`, `ExportGeometry`, `ResourceBudget`, `TemporaryFolder`, `ExperienceStorage`)? [Clarifications facts, plan Constitution Check II] — yes.
- [x] CHK008 Are the manual's three risks recorded with an owner, a verification method and a release-blocker condition? [Spec §FR-A19-006, data-model] — yes (restricted wallpaper behaviour, out-of-memory at very high resolution, video encoding cost).
- [x] CHK009 Are the negative rules complete: no EGL path or second renderer, no ProjectM, no network, no private API, no automatic wallpaper setting, no live-wallpaper claim, no unbounded size, no bought, generated or photographic images? [Spec §FR-A19-006] — yes.

## Consistency

- [x] CHK010 Are the size rules consistent between the edge case, FR-A19-003 and the clarification (no tiling in 0.1; refusal before allocation with a fallback)? [Clarifications Q5, Spec §FR-A19-003] — yes.
- [x] CHK011 Is the Photos posture consistent across the constitution, clarification and edge cases (share sheet, add-only string, no PhotoKit, no read access)? [Clarifications Q4, constitution A19] — yes.

## iOS lifecycle

- [x] CHK012 Are the host's main-thread rule, memory warnings, context-loss rebuild and the offscreen path's restoration of the live scene required in the assessment? [Spec §FR-A19-001, FR-A19-003, plan lifecycle] — yes.

## Privacy and release constraints

- [x] CHK013 Is behaviour defined when the person declines Photos access (least privilege with a useful fallback, manual §13)? [Spec §Edge Cases] — failed (no requirement covered a declined permission); the edge case now says only that destination is refused and Files or another app still receive the file.
- [x] CHK014 Is the absence of new data, permissions and interface in this phase stated, with the later permission word and its release step named? [Clarifications Q4, Negative Requirements] — yes (`photo-library-add`, A19-P04; `app-usage-descriptions`).
- [x] CHK015 Is "nothing visible to a person" made checkable, with the registry and catalog unchanged? [Spec §FR-A19-005, SC-A19-005] — yes.
- [x] CHK016 Is the no-change rule for VisualCore and ProjectM measurable from a named commit? [Clarifications facts, SC-A19-005] — yes (`530855ef`).

## Testability and performance

- [x] CHK017 Are all success criteria tied to a runnable check, with the expected registered-experience count stated? [SC-A19-001–006, quickstart] — yes (18, none A19).
- [x] CHK018 Are performance claims excluded from this phase, leaving only command-time bounds? [Spec §SC-A19-006] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
