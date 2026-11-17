# Preview Requirements Quality Checklist: Shader Studio — Phase 02

**Purpose**: Unit tests for the requirements of A22-P02 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-17 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK005).

## Completeness

- [x] CHK001 Are the core's state, actions, ranges and refusal rules specified? [Spec §Q1, data-model] — yes.
- [x] CHK002 Is the path from Run to compile (queue, validation, next frame, swap) specified? [Spec §Q2, FR-A22-202–204] — yes.
- [x] CHK003 Is how uniforms reach the preview without a recompile specified? [Spec §Q3, FR-A22-205] — yes.
- [x] CHK004 Are the interface's controls, identifiers and spoken labels specified? [Spec §Q4, contracts/experience.md] — yes.
- [x] CHK005 Is the outcome of a compile that succeeds with warnings specified? [Spec §Edge Cases, data-model PreviewStatus] — corrected: it replaces the preview, lists the warnings and the status shows their count.
- [x] CHK006 Is the registration specified (catalog, registry, project, synthetic candidate)? [Spec §Q5, FR-A22-207] — yes.

## Clarity and measurability

- [x] CHK007 Is "never replaces a working preview" measurable? [Spec §SC-A22-201] — yes (byte-identical pictures).
- [x] CHK008 Is "one compile per frame" countable? [Spec §SC-A22-203, Q4] — yes (`compileCount`).
- [x] CHK009 Are the frame rate and tier stated? [Spec §Q3] — yes (30 frames per second, `level-0`).

## Lifecycle and edge cases

- [x] CHK010 Are context rebuild and resize covered? [Spec §US4, FR-A22-206] — yes.
- [x] CHK011 Are close-with-pending, template-switch-while-pending and first-run-fails covered? [Spec §Edge Cases] — yes.
- [x] CHK012 Is link failure treated like compile failure? [Spec §Edge Cases, FR-A22-204] — yes.

## Architecture, privacy and release

- [x] CHK013 Is compiling barred from control actions and confined to the host's context? [Spec §FR-A22-203, Negative Requirements; constitution 2.18.1] — yes.
- [x] CHK014 Are GL calls outside VisualCore's scenes excluded? [Spec §Negative Requirements, Plan §Constitution Check] — yes.
- [x] CHK015 Is the experience kept unavailable until X-A22? [Spec §FR-A22-207] — yes.
- [x] CHK016 Is network use and any sandbox claim excluded? [Spec §Negative Requirements] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
