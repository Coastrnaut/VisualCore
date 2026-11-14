# Audit Requirements Quality Checklist: Digital Aquarium — Phase 00

**Purpose**: Unit tests for the requirements of A09-P00 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK009).

## Completeness

- [x] CHK001 Are all inventory areas of the manual's Phase 00 deliverable (products, host, thread, shaders/resources, build steps, ownership, regression) required? [Spec §FR-A09-001] — yes.
- [x] CHK002 Are all six brainstorm capabilities and six version 0.1 features required in the matrix? [Spec §FR-A09-002, SC-A09-001] — yes.
- [x] CHK003 Is the stop/go decision required with the conditions that force "stop"? [Spec §US4 AC2, FR-A09-006] — yes (missing host or buildable drawing path).

## Architecture ownership

- [x] CHK004 Does every gap name an owning module and phase? [Spec §FR-A09-003, SC-A09-002] — yes.
- [x] CHK005 Is the rule for "available" defined so ownership is not claimed from another experience's or a harness's code? [Clarifications Q2, Edge Cases] — yes.
- [x] CHK006 Are the expected gaps (bounded steering and neighbour search, fish shapes and swim animation, depth layers, bubbles and caustics, feeding and placement, persistence, ambient low-motion mode with dimming) named with owners? [Spec §FR-A09-003, Clarifications Q5] — yes.
- [x] CHK007 Is reuse of existing products (seeded fixed-step clock, particles, batched shapes, gestures, effect passes, storage, quality tiers) required rather than left implicit? [Spec §Assumptions, Clarifications facts] — yes.
- [x] CHK008 Are negative rules (no EGL path, no second renderer, no ProjectM, no networking, no artwork, no creature economy, no realism or wellbeing claims) stated? [Spec §FR-A09-006] — yes.
- [x] CHK009 Is the license and provenance rule for content bundled in later phases stated? [Spec §FR-A09-006; constitution A09 Licenses] — failed at first (only "no artwork" was stated); FR-A09-006 now requires every later species, palette, preset habitat and shader to record author and license.

## iOS lifecycle

- [x] CHK010 Is the inventory of the host's thread rule, the session lifecycle and the fixed-step simulation required? [Spec §FR-A09-001, plan Lifecycle contracts] — yes.

## Privacy and release constraints

- [x] CHK011 Is the absence of new data, permissions and interface in this phase stated, with no permission needed for the version 0.1 features? [Spec §Edge Cases, Clarifications Q4] — yes.
- [x] CHK012 Is "nothing visible to a person" made checkable (registry and catalog unchanged)? [Spec §FR-A09-005, SC-A09-005] — yes.
- [x] CHK013 Is the no-change rule for VisualCore and ProjectM measurable from a named commit? [Clarifications facts, SC-A09-005] — yes (`951802c1`).

## Testability and measurability

- [x] CHK014 Are all success criteria tied to a runnable check, with the expected registered-experience count stated? [SC-A09-001–006, quickstart] — yes (8, none A09).

## Performance

- [x] CHK015 Are performance claims excluded from this phase, with only command-time bounds, and is the draw-overhead risk recorded without measurement? [Spec §SC-A09-006, Edge Cases] — yes.

## Notes

- 15 items evaluated on 2026-11-14; CHK009 corrected in spec.md before marking. `/speckit-implement` reads these markers
  and does not change them.
