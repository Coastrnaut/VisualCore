# Requirements Quality Checklist: Fluid Art Playground Phase 05 — controls, determinism, fixtures and stress automation

**Purpose**: Unit tests for the Phase 05 requirements: completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance and release constraints.

**Created**: 2026-11-11

**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

**Ownership**: `[x]` means the reviewer judged that requirements-quality criterion satisfied. It does not mean the
implementation is complete. `/speckit-implement` reads these markers but never changes them.

## Requirement Completeness

- [ ] CHK001 Are the Pause, Step and Reset outcomes specified for every simulation state (running, paused, mid-swipe, mid-pinch)? [Completeness, Spec §US1, §Edge Cases]
- [ ] CHK002 Is what Reset keeps (pause state, tuning, palette, brush, detail level) and what it clears listed explicitly? [Completeness, Spec §FR-A02-503]
- [ ] CHK003 Are all five §11 fixtures named with their pass conditions? [Completeness, Spec §US3, §FR-A02-506]
- [ ] CHK004 Are the automation modes, launch keys and report fields documented for the device campaign? [Completeness, Spec §FR-A02-508, §FR-A02-510]
- [ ] CHK005 Is the behavior of a Simulation detail change on an active stroke and on the touch queue specified? [Gap, Spec §FR-A02-511]

## Requirement Clarity

- [ ] CHK006 Is "deterministic" defined with its scope (same runtime and device, byte-identical) and its non-claims (across GPUs)? [Clarity, Spec §FR-A02-504, §Assumptions]
- [ ] CHK007 Is "bounded catch-up" quantified (steps per rendered frame, time-step range)? [Clarity, Spec §FR-A02-506, Clarification 3]
- [ ] CHK008 Is the "aggressive" stress script quantified (pointers, force, samples, iterations, frames)? [Clarity, Spec §US4, Contract]
- [ ] CHK009 Is "within its encoding range" defined per field and per storage? [Clarity, Spec §FR-A02-507]

## Requirement Consistency

- [ ] CHK010 Are the grid sizes for the detail levels consistent across clarifications, FR-A02-511 and SC-A02-507? [Consistency]
- [ ] CHK011 Does "Reset keeps the pause state" agree with the edge case "Reset while paused shows the seeded pattern immediately"? [Consistency, Spec §FR-A02-503, §Edge Cases]

## Acceptance Criteria Quality

- [ ] CHK012 Is SC-A02-502's "differ in at least 1% of pixels" measurable against a defined comparison (per-channel, any channel)? [Measurability, Spec §SC-A02-502]
- [ ] CHK013 Can SC-A02-506's simulator rehearsal be judged without device data, and is it labelled as not device evidence? [Measurability, Spec §SC-A02-506, §Negative Requirements]

## Scenario and Edge Case Coverage

- [ ] CHK014 Are context loss and recovery during the test mode covered by a requirement, not only an edge case? [Coverage, Spec §Edge Cases]
- [ ] CHK015 Is a detail change that exceeds the device's maximum size (capped) or fails to allocate covered? [Edge Case, Gap]
- [ ] CHK016 Are suspension while paused and suspension while running both covered by fixture 5? [Coverage, Spec §Edge Cases]

## Non-Functional: Privacy, Lifecycle, Performance, Release

- [ ] CHK017 Is it stated that the test mode stores nothing and collects no data, and that reports stay in the app container? [Privacy, Gap]
- [ ] CHK018 Are EGL/context ownership and the no-catch-up rule stated as requirements with an enforcement check? [Lifecycle, Spec §FR-A02-509]
- [ ] CHK019 Are performance thresholds explicitly deferred to measured device data rather than invented? [Performance, Spec §Assumptions]
- [ ] CHK020 Is the Release-build exclusion of automation (symbols and trigger strings) stated with its check? [Release, Spec §FR-A02-508]
- [ ] CHK021 Are the accessibility requirements (labels, values, hints, announcements, Dynamic Type) specified for the new controls and picker? [Accessibility, Spec §FR-A02-501, Contract]

## Dependencies and Assumptions

- [ ] CHK022 Is the new VisualCore dependency edge (Scenes → Simulation) justified against the package rules? [Dependency, Plan §Constitution Check, Research R1]
- [ ] CHK023 Is the assumption that the simulator GPU is deterministic stated with what happens if it is not? [Assumption, Research R5]

## Notes

Generated 2026-11-11. Review follows.
