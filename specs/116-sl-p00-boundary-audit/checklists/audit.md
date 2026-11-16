# Audit Requirements Quality Checklist: Simulation Lab — Phase 00

**Purpose**: Unit tests for the requirements of A16-P00 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-16 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK008).

## Completeness

- [x] CHK001 Are all inventory areas of the manual's Phase 00 deliverable (products, host, thread, shaders/resources, build steps, ownership, regression) required? [Spec §FR-A16-001] — yes.
- [x] CHK002 Are all five brainstorm capabilities and six version 0.1 features required in the matrix? [Spec §FR-A16-002, SC-A16-001] — yes.
- [x] CHK003 Is the stop/go decision required with the conditions that force "stop"? [Spec §US4 AC2, FR-A16-006] — yes (missing host or buildable offscreen feedback path).

## Architecture ownership

- [x] CHK004 Does every gap name an owning module and phase? [Spec §FR-A16-003, SC-A16-002] — yes.
- [x] CHK005 Is the rule for "available" defined so ownership is not claimed from another experience's code? [Clarifications Q2, Edge Cases] — yes (Fluid Art Playground's feedback field and Generative Art Studio's export named as examples).
- [x] CHK006 Are the expected gaps (three families with CPU references, seeds and parameter schema, boundary rules, ping-pong separation, float targets with probe and fallback, GPU-versus-CPU tolerance, pause/reset/step/speed, histogram or legend, seeding with a control alternative, presets, capture, resize and context rebuild) enumerated? [Spec §FR-A16-003] — yes.
- [x] CHK007 Is reuse of existing products (`PingPongTarget`, `FloatRenderSupport`, `FieldPass`, `RenderTarget`, `StillCapture`, `FieldGrid`, gestures, persistence, experience storage) required rather than left implicit? [Spec §Assumptions, Clarifications facts] — yes.
- [x] CHK008 Are the manual's three risks recorded with an owner, verification method and release-blocker condition? [Gap → FR-A16-006] — failed (the edge cases named them but no requirement asked for owners and blockers); FR-A16-006 now requires them in the contract.
- [x] CHK009 Are negative rules (no EGL path, no second renderer, no ProjectM, no network, no accuracy, prediction or certification claims, no cluster computation, no multi-user experiments, no pass reading the texture it writes, no images, no unlicensed presets or copy) stated? [Spec §FR-A16-006] — yes.
- [x] CHK010 Are precision and boundary assumptions for later phases decided without claiming tolerances now? [Clarifications Q5] — yes.

## iOS lifecycle

- [x] CHK011 Is the inventory of the host's thread rule, the session lifecycle and target rebuild after context loss required? [Spec §FR-A16-001, plan Lifecycle contracts] — yes.

## Privacy and release constraints

- [x] CHK012 Is the absence of new data, permissions and interface in this phase stated, and is the capture's posture (share sheet, no new usage string) decided for later phases? [Spec §Edge Cases, Clarifications Q4] — yes.
- [x] CHK013 Is "nothing visible to a person" made checkable (registry and catalog unchanged)? [Spec §FR-A16-005, SC-A16-005] — yes.
- [x] CHK014 Is the no-change rule for VisualCore and ProjectM measurable from a named commit? [Clarifications facts, SC-A16-005] — yes (`1006181f`).

## Testability and measurability

- [x] CHK015 Are all success criteria tied to a runnable check, with the expected registered-experience count stated? [SC-A16-001–006, quickstart] — yes (15, none A16).

## Performance

- [x] CHK016 Are performance claims excluded from this phase, with only command-time bounds? [Spec §SC-A16-006] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
