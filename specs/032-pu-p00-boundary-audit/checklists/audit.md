# Audit Requirements Quality Checklist: Particle Universe — Phase 00 boundary audit

**Purpose**: Unit tests for the Phase 00 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance and release constraints)
**Created**: 2026-11-11
**Feature**: [spec.md](../spec.md)

**Review Ownership**: reviewer-owned. `[x]` means the requirements-quality criterion is satisfied, not that code is
done. Focus: the manual's three Phase 00 gates, its capability audit (§6), its risk register (§13), the A04 rules and
the reuse rule. Depth: phase gate. Audience: reviewer.

## Requirement Completeness

- [x] CHK001 Are all three manual acceptance gates required: integration matrix, compilable shell and written stop/go decision? [Completeness, Spec §FR-A04-002, §FR-A04-005, §FR-A04-009]
- [x] CHK002 Does the inventory name the areas a particle sandbox depends on (particle system, renderer, trail targets, pointer input, quality and pacing, persistence, export)? [Completeness, Spec §FR-A04-001]
- [x] CHK003 Are all five brainstorm capabilities and five version 0.1 needs enumerated as matrix rows? [Completeness, Spec §FR-A04-002, §SC-A04-002]
- [x] CHK004 Are negative requirements listed, each with its forbidding source? [Completeness, Spec §FR-A04-011]

## Requirement Clarity

- [x] CHK005 Are the three matrix statuses and the evidence rule (file, public non-test symbol, product) unambiguous? [Clarity, Spec §FR-A04-002, §Edge Cases]
- [x] CHK006 Is the CPU-versus-GPU simulation decision stated with its reason (no compute shaders on the path)? [Clarity, Spec §Clarifications 2, §Edge Cases]
- [x] CHK007 Are the stop conditions concrete, including compute shaders the path cannot provide? [Clarity, Spec §FR-A04-009]

## Architecture Ownership

- [x] CHK008 Does every gap require an owning VisualCore module or a justified app-local exception? [Consistency, Spec §FR-A04-008, Constitution II]
- [x] CHK009 Is it explicit which particle machinery goes to VisualCore (emitter families, fields, blending, trails, quality tiers) and what stays app content (presets, scene schema)? [Consistency, Spec §Clarifications 3, Constitution A04]
- [x] CHK010 Is the no-modification rule for VisualCore and ProjectM measurable? [Measurability, Spec §FR-A04-007, §SC-A04-006]
- [x] CHK011 Is ProjectM independence of the new target required and verifiable? [Coverage, Spec §FR-A04-006]

## Privacy, Lifecycle and Platform

- [x] CHK012 Are permissions and networking for the shell excluded? [Completeness, Spec §FR-A04-005]
- [x] CHK013 Is it explicit that Phase 00 creates no render host or GPU resources? [Clarity, Spec §FR-A04-005]
- [x] CHK014 Are exact-physics, marketplace, multi-user and device-performance claims excluded? [Consistency, Spec §FR-A04-011]
- [x] CHK015 Are the risk register's concerns (instance support, additive-blend comfort, thermal pressure) traced to gaps or rules? [Coverage, Spec §User Story 4, Constitution A04 bounded GPU and accessibility]

## Testability and Acceptance

- [x] CHK016 Are all success criteria quantified? [Measurability, Spec §SC-A04-001–007]
- [x] CHK017 Are both simulator runtimes required for the smoke test? [Coverage, Spec §SC-A04-003]
- [x] CHK018 Is the regression baseline defined by named steps, with failure a blocker? [Clarity, Spec §Clarifications 5, §Edge Cases]

## Performance and Release

- [x] CHK019 Is it explicit that no performance budget is set in Phase 00? [Clarity, Spec §Edge Cases, plan]
- [x] CHK020 Are the bundle identity and target location fixed? [Consistency, Spec §FR-A04-005]
- [x] CHK021 Does traceability require every v0.1 feature and journey to map to a phase? [Coverage, Spec §FR-A04-010, §SC-A04-007]

## Review

Generated 2026-11-11 from the A02/A03 audit checklist pattern, adapted to the A04 capabilities, risks and rules.
Reviewed 2026-11-11 under the owner's delegated approval (CLAUDE.md §2): 21/21 satisfied by spec.md as clarified.
