# Audit Requirements Quality Checklist: Aurora — Phase 00

**Purpose**: Unit tests for the requirements of A21-P00 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-17 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK013).

## Completeness

- [x] CHK001 Are all inventory areas of the manual's Phase 00 deliverable required (products, host, thread, shaders and resources, build steps, ownership, regression)? [Spec §FR-A21-001] — yes.
- [x] CHK002 Are all five brainstorm capabilities and six version 0.1 features required in the matrix, and are the six features named somewhere a reviewer can read? [Spec §FR-A21-002, SC-A21-001, research D2] — yes.
- [x] CHK003 Is the stop/go decision required with the conditions that force "stop"? [Spec §US4 AC2, FR-A21-006] — yes (a missing host, full-screen shader drawing or additive compositing over the existing renderer).

## Architecture ownership

- [x] CHK004 Does every gap name an owning module and phase? [Spec §FR-A21-003, SC-A21-002, research D4] — yes.
- [x] CHK005 Is the rule for "available" defined so that ownership is not claimed from another experience's code? [Clarifications Q2, Edge Cases] — yes (Ambient Clock's crossfade use and Digital Zen Garden's tones counted as experience use only).
- [x] CHK006 Are the expected gaps enumerated: scene and presets, ribbons, stars and clouds, the luminance cap, transitions and preferences, the rendered clock, low power and reduced flash, the ambient loop, hide and restore controls, the static fallback, rebuild and release of targets? [Spec §FR-A21-003] — yes.
- [x] CHK007 Is reuse of existing products required rather than left implicit (`FullScreenShaderScene`, `vc/`, `ParticleRenderer`, `CrossfadeScene`, `SceneClock`, `FramePacing`, `CachedScene`, `RenderCapabilities`, `ExperienceStorage`)? [Clarifications facts, plan Constitution Check II] — yes.
- [x] CHK008 Are the manual's three risks recorded with an owner, a verification method and a release-blocker condition? [Spec §FR-A21-006, data-model] — yes (battery drain, bright or flashing imagery, soundtrack licensing).
- [x] CHK009 Are the negative rules complete: no EGL path or second renderer, no ProjectM, no network or location, no private API, no forecast, scientific, therapeutic or sleep claim, no always-on promise, no required background audio, no bought, generated or photographic images or recordings? [Spec §FR-A21-006] — yes.

## Consistency

- [x] CHK010 Is the ambient-loop decision consistent between the constitution (sound is code), clarification Q4 (VisualCoreAudio upstream gap in A21-P04) and research D4 and D6? [Clarifications Q4, research] — yes.
- [x] CHK011 Is the luminance-cap ownership consistent between clarification Q3, research alternatives and the constitution's reuse rule (app-local now, upstream on a second user)? [Clarifications Q3, research] — yes.

## iOS lifecycle

- [x] CHK012 Are the host's main-thread rule, sound stopping on suspend, rendered time apart from wall-clock time, and context-loss rebuild required in the assessment? [Spec §FR-A21-001, FR-A21-003, plan lifecycle] — yes.

## Measurability and release constraints

- [x] CHK013 Are the numbers behind "comfort bounds" and the "luminance cap" either quantified or explicitly deferred to an owning phase? [Spec §FR-A21-003, research D4a] — failed (no owner for the numbers); research D4a now defers them to A21-P01 and A21-P02 with their tests.
- [x] CHK014 Is the absence of any permission and usage string stated? [Spec §Negative Requirements, research D5] — yes.
- [x] CHK015 Is "nothing visible to a person" made checkable, with the registry and catalog unchanged? [Spec §FR-A21-005, SC-A21-005] — yes.
