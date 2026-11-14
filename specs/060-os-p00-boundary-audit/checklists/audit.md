# Audit Requirements Quality Checklist: Oscilloscope Studio — Phase 00

**Purpose**: Unit tests for the requirements of A08-P00 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); no item failed.

## Completeness

- [x] CHK001 Are all inventory areas of the manual's Phase 00 deliverable (products, host, thread, shaders/resources, build steps, ownership, regression) required? [Spec §FR-A08-001] — yes.
- [x] CHK002 Are all five brainstorm capabilities and six version 0.1 features required in the matrix? [Spec §FR-A08-002, SC-A08-001] — yes.
- [x] CHK003 Is the stop/go decision required with the conditions that force "stop"? [Spec §US4 AC2, FR-A08-006] — yes (missing host or buildable audio path).

## Architecture ownership

- [x] CHK004 Does every gap name an owning VisualCore module and phase? [Spec §FR-A08-003, SC-A08-002] — yes.
- [x] CHK005 Is the rule for "available" defined so ownership is not claimed from another experience's or a harness's code? [Clarifications Q2, Edge Cases] — yes.
- [x] CHK006 Are the expected gaps (trigger and timebase window, min/max decimation, square and sweep demo, two-channel capture, multi-point trace strips, spectrum annotation) named with owners? [Spec §FR-A08-003, Clarifications Q5] — yes.
- [x] CHK007 Is reuse of the shared audio products (sources, permission, ring buffer, spectrum, demo tones) required rather than left implicit? [Spec §FR-A08-002, Clarifications Q4] — yes.
- [x] CHK008 Are negative rules (no EGL path, no second renderer, no ProjectM, no networking, no audio leaving the device, no system-audio capture, no microphone monitoring to the speaker, no calibrated, certified, laboratory or medical accuracy claims) stated? [Spec §FR-A08-006] — yes.

## iOS lifecycle

- [x] CHK009 Is the inventory of the host's thread rule and the session and audio-source lifecycle required? [Spec §FR-A08-001, plan Lifecycle contracts] — yes.

## Privacy and release constraints

- [x] CHK010 Is the absence of new data, permissions and interface in this phase stated, and the shared microphone string recorded? [Spec §Edge Cases, Clarifications Q4] — yes.
- [x] CHK011 Is "nothing visible to a person" made checkable (registry and catalog unchanged)? [Spec §FR-A08-005, SC-A08-005] — yes.
- [x] CHK012 Is the no-change rule for VisualCore and ProjectM measurable from a named commit? [Clarifications facts, SC-A08-005] — yes (`6fdb5ca9`).

## Testability and measurability

- [x] CHK013 Are all success criteria tied to a runnable check? [SC-A08-001–006, quickstart] — yes.
- [x] CHK014 Is the expected registered-experience count stated so the package check is measurable? [SC-A08-004] — yes (7, none A08).

## Performance

- [x] CHK015 Are performance claims excluded from this phase, with only command-time bounds? [Spec §SC-A08-006, constitution A08 truthful claims] — yes.

## Edge cases

- [x] CHK016 Are mono-only sources and the units/calibration limit (relative dBFS, no calibrated volts or SPL) recorded as rules or gaps instead of being assumed away? [Spec §Edge Cases, FR-A08-003] — yes.

## Notes

- 16 items evaluated on 2026-11-14; none failed, so the spec is unchanged. `/speckit-implement` reads these markers
  and does not change them.
