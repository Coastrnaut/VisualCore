# Render loop Checklist: Particle Universe — Phase 02

**Purpose**: Unit tests for the Phase 02 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance and release constraints)
**Created**: 2026-11-11
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

**Ownership**: reviewer-owned; `[x]` means the reviewer judged the requirement quality sufficient, not that the work is
done. `/speckit-implement` reads these markers and does not change them.

## Requirement Completeness

- [x] CHK001 Are the formula, parameters and clamp ranges specified for every new force kind? [Completeness, Spec §Clarifications Q1]
- [x] CHK002 Is a numeric acceleration bound documented for every force kind, including the velocity-dependent wind and drag bounds? [Completeness, Spec §FR-A04-202]
- [x] CHK003 Are the budget shares, minimum and rounding rule specified for every quality tier? [Completeness, Spec §Clarifications Q2]
- [x] CHK004 Are the default strength and radius/softening of each placeable force kind specified? [Completeness, Spec §Clarifications Q3]
- [x] CHK005 Is the wind direction defined for every placement, including a force placed exactly at the world center? [Gap, Spec §Clarifications Q3]
- [x] CHK006 Is the content and wording of the fallback note and the renderer status specified? [Completeness, Spec §US4 AC3, contracts/app-ui.md]
- [x] CHK007 Are the three fixed simulation states used for the offscreen pixel test identified? [Completeness, Spec §SC-A04-205]

## Requirement Clarity

- [x] CHK008 Is "lit" quantified for a particle center pixel (which channel dominates, against which background)? [Clarity, Spec §US4 AC1]
- [x] CHK009 Is "far-away pixel" defined with a distance in particle radii? [Clarity, Spec §US4 AC1]
- [x] CHK010 Is "applied live / on the next step" defined for strength and kind changes? [Clarity, Spec §US1 AC3]
- [x] CHK011 Is the effective-limit text format (numbers, tier numbering) specified? [Clarity, Spec §FR-A04-205, contracts/app-ui.md]

## Requirement Consistency

- [x] CHK012 Is the "minimum budget" edge case consistent with the rule that the requested limit is never exceeded? [Conflict, Spec §Edge Cases vs §US3]
- [x] CHK013 Do the SceneForce validation ranges match the VisualCore clamp ranges? [Consistency, data-model]
- [x] CHK014 Is the requirement that existing forces stay bit-identical consistent with clamping every force before each step? [Consistency, Spec §FR-A04-201, research R1]

## Scenario and Edge Case Coverage

- [x] CHK015 Are requirements defined for a force placed by a tap outside the world square? [Edge Case, Spec §Edge Cases]
- [x] CHK016 Are requirements defined for lowering the live limit while it is full (no deletion, drops counted)? [Coverage, Spec §US3 AC2]
- [x] CHK017 Is the recovery path (calm period, step back up) specified after heat or Low Power Mode ends? [Recovery, Spec §US3 AC3]
- [x] CHK018 Is the behavior on GPU context recreation specified (state kept, GPU objects rebuilt)? [Recovery, Spec §US4 AC2]
- [x] CHK019 Are requirements stated for the render host while the app is in the background? [Gap, iOS lifecycle]
- [x] CHK020 Is the Reduce Motion starting state stated for the GPU path as well as the CPU preview? [Gap, iOS lifecycle]

## Architecture Ownership

- [x] CHK021 Is it stated which module owns each new generic type (forces, budget, device conditions, layer scene) and that the app owns no GL/EGL? [Architecture, Spec §Canonical overrides, §FR-A04-206]
- [x] CHK022 Is the requirement to keep ProjectM types out of the new public API and to run the reference regression stated? [Architecture, Spec §FR-A04-207]

## Testability, Privacy, Performance and Release

- [x] CHK023 Is each success criterion measurable on the host or simulator without a device? [Measurability, Spec §SC-A04-201…206]
- [x] CHK024 Are DEBUG-only test seams required to be absent from Release builds? [Release, Spec §Clarifications Q5]
- [x] CHK025 Is it stated that the phase stores nothing, uses no network and requests no permission? [Privacy, Spec §Negative requirements]
- [x] CHK026 Are performance claims excluded and resource bounds stated instead? [Performance, Spec §Negative requirements, plan §Technical Context]
- [x] CHK027 Are accessibility requirements (labels, Dynamic Type layout of the new controls, audits on both runtimes) specified? [Accessibility, Spec §SC-A04-206, Gap]

## Notes

- Items are evaluated by the reviewer (the agent acting under the owner's delegation, CLAUDE.md §2).
- Review 2026-11-11 (agent under the owner's standing delegation): CHK005, CHK007, CHK008, CHK010, CHK012, CHK019,
  CHK020 and CHK027 were gaps; each is now answered in spec §Edge Cases (recommended option, research R3, R8). All
  27 items pass.
