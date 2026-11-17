# Audit Requirements Quality Checklist: Ambient Clock — Phase 00

**Purpose**: Unit tests for the requirements of A18-P00 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-16 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK010).

## Completeness

- [x] CHK001 Are all inventory areas of the manual's Phase 00 deliverable required (products, host, thread, shaders and resources, build steps, ownership, regression)? [Spec §FR-A18-001] — yes.
- [x] CHK002 Are all five brainstorm capabilities and six version 0.1 features required in the matrix, and are the six features named somewhere a reviewer can read? [Spec §FR-A18-002, SC-A18-001, research D2] — yes (research D2 lists features 01–06).
- [x] CHK003 Is the stop/go decision required with the conditions that force "stop"? [Spec §US4 AC2, FR-A18-006] — yes (a missing host, or a missing buildable text-over-shader path).

## Architecture ownership

- [x] CHK004 Does every gap name an owning module and phase? [Spec §FR-A18-003, SC-A18-002] — yes.
- [x] CHK005 Is the rule for "available" defined so that ownership is not claimed from another experience's code? [Clarifications Q2, Edge Cases] — yes (Solar System Explorer's injected clock and the audio experiences' foreground observers named as experience-only).
- [x] CHK006 Are the expected gaps enumerated: formatting with an injected date, time-change updates, four themes, readable typography, the theme editor and favourites, night mode and motion reduction, screen care and keep-awake, transitions, budgets and rebuild? [Spec §FR-A18-003] — yes.
- [x] CHK007 Is reuse of existing products required rather than left implicit (`FullScreenShaderScene`, `FieldPass`, the GLSL library, particles, `AccessibleColors`, `NamedLibrary`, `ExperienceStorage`, `QualityGovernor`, the canvas overlay)? [Spec §Assumptions, Clarifications facts] — yes.
- [x] CHK008 Are the manual's three risks recorded with an owner, a verification method and a release-blocker condition? [Spec §FR-A18-006, data-model] — yes (thermal load and burn-in, time correctness, weather permissions).
- [x] CHK009 Are the negative rules complete: no EGL path or second renderer, no ProjectM, no network, location or weather, no simulated clock in production, no screen-on guarantee, no background rendering, no bought, generated or photographic images? [Spec §FR-A18-006] — yes.

## Consistency

- [x] CHK010 Is night mode described consistently with the decision that the system brightness is never set? [Clarifications Q4, Spec §FR-A18-003] — failed (FR-A18-003 listed "brightness" as a night-mode element without qualification); FR-A18-003 now says night mode dims and warms the drawing itself and never sets the system brightness.

## iOS lifecycle

- [x] CHK011 Are foreground return, time-zone, daylight-saving, locale and significant time changes required in the assessment, together with the host's thread rule, scene phase and context-loss rebuild? [Spec §FR-A18-001, FR-A18-003, Edge Cases] — yes.
- [x] CHK012 Is the keep-awake request bounded (opt-in, off by default, released on background, close and teardown) and its scan exception limited to one named file? [Clarifications Q4] — yes.

## Privacy and release constraints

- [x] CHK013 Is the absence of new data, permissions and interface in this phase stated, and is the posture for later phases decided (no permission, no usage string, no network)? [Clarifications Q4, Negative Requirements] — yes.
- [x] CHK014 Is "nothing visible to a person" made checkable, with the registry and catalog unchanged? [Spec §FR-A18-005, SC-A18-005] — yes.
- [x] CHK015 Is the no-change rule for VisualCore and ProjectM measurable from a named commit? [Clarifications facts, SC-A18-005] — yes (`43f3eb05`).

## Testability and performance

- [x] CHK016 Are all success criteria tied to a runnable check, with the expected registered-experience count stated? [SC-A18-001–006, quickstart] — yes (17, none A18).
- [x] CHK017 Are performance claims excluded from this phase, leaving only command-time bounds? [Spec §SC-A18-006] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
