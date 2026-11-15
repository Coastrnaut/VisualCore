# Model Requirements Quality Checklist: Physics Playground — Phase 01

**Purpose**: Unit tests for the requirements of A11-P01 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK007).

## Completeness

- [x] CHK001 Are both Phase 01 gates (circles and boxes with rigid-body collision; two-body elastic momentum fixture) required with measurable outcomes? [Spec §Canonical overrides, FR-A11-101, 102, SC-A11-102] — yes.
- [x] CHK002 Are all version 0.1 features in this phase's scope (01, 02 without springs, 04) mapped to requirements, and are the others explicitly deferred? [Spec §Traceability, Out of Scope] — yes.
- [x] CHK003 Are units, stage size, tick, defaults and caps stated as numbers? [Clarifications Q1] — yes (metres, kg/m², s, rad; 10 × 8 m; 1/120 s; caps 40 m/s, 40 rad/s, 48 bodies).
- [x] CHK004 Are the starting scene and every action with its range and refusal code specified? [Clarifications Q4, FR-A11-112] — yes.

## Architecture ownership

- [x] CHK005 Is the split between generic VisualCore code (contacts, solver) and app-local code (world, materials, scene, diagnostics) explicit, with the gap each closes? [Spec §Canonical overrides, FR-A11-101–114] — yes.
- [x] CHK006 Are the solver semantics (normal direction, touching tolerance, restitution and friction combination, threshold, slop, correction, iterations, static bodies) defined precisely enough to test? [Clarifications Q2] — yes.
- [x] CHK007 Are the restitution and friction of the walls and the ledge defined? [Spec §Edge Cases] — failed at first (walls had no material); an Edge Cases bullet now gives walls restitution 0 and friction 0.5 and the ledge the steel material, and states the momentum fixture's test material.
- [x] CHK008 Is the reference regression for the VisualCore change scheduled, with documentation and the API baseline required? [FR-A11-103] — yes (X-A11).

## iOS lifecycle and persistence

- [x] CHK009 Are suspension without catch-up, save/restore identity and refusal of damaged or newer data required? [Spec §US3, Clarifications Q5] — yes.
- [x] CHK010 Is it stated that drawing and the quality level never change the world? [Spec §US2 AC5, Negative Requirements] — yes.

## Privacy and release constraints

- [x] CHK011 Are no permission, no network and no collected data stated? [Spec §Negative Requirements] — yes.
- [x] CHK012 Are licenses required for every material with named refusal reasons and a generated document? [FR-A11-114, Clarifications Q3] — yes.
- [x] CHK013 Are claims limited to educational approximations wherever diagnostics are shown? [FR-A11-113] — yes.

## Accessibility

- [x] CHK014 Do all actions have native controls with VoiceOver labels and values, and a spoken description of the world? [FR-A11-120, 121] — yes.

## Testability and measurability

- [x] CHK015 Are the analytic tolerances (free fall 1 %, momentum 1e-9 relative, velocity exchange 2 %, static body displacement exactly 0) stated? [SC-A11-102, 103] — yes.
- [x] CHK016 Are determinism and frame-pacing independence measurable from replays at named frame times? [SC-A11-104] — yes.
- [x] CHK017 Are the contact test cases enumerated (separated, touching, overlapping, rotated, non-finite)? [SC-A11-105] — yes.
- [x] CHK018 Are the manifest fixtures listed by name? [FR-A11-122] — yes (ten).

## Performance

- [x] CHK019 Are per-tick work bounds stated without unmeasured performance claims, and is test duration bounded? [Plan §Technical Context, SC-A11-107] — yes (≤ 48 bodies, ≤ 1,326 pairs, 10 iterations; tests < 10 s).
- [x] CHK020 Is resting-stack jitter acknowledged as out of this phase with its owner? [Spec §Edge Cases] — yes (A11-P02).

## Notes

- 20 items evaluated on 2026-11-15; CHK007 corrected in spec.md before marking. `/speckit-implement` reads these markers
  and does not change them.
