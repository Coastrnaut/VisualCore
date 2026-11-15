# Audit Requirements Quality Checklist: Neon Arcade — Phase 00

**Purpose**: Unit tests for the requirements of A10-P00 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK007).

## Completeness

- [x] CHK001 Are all inventory areas of the manual's Phase 00 deliverable (products, host, thread, shaders/resources, build steps, ownership, regression) required? [Spec §FR-A10-001] — yes.
- [x] CHK002 Are all six brainstorm capabilities and six version 0.1 features required in the matrix? [Spec §FR-A10-002, SC-A10-001] — yes.
- [x] CHK003 Is the stop/go decision required with the conditions that force "stop"? [Spec §US4 AC2, FR-A10-006] — yes (missing host or buildable drawing path).

## Architecture ownership

- [x] CHK004 Does every gap name an owning module and phase? [Spec §FR-A10-003, SC-A10-002] — yes.
- [x] CHK005 Is the rule for "available" defined so ownership is not claimed from another experience's or a harness's code (A04 particle editor, A07 tunnel collision)? [Clarifications Q2, Edge Cases] — yes.
- [x] CHK006 Are the expected gaps (2D collision with swept tests, game rules and input replay, synthesized sound playback, title/pause/game-over transitions, touch-steering sensitivity, local high scores, glow readability caps) named with owners and phases? [Spec §FR-A10-003, Clarifications Q5] — yes.
- [x] CHK007 Is the collision-tunnelling risk of fast hazards stated as an edge case with its owner and proving fixture? [Spec §Edge Cases, Clarifications Q5] — failed at first (only the clarification named swept tests); an Edge Cases bullet now records it.
- [x] CHK008 Is reuse of existing products (fixed-step clock and runner, particles, batched shapes with hit testing, tap and drag gestures, bloom, haptic and announcement planning, storage, quality tiers) required rather than left implicit? [Spec §Assumptions, Clarifications facts] — yes.
- [x] CHK009 Are negative rules (no EGL path, no second renderer, no ProjectM, no networking, no online leaderboards or user-generated levels, no loot boxes or purchasable currency, no artwork or recorded sound, no skill/reflex/cognitive/health claims) stated? [Spec §FR-A10-006] — yes.
- [x] CHK010 Is the license and provenance rule for content bundled in later phases stated? [Spec §FR-A10-006; constitution A10] — yes.

## iOS lifecycle

- [x] CHK011 Is the inventory of the host's thread rule, the session lifecycle and the fixed-step simulation required? [Spec §FR-A10-001, plan Lifecycle contracts] — yes.

## Privacy and release constraints

- [x] CHK012 Is the absence of new data, permissions and interface in this phase stated, with no permission needed for the version 0.1 features (synthesized sound, local scores)? [Spec §Edge Cases, Clarifications Q4] — yes.
- [x] CHK013 Is "nothing visible to a person" made checkable (registry and catalog unchanged)? [Spec §FR-A10-005, SC-A10-005] — yes.
- [x] CHK014 Is the no-change rule for VisualCore and ProjectM measurable from a named commit? [Clarifications facts, SC-A10-005] — yes (`8e4fcdbe`).

## Testability and measurability

- [x] CHK015 Are all success criteria tied to a runnable check, with the expected registered-experience count stated? [SC-A10-001–006, quickstart] — yes (9, none A10).

## Performance

- [x] CHK016 Are performance claims excluded from this phase, with only command-time bounds, and are the draw and readability risks recorded without measurement? [Spec §SC-A10-006, Edge Cases] — yes.

## Notes

- 16 items evaluated on 2026-11-14; CHK007 corrected in spec.md before marking. `/speckit-implement` reads these markers
  and does not change them.
