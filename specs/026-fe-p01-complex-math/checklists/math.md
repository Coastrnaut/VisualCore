# Requirements Quality Checklist: Fractal Explorer Phase 01 — complex-plane math, fixtures and modes

**Purpose**: Unit tests for the Phase 01 requirements: completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance and release constraints.

**Created**: 2026-11-11

**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

**Ownership**: `[x]` means the reviewer judged that requirements-quality criterion satisfied. It does not mean the
implementation is complete. `/speckit-implement` reads these markers but never changes them.

## Requirement Completeness

- [x] CHK001 Are all three phase gates (modes with explanations, known-point fixtures, EGL ownership) mapped to requirements? [Completeness, Spec §FR-A03-101, §FR-A03-103, §Negative]
- [x] CHK002 Are the four Julia samples named individually, with their expected interior or exterior result? [Gap, Spec §FR-A03-103, §SC-A03-101]
- [x] CHK003 Are the defaults (centers, widths, seed, cap, radius) stated? [Completeness, Clarification 5]

## Requirement Clarity

- [x] CHK004 Is the escape rule unambiguous (strict inequality, step numbering), with exact expected counts? [Clarity, Clarification 1]
- [x] CHK005 Is the spoken description's content and number formatting (decimal places, scientific notation for the zoom) defined? [Gap, Spec §FR-A03-101]
- [x] CHK006 Is the screen↔plane convention (origin, y direction) defined? [Clarity, Clarification 2]

## Requirement Consistency

- [x] CHK007 Do the zoom limits in the edge cases (about 1e-15) and in clarification 2 (minUnitsPerPoint 1e-15) agree? [Consistency]
- [x] CHK008 Is the boundary between CPU preview (this phase) and GPU render (Phase 02) consistent across the spec, plan and assumptions? [Consistency, Spec §FR-A03-106, Plan §Summary]

## Acceptance Criteria Quality

- [x] CHK009 Are viewport tolerances quantified (round trip 1e-9 points; anchor 1e-12 relative; scale range)? [Measurability, Spec §SC-A03-102]
- [x] CHK010 Is "the UI never blocks" turned into a bounded, testable rule (budget, stale results dropped)? [Measurability, Spec §US4, Clarification 4]

## Scenario and Edge Case Coverage

- [x] CHK011 Are non-finite inputs, zero size, and out-of-range caps and radii covered? [Edge Case, Spec §Edge Cases]
- [x] CHK012 Are Julia seeds outside |c| ≤ 2 addressed? [Edge Case, Spec §Edge Cases]

## Non-Functional: Ownership, Lifecycle, Privacy, Performance, Release

- [x] CHK013 Is the ownership split (PlaneViewport in VisualCore; formulas app-local with a CPU reference) explicit? [Architecture, Spec §FR-A03-102, §FR-A03-104]
- [x] CHK014 Is the "no render host or GPU resources in this phase" rule stated? [Lifecycle, Spec §FR-A03-106, §Negative]
- [x] CHK015 Are privacy constraints (no permissions, networking or persistence) stated? [Privacy, Spec §Negative]
- [x] CHK016 Are timing and precision claims excluded? [Performance, Plan §Technical Context, Spec §Negative]
- [x] CHK017 Are accessibility requirements (control alternative, explanation, spoken description, audit sizes) complete? [Accessibility, Spec §FR-A03-101, §SC-A03-103]
- [x] CHK018 Is the ProjectM regression required after the VisualCore addition? [Release, Spec §FR-A03-107]

## Notes

Reviewed 2026-11-11 under the owner's delegated approval (CLAUDE.md §2).

The first pass found 2 gaps:
- CHK002: the Julia samples were not individually named;
- CHK005: the spoken description's format was undefined.

FR-A03-103 now lists the four Julia samples with their expected results, and FR-A03-101 now defines the spoken
description's format. After these amendments, 18/18 items are satisfied.
