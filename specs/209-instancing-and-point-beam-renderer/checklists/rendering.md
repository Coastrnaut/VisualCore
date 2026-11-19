# Requirements Quality Checklist: R02-F09 instancing and points/beams

**Purpose**: Unit tests for the requirements of feature 209 (completeness, compatibility, GPU lifecycle, testability,
performance)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-19; failures were corrected in the artifacts.

## Requirement Completeness

- [x] CHK001 Are all three deliverables mapped to requirements? [Traceability, Spec §Traceability]
- [x] CHK002 Are instance limits and per-instance layouts stated? [Completeness, Clarifications Q1, data-model]
- [x] CHK003 Is the GL state (culling, depth test and write) defined for each case? [Gap → corrected: data-model GL state]

## Requirement Clarity

- [x] CHK004 Is the beam geometry, including the end-on fallback, defined precisely? [Clarity, Clarifications Q2]
- [x] CHK005 Is the falloff a formula? [Clarity, Clarifications Q2]
- [x] CHK006 Is the depth used for ordering defined for meshes and beams? [Clarity, Clarifications Q3]

## Compatibility

- [x] CHK007 Is it stated that existing particle, mesh and depth-pass renderers are unchanged? [Compatibility, Spec §FR-R02F09-007]

## GPU Lifecycle

- [x] CHK008 Is rebuilding after a context rebuild and release required? [Lifecycle, Spec §FR-R02F09-006]
- [x] CHK009 Is buffer reuse across frames stated? [Lifecycle, Spec §FR-R02F09-006]

## Testability

- [x] CHK010 Is "one draw call" provable without GPU counters? [Measurability, Clarifications Q5]
- [x] CHK011 Are tolerances stated for each pixel comparison? [Measurability, Spec §SC-R02F09-001, 002]

## Performance

- [x] CHK012 Is cost bounded by limits and draw counts rather than a clock? [Performance, plan Technical Context]

## Edge Cases

- [x] CHK013 Are empty lists, non-finite inputs, zero widths and end-on beams addressed? [Edge Case, Spec §Edge Cases]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
