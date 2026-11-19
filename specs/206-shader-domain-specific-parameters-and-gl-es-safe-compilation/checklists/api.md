# Requirements Quality Checklist: R02-F06 shader parameters and safe compilation

**Purpose**: Unit tests for the requirements of feature 206 (completeness, API compatibility, GPU lifecycle,
testability, performance, determinism)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-19; failures were corrected in the artifacts.

## Requirement Completeness

- [x] CHK001 Are all five deliverables of the source mapped to requirements? [Traceability, Spec §Traceability]
- [x] CHK002 Are every limit's numbers stated (depth 8, 64 KiB, 32 defines, 256 characters, 6 switches, 8 values, 64 combinations, 64 KiB logs)? [Completeness, Spec §FR-R02F06-001…005]
- [x] CHK003 Is every reason code enumerated? [Completeness, Clarifications Q4]
- [x] CHK004 Is the stage of a shader (vertex or fragment) defined for the precision rule? [Gap → corrected: data-model ShaderStageKind]

## Requirement Clarity

- [x] CHK005 Is "include once" defined (later includes skipped, per expansion)? [Clarity, Spec §FR-R02F06-001]
- [x] CHK006 Are variant order and key format unambiguous? [Clarity, Clarifications Q3]
- [x] CHK007 Is the difference between an error (undeclared, mistyped) and a report (unused) stated? [Clarity, Spec §FR-R02F06-006]

## API Compatibility

- [x] CHK008 Is it stated that `program(...)` keeps its signature and new behaviour arrives by overloads? [Compatibility, Clarifications Q2]
- [x] CHK009 Are the behaviour changes limited to cases that failed before (double include, missing precision)? [Compatibility, Clarifications Q2]
- [x] CHK010 Is the API baseline update required? [Compatibility, Spec §FR-R02F06-009]

## GPU Lifecycle

- [x] CHK011 Is binding behaviour across a context rebuild defined? [Lifecycle, Clarifications Q5]
- [x] CHK012 Is the validity of a prewarm report across a context rebuild defined? [Gap → corrected: data-model PrewarmReport]
- [x] CHK013 Is cache eviction during a warm variant set addressed? [Edge Case, Spec §Edge Cases]

## Testability & Determinism

- [x] CHK014 Are planted-mistake fixtures counted (at least 12)? [Measurability, Spec §SC-R02F06-001]
- [x] CHK015 Is variant enumeration deterministic and its count testable? [Determinism, Spec §SC-R02F06-002]
- [x] CHK016 Is the precision rule testable without a device (device report as input)? [Testability, Spec §SC-R02F06-003]

## Performance

- [x] CHK017 Is an expansion time bound stated and measurable on the host? [Performance, plan Technical Context]
- [x] CHK018 Are test durations bounded? [Performance, Spec §SC-R02F06-006]

## Dependencies & Assumptions

- [x] CHK019 Is the new package dependency and its direction stated? [Dependency, Clarifications Q1]
- [x] CHK020 Is uniform-block exclusion justified? [Assumption, Spec §Assumptions]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
