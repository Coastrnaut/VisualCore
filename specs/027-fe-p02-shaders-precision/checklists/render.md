# Requirements Quality Checklist: Fractal Explorer Phase 02 — GPU render, gestures, palettes and precision

**Purpose**: Unit tests for the Phase 02 requirements: completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance and release constraints.

**Created**: 2026-11-11

**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

**Ownership**: `[x]` means the reviewer judged that requirements-quality criterion satisfied. It does not mean the
implementation is complete. `/speckit-implement` reads these markers but never changes them.

## Requirement Completeness

- [x] CHK001 Are all three phase gates (pinch/pan with palettes, the centered-pinch fixture, EGL ownership) mapped to requirements? [Completeness, Spec §FR-A03-201, §FR-A03-202, §FR-A03-203]
- [x] CHK002 Are the offered palettes and the default palette named? [Gap, Spec §FR-A03-203]
- [x] CHK003 Are the precision warning's and the clamp's appearance, wording and announcement frequency specified? [Gap, Spec §FR-A03-206]

## Requirement Clarity

- [x] CHK004 Are the advisor's thresholds expressed as numbers derived from the mantissa bits? [Clarity, Clarification 2]
- [x] CHK005 Is the uniform contract (names, units, the y direction) defined? [Clarity, Clarification 3]
- [x] CHK006 Is the palette animation rate quantified? [Clarity, Spec §Assumptions]

## Requirement Consistency

- [x] CHK007 Are the pinch tolerances in US1 AC2 (1e-9 relative, 1 pixel) consistent with SC-A03-201? [Consistency]
- [x] CHK008 Is the CPU preview's new role (reference and fallback) consistent across the spec, plan and clarification 5? [Consistency]

## Acceptance Criteria Quality

- [x] CHK009 Is GPU–CPU agreement measurable (99%, 64 × 64, boundary rule)? [Measurability, Spec §FR-A03-207]
- [x] CHK010 Can the clamp behavior be verified without a device (simulator-reported bits as context)? [Measurability, Spec §SC-A03-203, §Assumptions]

## Scenario and Edge Case Coverage

- [x] CHK011 Are a finger lift mid-pinch, three fingers, shader failure, context loss and a zero-magnitude center covered? [Edge Case, Spec §Edge Cases]
- [x] CHK012 Are control alternatives defined for every gesture? [Coverage, Spec §US1 AC4]

## Non-Functional: Ownership, Lifecycle, Privacy, Performance, Release

- [x] CHK013 Is the split between VisualCore and the app explicit (precision query and advisor in VisualCore; the shader and FractalScene in the app)? [Architecture, Plan §Constitution Check]
- [x] CHK014 Are host ownership and teardown on disappear specified? [Lifecycle, Plan §Lifecycle]
- [x] CHK015 Is Reduce Motion behavior for palette animation specified? [Accessibility, Spec §US2 AC3]
- [x] CHK016 Are simulator precision values excluded as evidence? [Performance, Spec §Assumptions, §Negative]
- [x] CHK017 Is the ProjectM regression required after the RenderCapabilities change? [Release, Spec §FR-A03-208]
- [x] CHK018 Are privacy constraints (no networking, permissions or persistence) stated? [Privacy, Spec §Negative]

## Notes

Reviewed 2026-11-11 under the owner's delegated approval (CLAUDE.md §2).

The first pass found 2 gaps:
- CHK002: the palettes and the default were not named;
- CHK003: the banner's wording and announcement frequency were not specified.

FR-A03-203 now names the palettes, and FR-A03-206 now specifies the banner text, its location and an announcement
only when the state changes. After these amendments, 18/18 are satisfied.
