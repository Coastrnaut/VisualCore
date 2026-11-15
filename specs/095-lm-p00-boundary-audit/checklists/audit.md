# Audit Requirements Quality Checklist: Light Maze — Phase 00

**Purpose**: Unit tests for the requirements of A13-P00 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); no item failed.

## Completeness

- [x] CHK001 Are all inventory areas of the manual's Phase 00 deliverable (products, host, thread, shaders/resources, build steps, ownership, regression) required? [Spec §FR-A13-001] — yes.
- [x] CHK002 Are all five brainstorm capabilities and six version 0.1 features required in the matrix? [Spec §FR-A13-002, SC-A13-001] — yes.
- [x] CHK003 Is the stop/go decision required with the conditions that force "stop"? [Spec §US4 AC2, FR-A13-006] — yes (missing host or buildable 2D drawing path).

## Architecture ownership

- [x] CHK004 Does every gap name an owning module and phase? [Spec §FR-A13-003, SC-A13-002] — yes.
- [x] CHK005 Is the rule for "available" defined so ownership is not claimed from another experience's code (Neon Arcade glow, Oscilloscope beams, Physics Playground 2D editing)? [Clarifications Q2, Edge Cases] — yes.
- [x] CHK006 Are the expected gaps (2D ray against segments with reflection, the tile board and optical rules, bounce cap and cycle detection, beam rendering with capped glow, snapped drag and rotate, levels, progression, undo and restart, saved progress, hints and spoken descriptions, success feedback, the solvability checker) named with owners and phases? [Spec §FR-A13-003, Clarifications Q5] — yes.
- [x] CHK007 Are the manual's algorithm decisions (CPU ray/segment intersection with shader rendering as presentation only, epsilon and last-hit tracking with a bounce cap and cycle detection, monochrome first with authored colour channels, solver and replay tests) stated as edge cases or gaps with owners? [Spec §Edge Cases, Clarifications Q5] — yes.
- [x] CHK008 Is reuse of existing products (vectors, 2D transforms and camera, primitives, primitive renderer, render targets, effect graph, additive blending, gestures, accessibility planners, storage, sound effects) required rather than left implicit? [Spec §Assumptions, Clarifications facts] — yes.
- [x] CHK009 Are negative rules (no EGL path, no second renderer, no ProjectM, no networking, no refraction physics, no unvalidated level sharing, no endless procedural levels, no sprites or textures as assets, no optics-accuracy or learning claims, no shader deciding the solved state) stated? [Spec §FR-A13-006] — yes.
- [x] CHK010 Is the license and provenance rule for content bundled in later phases (levels, palettes, shaders) stated? [Spec §FR-A13-006; constitution A13] — yes.

## iOS lifecycle

- [x] CHK011 Is the inventory of the host's thread rule, the session lifecycle and GPU rebuild after context loss required? [Spec §FR-A13-001, plan Lifecycle contracts] — yes.

## Privacy and release constraints

- [x] CHK012 Is the absence of new data, permissions and interface in this phase stated, with no permission needed for the version 0.1 features? [Spec §Edge Cases, Clarifications Q4] — yes.
- [x] CHK013 Is "nothing visible to a person" made checkable (registry and catalog unchanged)? [Spec §FR-A13-005, SC-A13-005] — yes.
- [x] CHK014 Is the no-change rule for VisualCore and ProjectM measurable from a named commit? [Clarifications facts, SC-A13-005] — yes (`57a587f9`).

## Testability and measurability

- [x] CHK015 Are all success criteria tied to a runnable check, with the expected registered-experience count stated? [SC-A13-001–006, quickstart] — yes (12, none A13).

## Performance

- [x] CHK016 Are performance claims excluded from this phase, with only command-time bounds, and are content-size and glow risks recorded without measurement? [Spec §SC-A13-006, Edge Cases] — yes.

## Notes

- 16 items evaluated on 2026-11-15; none failed. `/speckit-implement` reads these markers and does not change them.
