# Seeded particle domain Checklist: Particle Universe — Phase 01

**Purpose**: Unit tests for the Phase 01 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance and release constraints)
**Created**: 2026-11-11
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

**Ownership**: reviewer-owned; `[x]` means the reviewer judged the requirement quality sufficient, not that the work is
done. `/speckit-implement` reads these markers and does not change them.

## Requirement Completeness

- [x] CHK001 Are all four emitter families specified with their shape, emission mode and parameters? [Completeness, Spec §Clarifications Q4]
- [x] CHK002 Are clamp ranges defined for every emitter parameter that can be set? [Completeness, Spec §FR-A04-102]
- [x] CHK003 Are all scene validation failure reasons enumerated? [Completeness, Spec §US4 AC2, data-model]
- [x] CHK004 Is the content of the replay fixture (seed, families, controls, steps, expected values) fully specified? [Completeness, Spec §Clarifications Q5]
- [x] CHK005 Are requirements stated for what happens to commands whose target index does not exist? [Gap, data-model SceneCommand]

## Requirement Clarity

- [x] CHK006 Is "on the shape" quantified with a tolerance? [Clarity, Spec §SC-A04-101]
- [x] CHK007 Is the burst timing (first burst, cadence, catch-up after a stall) defined unambiguously? [Clarity, research R3]
- [x] CHK008 Is "bounded catch-up" quantified (substep cap, dropped time accounting)? [Clarity, Spec §US3]
- [x] CHK009 Is the meaning of time scale relative to the fixed step defined so that determinism is preserved? [Clarity, research R6]

## Requirement Consistency

- [x] CHK010 Are the particle-limit range in the scene and the VisualCore pool cap consistent? [Consistency, Spec §Clarifications Q4]
- [x] CHK011 Do the clamp ranges include every value A01 and the baselines use, so their results stay unchanged? [Consistency, Spec §FR-A04-101, research R4]
- [x] CHK012 Is "Firework" described consistently as bursts across stories, clarifications and the contract? [Consistency]

## Acceptance Criteria Quality

- [x] CHK013 Can bit-exact replay be objectively checked, and are the platforms on which it must hold stated? [Measurability, Spec §SC-A04-103, Clarifications Q5]
- [x] CHK014 Are the drop-count expectations expressed as an exact equation? [Measurability, Spec §SC-A04-102]

## Scenario and Edge Case Coverage

- [x] CHK015 Are degenerate shapes (zero radius or length) and non-positive burst intervals covered? [Edge Case, Spec §Edge Cases]
- [x] CHK016 Are requirements defined for changing family or seed mid-run? [Coverage, Spec §Edge Cases]
- [x] CHK017 Are background/foreground and Reduce Motion behaviors specified for the preview? [Coverage, iOS lifecycle, plan §Lifecycle]

## Architecture Ownership and Constraints

- [x] CHK018 Is it explicit which pieces live in VisualCore and which in the app, with dependency direction? [Architecture, plan §Project Structure]
- [x] CHK019 Is the absence of GPU/EGL use in this phase stated as a negative requirement? [Architecture, Spec §Negative requirements]
- [x] CHK020 Are the VisualCore change obligations (API baseline, docs, ProjectM regression, A01/A02 builds) listed? [Release, Spec §FR-A04-107]

## Privacy, Performance and Release

- [x] CHK021 Is it stated that this phase stores nothing, uses no network and requests no permission? [Privacy, Spec §Negative requirements]
- [x] CHK022 Are performance claims excluded and resource bounds (limit, substeps, preview count) stated instead? [Performance, plan §Technical Context]
- [x] CHK023 Are accessibility requirements (labels, Dynamic Type, audit on both runtimes) specified for the new controls? [Accessibility, Spec §SC-A04-106, contracts]

## Notes

- Items are evaluated by the reviewer (the agent acting under the owner's delegation, CLAUDE.md §2).
