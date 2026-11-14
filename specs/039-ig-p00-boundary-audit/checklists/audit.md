# Audit Requirements Quality Checklist: Infinite Geometry — Phase 00

**Purpose**: Unit tests for the requirements of A05-P00 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-13
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-13; failed items were corrected in the spec before continuing.

## Completeness

- [x] CHK001 Are all inventory areas of the manual's Phase 00 deliverable (products, host, thread, shaders/resources, build steps, ownership, regression) required? [Spec §FR-A05-001] — yes.
- [x] CHK002 Are all five brainstorm capabilities and six version 0.1 features required in the matrix? [Spec §FR-A05-002, SC-A05-001] — yes.
- [x] CHK003 Is the stop/go decision required with the conditions that force "stop"? [Spec §US4 AC2, FR-A05-006] — yes (missing host or mesh path).

## Architecture ownership

- [x] CHK004 Does every gap name an owning VisualCore module and phase? [Spec §FR-A05-003] — yes.
- [x] CHK005 Is the rule for "available" defined so ownership is not claimed from harness code? [Clarifications Q4, Edge Cases] — yes.
- [x] CHK006 Are negative rules (no EGL path, no second renderer, no ProjectM, no networking, no imported assets, no exactness claims) stated? [Spec §FR-A05-006] — yes.

## iOS lifecycle

- [x] CHK007 Is the inventory of the host's thread rule and the session lifecycle required? [Spec §FR-A05-001, plan Lifecycle contracts] — yes.

## Privacy and release constraints

- [x] CHK008 Is the absence of data, permissions and interface in this phase stated? [Spec §Edge Cases] — yes.
- [x] CHK009 Is "nothing visible to a person" made checkable (registry and catalog unchanged)? [Spec §FR-A05-005, SC-A05-005] — yes.
- [x] CHK010 Is the no-change rule for VisualCore and ProjectM measurable from a named commit? [Clarifications Q2, SC-A05-005] — yes.

## Testability and measurability

- [x] CHK011 Are all success criteria tied to a runnable check? [SC-A05-001–005, quickstart] — yes.
- [x] CHK012 Is every success criterion applicable to this phase? [Conflict, SC-A05-006] — failed first: SC-A05-006 ("every new test under 10 s") applies to no test, since this phase adds none after clarification 1. Corrected: SC-A05-006 now bounds the phase's checks (contract checker under 10 s; each regression chunk and the app build under 10 minutes).

## Performance

- [x] CHK013 Are performance claims excluded from this phase? [Spec §Assumptions, constitution A05 truthful claims] — yes (none made).

## Notes

- One item failed on first evaluation (CHK012); corrected in spec.md.
