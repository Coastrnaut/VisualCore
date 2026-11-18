# Requirements Quality Checklist: Shader Studio — Phase 04 limits, guidance, watchdog and library

**Purpose**: Unit tests for the Phase 04 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-18
**Feature**: [spec.md](../spec.md), [plan.md](../plan.md), [data-model.md](../data-model.md),
[contracts/limits.md](../contracts/limits.md)

`[x]` means the reviewer judged the requirement's writing satisfactory (evaluated by the lead under the owner's
standing delegation, 2026-11-18); it does not mean the work is done.

## Requirement Completeness

- [x] CHK001 Is a guidance sentence required for every validator refusal code, with the full list of codes named? [Completeness, Spec §FR-A22-401, Clarifications]
- [x] CHK002 Are the compiler errors that get specific guidance enumerated, with a fallback for all others? [Completeness, Spec §FR-A22-402]
- [x] CHK003 Are the watchdog's limit, window and skipped intervals stated as numbers and events? [Completeness, Spec §FR-A22-403]
- [x] CHK004 Is what Reset restores defined, including the case with no fallback? [Completeness, Spec §FR-A22-404]
- [x] CHK005 Are every library operation and its caps and messages specified? [Completeness, Spec §FR-A22-405, data-model]
- [x] CHK006 Is the stopped preview's picture specified (what is drawn instead of the shader)? [Completeness, data-model "FrameWatchdog"]

## Requirement Clarity

- [x] CHK007 Is "specific guidance" measurable (distinct sentences per code, the line where known)? [Clarity, Spec §SC-A22-401]
- [x] CHK008 Is "slower than the limit" unambiguous about consecutive versus total frames? [Clarity, Spec §FR-A22-403]
- [x] CHK009 Are name rules (trimming, length, case) explicit? [Clarity, data-model]

## Requirement Consistency

- [x] CHK010 Is "last good shader" used consistently with A22-P02's meaning, the watchdog's fallback being defined separately? [Consistency, Spec §FR-A22-404, research R4]
- [x] CHK011 Do the snapshot rules (schema 1, optional `resets`) agree with A22-P03's optional `textures`? [Consistency, data-model]

## Scenario and Edge Case Coverage

- [x] CHK012 Are recovery flows covered: Reset after a stop, a context loss while stopped, a pause in drawing? [Coverage, Spec §Edge Cases]
- [x] CHK013 Are damaged, oversized and newer files and a full quota covered, with nothing deleted automatically? [Coverage, Spec §FR-A22-406]
- [x] CHK014 Is opening over unsaved edits defined? [Edge Case, Spec §Edge Cases]

## Non-Functional, Architecture and Lifecycle

- [x] CHK015 Is privacy bounded (no network, no account, only the experience's storage)? [Privacy, Spec §Negative Requirements]
- [x] CHK016 Is ownership stated: pure core types, the experience owns storage and drawing, no VisualCore change, context ownership in the host? [Architecture, plan "Project Structure"]
- [x] CHK017 Are the watchdog and fallback lifecycle (setup, resize, teardown, context loss) specified? [iOS lifecycle, plan "Lifecycle"]
- [x] CHK018 Are test time limits and the no-real-slow-frames rule stated? [Testability, Spec §SC-A22-404, Assumptions]
- [x] CHK019 Is the no-sandbox claim kept, with device measurement of the watchdog's numbers deferred to A22-P05? [Release, Spec §Negative Requirements, research R3]
- [x] CHK020 Are interface tests and their identifiers specified for the new controls? [Testability, Spec §FR-A22-407, Clarifications]

## Notes

- Items CHK006, CHK012 and CHK014 failed at first; the stopped colour (data-model), a pause in drawing, a context loss
  while stopped, opening over unsaved edits and unreadable-file operations were added to the spec before marking.
- `/speckit-implement` reads checklist state; it does not change the markers.
