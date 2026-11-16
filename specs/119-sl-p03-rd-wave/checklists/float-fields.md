# Float Fields Requirements Quality Checklist: Simulation Lab — Phase 03

**Purpose**: Unit tests for the requirements of A16-P03 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-16 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK008).

## Completeness and clarity

- [x] CHK001 Is the GPU encoding of both float families (channels, boundary) stated? [Clarifications Q1, FR-A16-301–302] — yes.
- [x] CHK002 Is the tolerance quantified with grid, step count and both half roundings? [Clarifications Q2, SC-A16-301] — yes (16 × 16, 10 steps, 0.01).
- [x] CHK003 Are the reload triggers and interval enumerated? [Clarifications Q3, FR-A16-303] — yes (64 steps and every non-step change).
- [x] CHK004 Are the time-step limits, declared range, rule codes and sentences stated per family? [Clarifications Q4, FR-A16-330] — yes.
- [x] CHK005 Is the effect of an accepted time step on field, step count, running and speed defined? [FR-A16-330] — yes (all kept).

## Privacy

- [x] CHK006 Is it stated that the phase adds no permission, network or stored data beyond the existing state? [Negative Requirements, plan Constitution VIII] — yes.

## Architecture ownership

- [x] CHK007 Is reuse of VisualCore types required with no VisualCore change, and is the device-dependent refusal placed outside the deterministic core? [Assumptions, plan Summary] — yes.

## Accessibility and presentation

- [x] CHK008 Are the legend's placement, legibility and VoiceOver treatment specified? [FR-A16-320] — failed (only its content was stated); FR-A16-320 now places it on an opaque panel at the bottom-leading corner, in the caption style with Dynamic Type, hidden from VoiceOver because the description carries the values.
- [x] CHK009 Are refusals both shown and announced? [FR-A16-330] — yes (message line, announced).

## iOS lifecycle

- [x] CHK010 Are context recreation, resize and restore covered, including a restore without float support? [FR-A16-303, FR-A16-310, Edge Cases] — yes.
- [x] CHK011 Is the failure of a step program or an incomplete target defined? [Edge Cases] — yes (the session fails through the host).

## Testability and performance

- [x] CHK012 Is the wave border requirement measurable? [SC-A16-302] — yes (100 % of edge cells after 100 steps).
- [x] CHK013 Is the no-support case testable without special hardware? [Clarifications Q5] — yes (forced test seam).
- [x] CHK014 Is the GPU work per frame bounded? [plan Performance] — yes (≤ 128 steps, one reload upload).

## Release constraints

- [x] CHK015 Are accuracy claims beyond the stated tolerance and any 8-bit fallback excluded? [Negative Requirements, FR-A16-310] — yes.
- [x] CHK016 Is graphics context ownership kept in the host? [Traceability] — yes.

## Notes

`/speckit-implement` reads this checklist and does not change its markers.
