# Geometry Requirements Quality Checklist: R02-F05 — Procedural mesh compiler and mesh validation

**Purpose**: Unit tests for the requirements of R02-F05 (player impact, deterministic invariants, empty and error
states, source license, code-only feasibility, layout, simulator proof, device evidence)
**Created**: 2026-11-13
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-13; failed items were corrected in the spec before continuing.

## Player impact and completeness

- [x] CHK001 Is the visible consequence of a bad mesh (holes, inside-out faces, wrong shading) stated as the reason for the feature? [Spec §User Story 1–2] — yes.
- [x] CHK002 Are all seven purposes of the source (indexed vertices, surfaces, bevels, tubes, manifold validation, normals, bounds) covered by requirements? [Traceability table] — yes.
- [x] CHK003 Are the shapes enumerated with their parameters? [Spec §FR-R02F05-010–015, contracts/api.md] — yes.

## Deterministic invariants

- [x] CHK004 Is byte-for-byte determinism defined with a concrete digest construction? [Spec §FR-R02F05-051, Clarifications] — yes.
- [x] CHK005 Are tolerances for welding, unit normals, ranges and degeneracy quantified? [Clarifications] — yes.
- [x] CHK006 Is the validation report's order fixed so that reports are comparable? [Clarifications, FR-R02F05-031] — yes.

## Empty and error states

- [x] CHK007 Is the empty mesh's validity and bounds defined? [Spec §Edge Cases, US3 AC2] — yes.
- [x] CHK008 Are budget refusals defined as all-or-nothing? [Spec §FR-R02F05-050] — yes.
- [x] CHK009 Are invalid inputs (fewer than two distinct path points, self-intersecting outline, oversized bevel) specified? [Spec §Edge Cases, research D5] — yes.
- [x] CHK010 Is a zero bevel radius specified? [Gap] — failed first: missing. Added: radius 0 gives a plain box.

## Acceptance criteria quality

- [x] CHK011 Does the number of planted defect kinds in the success criteria equal the kinds listed in the requirements? [Conflict, SC-R02F05-002 vs FR-R02F05-030] — failed first: SC said 12, the requirements and data model list 14 (13 defects plus budget). Corrected to 14.
- [x] CHK012 Is the volume criterion unambiguous for faceted shapes at low resolution? [Ambiguity, SC-R02F05-001] — failed first: "within 1% of the analytic volume" fails a 3-sided tube by construction. Corrected: exact faceted volume within 1e-6 relative at every resolution, and within 1% of the smooth solid at the highest resolution.
- [x] CHK013 Is a timing criterion stated with a measurable bound and place? [SC-R02F05-006] — yes, < 1 s on the host at the budget.

## Source license and code-only feasibility

- [x] CHK014 Is the code-only, no-asset rule stated? [Spec §FR-R02F05-071] — yes.
- [x] CHK015 Are the algorithms original or from cited public methods with no copied code? [research D1–D9] — yes (double-reflection frames cited as a method; implementation original).

## Layout, simulator proof and device evidence

- [x] CHK016 Is the absence of interface (and thus of iPad/iPhone layout requirements) stated? [Spec §FR-R02F05-072] — yes.
- [x] CHK017 Is simulator proof required on both runtimes? [SC-R02F05-003, plan] — yes.
- [x] CHK018 Is the absence of device-only items justified? [Spec overrides] — yes (CPU-only; drawing by the existing renderer).

## Dependencies and compatibility

- [x] CHK019 Are compatibility requirements for existing generators and renderer stated and measurable? [Spec §FR-R02F05-060, SC-R02F05-005] — yes.
- [x] CHK020 Is the reference regression requirement stated? [Spec §FR-R02F05-061] — yes.

## Notes

- Three items failed on first evaluation (CHK010–CHK012); all are corrected in spec.md.
