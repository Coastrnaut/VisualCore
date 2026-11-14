# Audit Requirements Quality Checklist: VisualCore Music Lab — Phase 00

**Purpose**: Unit tests for the requirements of A06-P00 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14; no item failed.

## Completeness

- [x] CHK001 Are all inventory areas of the manual's Phase 00 deliverable (products, host, thread, shaders/resources, build steps, ownership, regression) required? [Spec §FR-A06-001] — yes.
- [x] CHK002 Are all five brainstorm capabilities and six version 0.1 features required in the matrix? [Spec §FR-A06-002, SC-A06-001] — yes.
- [x] CHK003 Is the stop/go decision required with the conditions that force "stop"? [Spec §US4 AC2, FR-A06-006] — yes (missing host or buildable audio path).

## Architecture ownership

- [x] CHK004 Does every gap name an owning VisualCore module and phase? [Spec §FR-A06-003] — yes.
- [x] CHK005 Is the rule for "available" defined so ownership is not claimed from harness code? [Clarifications Q4, Edge Cases] — yes.
- [x] CHK006 Are negative rules (no EGL path, no second renderer, no ProjectM/MilkDrop reuse, no networking, no audio leaving the device, no system-audio capture, no measurement claims) stated? [Spec §FR-A06-006] — yes.

## iOS lifecycle

- [x] CHK007 Is the inventory of the host's thread rule and the session lifecycle required? [Spec §FR-A06-001, plan Lifecycle contracts] — yes.

## Privacy and release constraints

- [x] CHK008 Is the absence of data, permissions and interface in this phase stated? [Spec §Edge Cases] — yes.
- [x] CHK009 Is "nothing visible to a person" made checkable (registry and catalog unchanged)? [Spec §FR-A06-005, SC-A06-005] — yes.
- [x] CHK010 Is the no-change rule for VisualCore and ProjectM measurable from a named commit? [Clarifications Q2, SC-A06-005] — yes.

## Testability and measurability

- [x] CHK011 Are all success criteria tied to a runnable check? [SC-A06-001–005, quickstart] — yes.
- [x] CHK012 Is every success criterion applicable to this phase? [Conflict, SC-A06-006] — yes: the spec already restricts SC-A06-006 to tests this phase adds (text carried over corrected from the A05 audit).

## Audio ownership

- [x] CHK014 Is the ownership of audio analysis and audio sources between VisualCore products specified? [Clarifications, Spec §FR-A06-003] — yes (`VisualCoreAudioDSP`, `VisualCoreAudio`).
- [x] CHK015 Is the absence of a microphone permission in this phase stated, with the phase that adds it? [Clarifications] — yes (A06-P01).

## Performance

- [x] CHK013 Are performance claims excluded from this phase? [Spec §Assumptions, constitution A06 truthful claims] — yes (none made).

## Notes

- 15 items evaluated on 2026-11-14; none failed (the CHK012 correction was already in the text carried over from A05).
