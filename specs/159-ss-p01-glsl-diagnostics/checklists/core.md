# Core Requirements Quality Checklist: Shader Studio — Phase 01

**Purpose**: Unit tests for the requirements of A22-P01 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-17 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK004).

## Completeness

- [x] CHK001 Are the project's fields, kind, schema, size cap and refusal codes specified? [Spec §FR-A22-101, 102, Q3] — yes.
- [x] CHK002 Are all limits given as numbers under the expansion ceiling? [Spec §Q2, data-model] — yes (16,384 bytes, 400 lines, 16 uniforms, 2 inputs).
- [x] CHK003 Is the template assembly (file names, order, prelude content) specified? [Spec §Q1] — yes.
- [x] CHK004 Do the validator's rules cover texture inputs as well as float uniforms? [Spec §Q2, FR-A22-103] — corrected: declared and source `sampler2D` inputs are now matched both ways, as uniforms are.
- [x] CHK005 Are token kinds and the line-splitting rule specified? [Spec §Q4, FR-A22-105] — yes.
- [x] CHK006 Are the templates and the broken-shader fixtures named? [Spec §Q5, FR-A22-106] — yes.

## Clarity and measurability

- [x] CHK007 Is "points to the authored line" measurable? [Spec §SC-A22-102, US3] — yes (file and line equal to the authored ones for every fixture).
- [x] CHK008 Is "tokens rebuild the source" exact? [Spec §SC-A22-103] — yes (concatenation equals the line).
- [x] CHK009 Are time limits stated? [Spec §SC-A22-105] — yes (10 s).

## Consistency

- [x] CHK010 Do spec, plan and data model agree on the core's dependencies (shader source and parameters only)? [Plan §Technical Context, research D3] — yes.
- [x] CHK011 Are reserved names consistent between the prelude and the validator? [Spec §Q1, Q2] — yes (`u_time`, `u_resolution`).

## Edge cases

- [x] CHK012 Are empty sources, CRLF, unclosed comments, long lines and line-less errors covered? [Spec §Edge Cases] — yes.
- [x] CHK013 Are errors inside includes kept apart from the person's lines? [Spec §US3/AC2, Q4] — yes ("outside the source").

## Architecture, privacy and release

- [x] CHK014 Is the core barred from GL, clocks, network and UI frameworks? [Spec §FR-A22-107] — yes.
- [x] CHK015 Is the compile proof confined to tests in the host's context, with no compile in the core? [Spec §Q5, Plan §Lifecycle] — yes.
- [x] CHK016 Is the licence record of the templates required? [Plan §Constitution Check XIII] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
