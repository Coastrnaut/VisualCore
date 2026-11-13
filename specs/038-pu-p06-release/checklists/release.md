# Release Requirements Quality Checklist: Particle Universe — Phase 06

**Purpose**: Unit tests for the requirements of A04-P06 (privacy, ownership, lifecycle, testability, performance claims,
release constraints)
**Created**: 2026-11-13
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that the work is done. Evaluated by the lead
under the owner's standing delegation on 2026-11-13; failures were corrected in the spec before continuing.

## Requirement Completeness

- [x] CHK001 Are privacy requirements stated for permissions, usage strings, network, tracking and sensors? [Spec §FR-A04-601–602] — yes, each named.
- [x] CHK002 Is what the experience stores, and where, required to be documented? [Spec §FR-A04-604] — yes.
- [x] CHK003 Are migration requirements defined for every library file form (no format, format 1, newer, damaged)? [Spec §FR-A04-610–611, Edge Cases] — yes.
- [x] CHK004 Are crash-recovery requirements defined for the drawing failure and for retry? [Spec §FR-A04-612] — yes.
- [x] CHK005 Are build-and-archive requirements defined with owner steps separated? [Spec §FR-A04-620] — yes.
- [x] CHK006 Is the release record (checklist, inventory, store text, known limitations, device plan) fully enumerated? [Spec §FR-A04-630–633] — yes.

## Requirement Clarity

- [x] CHK007 Is "measured claim" defined precisely enough to be checked mechanically? [Clarity, Clarifications Q3] — yes, denylist classes listed.
- [x] CHK008 Is "interface strings" bounded to specific sources? [Clarity, Spec §FR-A04-631] — yes, the experience's interface strings; plan names the files.
- [x] CHK009 Are checklist statuses defined as a closed set? [Clarity, Spec §FR-A04-633] — yes, via the reused statuses (plan D4).

## Requirement Consistency

- [x] CHK010 Is the Reduce Motion requirement consistent with where the pause is actually issued? [Consistency, Spec §FR-A04-613] — failed first: FR-A04-613 required a *hosted* test of both; the pause is issued by the controls view, testable only by the one app's interface test. Corrected in the spec (FR-A04-613 now names the interface test for Reduce Motion and a session test for Reduce Flashing).
- [x] CHK011 Do the one-app override and the release documents' locations agree across spec and plan? [Consistency] — yes.
- [x] CHK012 Does "no VisualCore change" agree with every planned file? [Consistency, Spec §FR-A04-641] — yes, all files are in the experience package, scripts or docs.

## Acceptance Criteria Quality

- [x] CHK013 Are success criteria countable (fixtures 4/4, failure 1/1, 0 claims, document removal fails)? [Measurability, SC-A04-601–606] — yes.
- [x] CHK014 Is the negative case of the release document check part of an acceptance criterion? [SC-A04-604] — yes.

## Scenario and Edge Case Coverage

- [x] CHK015 Is the behaviour of an older build reading a newly written file addressed? [Gap, Edge Cases] — failed first: missing. Added an edge case (older readers ignore the extra `format` key).
- [x] CHK016 Are failure-before-first-frame and failure-during-rename addressed? [Edge Cases] — yes.
- [x] CHK017 Is accessibility audit deferral stated with its owner ruling? [Spec overrides, FR-A04-632] — yes.

## Non-Functional, Dependencies and Release Constraints

- [x] CHK018 Are performance statements limited to "pending device campaign" with no target numbers claimed? [Spec §FR-A04-631–632] — yes.
- [x] CHK019 Are owner-only actions listed and excluded from agent work? [Spec overrides, FR-A04-620] — yes.
- [x] CHK020 Is the dependency on X-A04 (standalone retirement, metadata inputs entry) stated as an assumption? [Assumptions] — yes.

## Notes

- Two items failed on first evaluation (CHK010, CHK015); both are corrected in spec.md.
