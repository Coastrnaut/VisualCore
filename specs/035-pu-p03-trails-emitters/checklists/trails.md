# Trails and emitters Checklist: Particle Universe — Phase 03

**Purpose**: Unit tests for the Phase 03 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance and release constraints)
**Created**: 2026-11-11
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

**Ownership**: reviewer-owned; `[x]` means the reviewer judged the requirement quality sufficient, not that the work is
done. `/speckit-implement` reads these markers and does not change them.

## Requirement Completeness

- [ ] CHK001 Is the trail fade formula, including how it reaches background, specified? [Completeness, Spec §Clarifications Q1]
- [ ] CHK002 Are the strength range and its meaning (fraction kept per time unit) defined? [Completeness, Spec §Clarifications Q1]
- [ ] CHK003 Are the ranges and units of size, lifetime and the gradient set specified? [Completeness, Spec §Clarifications Q5]
- [ ] CHK004 Is the maximum number of emitters and the add/remove behavior at the limits specified? [Completeness, Spec §US1, Clarifications Q4]
- [ ] CHK005 Is the placement of a newly added emitter specified? [Gap, Spec §Clarifications Q4]
- [ ] CHK006 Is the brightness cap value and when it applies specified? [Completeness, Spec §Clarifications Q3]

## Requirement Clarity

- [ ] CHK007 Is "applied to new particles at once" unambiguous for size and color, which are drawn from the emitter? [Clarity, Spec §US2, SC-A04-302]
- [ ] CHK008 Is "additive" blending defined precisely enough to predict overlapping pixels? [Clarity, Spec §FR-A04-301, Clarifications Q2]
- [ ] CHK009 Is the frame-rate independence of trails stated with a measurable tolerance? [Clarity, Spec §SC-A04-303]

## Requirement Consistency

- [ ] CHK010 Is "no live particle is deleted" on removal consistent with how emitter colors and sizes are looked up? [Consistency, Spec §US1 AC2, Clarifications Q4]
- [ ] CHK011 Is "trails at strength 0 cost no extra pass" consistent with the brightness cap routing drawing through the layer? [Conflict, Spec §Edge Cases vs Clarifications Q3]
- [ ] CHK012 Do the scene override ranges match the UI control ranges? [Consistency, Spec §Clarifications Q5]

## Scenario and Edge Case Coverage

- [ ] CHK013 Are requirements defined for adding an emitter when the particle budget is full? [Edge Case, Spec §Edge Cases]
- [ ] CHK014 Are requirements defined for zero-size and maximum-size views with trails on? [Edge Case, Spec §Edge Cases]
- [ ] CHK015 Are requirements defined for trails across background and context recreation? [Recovery, Spec §US4 AC1, §Edge Cases]
- [ ] CHK016 Is the CPU preview's behavior for trails and blend specified? [Exception Flow, Spec §US4 AC3]
- [ ] CHK017 Is the behavior of a family or seed change on several emitters and their overrides specified? [Gap]

## Architecture Ownership

- [ ] CHK018 Is it stated that the blend option, trail layer and fade model are VisualCore components and the app owns no GL? [Architecture, Spec §Canonical overrides, §Negative requirements]
- [ ] CHK019 Are the regression obligations after the VisualCore change (reference regression, A01/A02, replay fixture) stated? [Architecture, Spec §FR-A04-307]

## Testability, Privacy, Performance and Release

- [ ] CHK020 Can every success criterion be measured on host or simulator without a device? [Measurability, Spec §SC-A04-301…306]
- [ ] CHK021 Is texture-leak freedom defined as a countable outcome? [Measurability, Spec §SC-A04-304]
- [ ] CHK022 Are graphics memory bounds for the trail targets stated instead of performance claims? [Performance, Plan §Technical Context]
- [ ] CHK023 Is it stated that the phase stores nothing, uses no network and requests no permission? [Privacy, Spec §Negative requirements]
- [ ] CHK024 Are accessibility requirements (Reduce Flashing, labels and values of new controls, audits on both runtimes) specified? [Accessibility, Spec §US4, SC-A04-306]

## Notes

- Items are evaluated by the reviewer (the agent acting under the owner's delegation, CLAUDE.md §2).
