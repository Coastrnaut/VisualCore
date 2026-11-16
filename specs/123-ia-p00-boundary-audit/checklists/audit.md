# Audit Requirements Quality Checklist: Interactive Anatomy — Phase 00

**Purpose**: Unit tests for the requirements of A17-P00 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-16 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK010).

## Completeness

- [x] CHK001 Are all inventory areas of the manual's Phase 00 deliverable required (products, host, thread, shaders and resources, build steps, ownership, regression)? [Spec §FR-A17-001] — yes.
- [x] CHK002 Are all five brainstorm capabilities and six version 0.1 features required in the matrix? [Spec §FR-A17-002, SC-A17-001] — yes.
- [x] CHK003 Is the stop/go decision required with the conditions that force "stop"? [Spec §US4 AC2, FR-A17-006] — yes (a missing host, or a missing buildable lit, depth-tested mesh path).

## Architecture ownership

- [x] CHK004 Does every gap name an owning module and phase? [Spec §FR-A17-003, SC-A17-002] — yes.
- [x] CHK005 Is the rule for "available" defined so that ownership is not claimed from another experience's code? [Clarifications Q2, Edge Cases] — yes (Molecular Explorer's picking and Solar System Explorer's `LabelLayout` named).
- [x] CHK006 Are the expected gaps enumerated: procedural geometry, the structure graph, layers with isolate and ghost, picking, anchored labels with overlap, search, camera framing, materials, cited text, the content pack, saved view, budgets and rebuild? [Spec §FR-A17-003] — yes.
- [x] CHK007 Is reuse of existing products required rather than left implicit (`Mesh`, `MeshRenderer`, `OrbitCamera`, `CameraBounds`, `RayIntersection`, the canvas overlay, persistence, experience storage)? [Spec §Assumptions, Clarifications facts] — yes.
- [x] CHK008 Are the manual's three risks recorded with an owner, a verification method and a release-blocker condition? [Spec §FR-A17-006] — yes.
- [x] CHK009 Are the negative rules complete: no EGL path or second renderer, no ProjectM, no network, no medical claim, no health data, no bought or modelled assets, no unsourced text? [Spec §FR-A17-006] — yes.

## Content and claims

- [x] CHK010 Is the clinical review of the content stated as a person's action, with the label that applies until it is done? [Clarifications Q5] — failed (the spec named the sources but not where the review is recorded); FR-A17-006 now records it as a `negative` rule with owner `owner-action`.

## iOS lifecycle

- [x] CHK011 Is the inventory of the host's thread rule, the session lifecycle and target rebuild after context loss required? [Spec §FR-A17-001] — yes.

## Privacy and release constraints

- [x] CHK012 Is the absence of new data, permissions and interface in this phase stated, and is the posture for later phases decided (bundled content, no usage string)? [Clarifications Q4] — yes.
- [x] CHK013 Is "nothing visible to a person" made checkable, with the registry and catalog unchanged? [Spec §FR-A17-005, SC-A17-005] — yes.
- [x] CHK014 Is the no-change rule for VisualCore and ProjectM measurable from a named commit? [Clarifications facts, SC-A17-005] — yes (`f437fd0b`).

## Testability and performance

- [x] CHK015 Are all success criteria tied to a runnable check, with the expected registered-experience count stated? [SC-A17-001–006, quickstart] — yes (16, none A17).
- [x] CHK016 Are performance claims excluded from this phase, leaving only command-time bounds? [Spec §SC-A17-006] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
