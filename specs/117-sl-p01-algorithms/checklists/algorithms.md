# Algorithms Requirements Quality Checklist: Simulation Lab — Phase 01

**Purpose**: Unit tests for the requirements of A16-P01 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-16 (depth standard, audience reviewer); two items failed and were corrected
before this record (CHK010, CHK011).

## Completeness and clarity

- [x] CHK001 Are each family's rule, stencil, boundary and storage precision stated exactly? [Clarifications Q1–Q3, FR-A16-101–103] — yes.
- [x] CHK002 Are the stability limits quantified with the refusal sentence? [Clarifications Q2–Q3, FR-A16-111] — yes (Δt ≤ 1.5625; C ≤ 0.7071).
- [x] CHK003 Is "energy does not grow" defined measurably? [Clarifications Q3, SC-A16-103] — yes (discrete leapfrog energy within 10⁻³).
- [x] CHK004 Are the seeded starts defined for each family? [Clarifications Q1–Q3, FR-A16-112] — yes.
- [x] CHK005 Is the speed rule defined with its cap and no-burst rule? [Clarifications Q4, FR-A16-120] — yes.

## Architecture ownership

- [x] CHK006 Is reuse of the VisualCore field grid, storage precision, seeded random, parameter definitions and field passes required? [Plan Technical Context, Assumptions] — yes.
- [x] CHK007 Are all rules kept GPU-free in Core with the drawing separate? [Plan Dependency direction, FR-A16-130] — yes.

## Data and recovery

- [x] CHK008 Is the saved state's content, size limit and validation stated? [Clarifications Q5, data model] — yes.
- [x] CHK009 Are unknown versions, kinds, boundaries and grid sizes refused with a defined fallback? [FR-A16-110, Edge Cases] — yes.

## Accessibility and lifecycle

- [x] CHK010 Are accessible labels and values for the controls and a spoken state required? [Gap → FR-A16-130] — failed (only the canvas description was required); FR-A16-130 now requires labels, values and the state in the description.
- [x] CHK011 Is Reduce Motion behaviour defined for a constantly changing field? [Gap → FR-A16-130; constitution A16 accessibility] — failed (not stated); the simulation now opens paused with Reduce Motion on.
- [x] CHK012 Is context loss handled by rebuilding from the CPU field? [Edge Cases, plan Lifecycle] — yes.

## Testability and performance

- [x] CHK013 Is every success criterion measurable with a fixture? [SC-A16-101–105] — yes.
- [x] CHK014 Is the CPU cost bounded by arithmetic rather than a timing claim? [Plan Performance] — yes (64² cells × 16 iterations per host step).

## Privacy and release constraints

- [x] CHK015 Are permissions, network use and accuracy claims excluded? [Negative Requirements] — yes.
- [x] CHK016 Is the experience kept a candidate (not available) in this phase? [Canonical overrides, FR-A16-131] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
