# Requirements Quality Checklist: Effects Composer — Phase 01 core

**Purpose**: Unit tests for the Phase 01 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md), [plan.md](../plan.md), [contracts/core.md](../contracts/core.md)

`[x]` means the reviewer judged the requirement's writing satisfactory (evaluated by the lead under the owner's
standing delegation, 2026-11-19); it does not mean the work is done.

## Requirement Completeness

- [x] CHK001 Are all five effects named with every parameter's range and default? [Spec §FR-A25-101, Clarifications Q1] — yes.
- [x] CHK002 Are the chain caps (length, identifier range, uniqueness) and the history depth stated? [Spec §FR-A25-102, 103, Clarifications Q2] — yes.
- [x] CHK003 Is every edit kind defined, including the index semantics of move and what undoing a remove restores? [Spec §FR-A25-103, Clarifications Q2] — yes, after a correction (see Notes).
- [x] CHK004 Are the chain file's envelope, size cap and every refusal code listed? [Spec §FR-A25-106, Clarifications Q3] — yes.
- [x] CHK005 Is the test image defined exactly (size, channels, pattern)? [Spec §Clarifications Q4] — yes.

## Requirement Clarity and Consistency

- [x] CHK006 Is each effect's formula stated so a CPU reference can be computed without the GPU? [Spec §FR-A25-104, Clarifications Q1] — yes.
- [x] CHK007 Are the pixel tolerances quantified per effect, with the reason for the wider distort tolerance? [Spec §Clarifications Q4, research R2] — yes.
- [x] CHK008 Is "order changes output" pinned to specific effects and values that do not commute? [Spec §FR-A25-105, Clarifications Q4] — yes.
- [x] CHK009 Is it consistent that effects work on stored values now and that linear light is a later gap? [Spec §Assumptions, A25-P00 G-COLOR] — yes.

## Acceptance Criteria Quality

- [x] CHK010 Are success criteria numeric (100% of refusals, byte-identical, tolerance, under 10 s)? [Spec §SC-A25-101–106] — yes.

## Edge Cases

- [x] CHK011 Are empty, full-length, all-disabled and duplicate-effect chains, boundary values and undo or redo with nothing to do addressed? [Spec §Edge Cases] — yes.

## Non-Functional, Architecture and Lifecycle

- [x] CHK012 Is the no-graphics-in-the-core rule measurable inside the host? [Spec §FR-A25-107, Clarifications Q5] — yes.
- [x] CHK013 Is ownership clear (effects app-local, no VisualCore change, pending core without an experience target)? [Spec §Canonical overrides, Assumptions] — yes.
- [x] CHK014 Are privacy and release constraints respected (no import, export, network or bundled image)? [Spec §Negative Requirements] — yes.

## Notes

- CHK003 failed at first: the move edit's target index and the identity of a node restored by undoing a remove were
  not defined; clarification Q2 now states both.
- `/speckit-implement` reads checklist state; it does not change the markers.
