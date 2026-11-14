# Renderer and Camera Requirements Quality Checklist: Infinite Geometry — Phase 02

**Purpose**: Unit tests for the requirements of A05-P02
**Created**: 2026-11-13
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-13; failed items were corrected in the spec before continuing.

## Completeness and clarity

- [x] CHK001 Are all camera actions, their parameters and bounds stated numerically? [Spec §FR-A05-210, Clarifications Q3] — yes.
- [x] CHK002 Is the shader's input contract (motif, order, repeats, scale, camera, palette) stated? [Clarifications Q1] — yes.
- [x] CHK003 Is the symmetry of the drawn picture defined with a measurable tolerance? [SC-A05-201, Clarifications Q5] — yes.
- [x] CHK004 Is GPU/CPU fold equality defined with a measurable tolerance? [SC-A05-202] — yes.

## Consistency and ownership

- [x] CHK005 Are reusable parts (2D SDFs, fold, camera bounds) assigned to VisualCore with docs, baseline and regression? [Spec §FR-A05-220–222] — yes.
- [x] CHK006 Is the split of renderers per kind (shader for kaleidoscope, primitives for tilings, mesh for solid) consistent across spec and plan? [Spec §FR-A05-201/203, plan] — yes.

## Lifecycle, recovery and persistence

- [x] CHK007 Are shader compile failure and context recreation addressed? [Spec §Edge Cases] — yes.
- [x] CHK008 Is the migration of saved state from the Phase 01 schema (without camera) specified? [Gap, Spec §FR-A05-213 vs plan D4] — failed first: the plan's schema 2 migration was not in the spec. Corrected: FR-A05-213 now requires a schema-1 state to restore with the preset's default camera.

## Accessibility

- [x] CHK009 Does every gesture have a native alternative, and is double tap's reset also a button? [Spec §FR-A05-212, Clarifications Q4] — yes.
- [x] CHK010 Is automatic camera motion excluded (Reduce Motion)? [Spec §Edge Cases] — yes.

## Testability, performance, release

- [x] CHK011 Is every success criterion tied to a runnable host or simulator check? [SC-A05-201–206, quickstart] — yes.
- [x] CHK012 Are wall-clock assertions excluded from CI? [Spec overrides] — yes.
- [x] CHK013 Is EGL ownership in the host required? [Spec §FR-A05-231] — yes.

## Notes

- One item failed on first evaluation (CHK008); corrected in spec.md.
