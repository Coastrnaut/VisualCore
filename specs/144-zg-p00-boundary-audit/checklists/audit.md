# Audit Requirements Quality Checklist: Digital Zen Garden — Phase 00

**Purpose**: Unit tests for the requirements of A20-P00 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-17 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK013).

## Completeness

- [x] CHK001 Are all inventory areas of the manual's Phase 00 deliverable required (products, host, thread, shaders and resources, input path, build steps, ownership, regression)? [Spec §FR-A20-001] — yes.
- [x] CHK002 Are all five brainstorm capabilities and six version 0.1 features required in the matrix, and are the six features named somewhere a reviewer can read? [Spec §FR-A20-002, SC-A20-001, research D2] — yes.
- [x] CHK003 Is the stop/go decision required with the conditions that force "stop"? [Spec §US4 AC2, FR-A20-006] — yes (a missing host, touch input or drawable persistent render target over the existing renderer).

## Architecture ownership

- [x] CHK004 Does every gap name an owning module and phase? [Spec §FR-A20-003, SC-A20-002, research D4] — yes.
- [x] CHK005 Is the rule for "available" defined so that ownership is not claimed from another experience's code? [Clarifications Q2, Edge Cases] — yes (Fluid Art's splats, Light Maze's undo and the experiences' own stores named as experience-only).
- [x] CHK006 Are the expected gaps enumerated: document and command log, resampled strokes and preview, the sand height target and replay, relief, stones and shadows, placement and selection, undo and redo, named gardens, the low-stimulation mode, gesture alternatives, rebuild? [Spec §FR-A20-003] — yes.
- [x] CHK007 Is reuse of existing products required rather than left implicit (`pointerHandler`, `PointerVelocityTracker`, `PingPongTarget`, `FieldPass`, `FloatRenderSupport`, `SceneNode.hitTest`, `Mesh` shapes, `ExperienceStorage`)? [Clarifications facts, plan Constitution Check II] — yes.
- [x] CHK008 Are the manual's three risks recorded with an owner, a verification method and a release-blocker condition? [Spec §FR-A20-006, data-model] — yes (expensive feedback undo, touch precision at small sizes, bright effects).
- [x] CHK009 Are the negative rules complete: no EGL path or second renderer, no ProjectM, no network, no private API, no granular-physics or wellbeing claim, no generative AI, no engagement loops, no bought, generated or photographic images? [Spec §FR-A20-006] — yes.

## Consistency

- [x] CHK010 Is the undo approach consistent between the edge case, clarification Q4 and research D6 (command replay with checkpoints, never texture snapshots)? [Spec §Edge Cases, Clarifications Q4] — yes.
- [x] CHK011 Is the ownership decision for the brush-stamp pass and undo stack consistent between the clarification, research and the constitution's reuse rule (app-local now, upstream on a second user)? [Clarifications Q4, research alternatives, constitution A20] — yes.

## iOS lifecycle

- [x] CHK012 Are the host's main-thread rule, pointer cancellation on suspend, context-loss rebuild of the sand target and orientation independence required in the assessment? [Spec §FR-A20-001, FR-A20-003, plan lifecycle] — yes.

## Privacy and release constraints

- [x] CHK013 Is the absence of any permission and usage string stated for this experience? [Spec §Negative Requirements] — failed (only the research said "none"); the negative requirements now state no permission and no usage string.
- [x] CHK014 Are the quiet defaults (sound and animation off, nothing flashes) carried into a gap with an owner? [Spec §FR-A20-003, research D4] — yes (A20-P05).
- [x] CHK015 Is "nothing visible to a person" made checkable, with the registry and catalog unchanged? [Spec §FR-A20-005, SC-A20-005] — yes.
- [x] CHK016 Is the no-change rule for VisualCore and ProjectM measurable from a named commit? [Clarifications facts, SC-A20-005] — yes (`4a0ba17b`).

## Testability and performance

- [x] CHK017 Are all success criteria tied to a runnable check, with the expected registered-experience count stated? [SC-A20-001–006, quickstart] — yes (19, none A20).
- [x] CHK018 Are performance claims excluded from this phase, leaving only command-time bounds? [Spec §SC-A20-006] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
