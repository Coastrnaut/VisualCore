# Requirements Quality Checklist: Shader Studio — Phase 05 stress, recovery, shape and device plan

**Purpose**: Unit tests for the Phase 05 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-18
**Feature**: [spec.md](../spec.md), [plan.md](../plan.md), [data-model.md](../data-model.md),
[contracts/recovery.md](../contracts/recovery.md)

`[x]` means the reviewer judged the requirement's writing satisfactory (evaluated by the lead under the owner's
standing delegation, 2026-11-18); it does not mean the work is done.

## Requirement Completeness

- [x] CHK001 Is "no build-up" defined as a measurable resource level with the moment it is taken? [Completeness, Spec §FR-A22-501, Clarifications]
- [x] CHK002 Are the stress cycle's contents and counts fixed? [Completeness, Spec §SC-A22-501, Clarifications]
- [x] CHK003 Are all recovery states and the rebuild count enumerated? [Completeness, Spec §FR-A22-502, SC-A22-502]
- [x] CHK004 Is the shape's action, range, default and effect on values specified? [Completeness, Spec §FR-A22-503, data-model]
- [x] CHK005 Are the device rows, their devices and their pending state enumerated, with the owner actions they need? [Completeness, Spec §FR-A22-505]

## Requirement Clarity and Consistency

- [x] CHK006 Is "the same picture" defined as byte-identical? [Clarity, Spec §SC-A22-502]
- [x] CHK007 Are the shape bounds consistent with the A22-P02/P03 rules and the A22-P04 deferral? [Consistency, Spec §Canonical overrides, data-model]
- [x] CHK008 Is the snapshot rule for a missing `shape` consistent with the earlier optional fields? [Consistency, Spec §Edge Cases]

## Scenario and Edge Case Coverage

- [x] CHK009 Are a queued compile at teardown, a rebuild while stopped and a rebuild under the library sheet covered? [Coverage, Spec §Edge Cases]
- [x] CHK010 Are shape changes on later edits defined (kept by position, ignored past the count)? [Edge Case, Spec §Edge Cases]
- [x] CHK011 Is the relaunch scenario's data persistence assumption stated? [Assumption, Spec §Assumptions]

## Non-Functional, Architecture and Lifecycle

- [x] CHK012 Is ownership kept: the core stays pure, the presenter sends the shape, no VisualCore change? [Architecture, plan "Project Structure"]
- [x] CHK013 Is the lifecycle of the live, fallback and stopped scenes and the texture targets across a rebuild specified? [iOS lifecycle, plan "Lifecycle"]
- [x] CHK014 Are test durations bounded (unit under 10 s, interface under 60 s, no soak)? [Performance, Testability, Spec §SC-A22-504, Negative Requirements]
- [x] CHK015 Is device evidence kept apart from simulator evidence, with no device run before the lock? [Release, Spec §Negative Requirements]
- [x] CHK016 Is privacy unchanged (no network, storage only in the experience)? [Privacy, plan Constitution VIII]

## Notes

- CHK005 and CHK011 failed at first; the owner actions per device row and the storage-persistence assumption were added
  to the spec before marking.
- `/speckit-implement` reads checklist state; it does not change the markers.
