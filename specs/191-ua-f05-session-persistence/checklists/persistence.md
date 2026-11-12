# Requirements Quality Checklist: UA-F05 — Session state, per-experience persistence, reset and restore

**Purpose**: Unit tests for the requirements of UA-F05: completeness, clarity, consistency, measurability,
lifecycle and failure coverage, privacy and no-advertising constraints, accessibility, the split between
simulator-verifiable and device-only requirements, and traceability to the sources.
**Created**: 2026-11-12
**Feature**: [spec.md](../spec.md)
**Depth**: standard · **Audience**: reviewer before `/speckit-tasks`

**Ownership**: `[x]` means the reviewer found the requirements-quality criterion satisfied; it says nothing
about the implementation. Under the owner's standing delegation the lead evaluated every item on 2026-11-12; the
evaluation follows each item. Items that failed at first are marked "corrected" with what was changed in spec.md.

## Requirement Completeness

- [x] CHK001 Are requirements present for each of the six acceptance items of the brief? [Completeness, Spec §Traceability] — yes: the traceability table maps each to requirements and success criteria.
- [x] CHK002 Are all operations of the storage handle and its limits specified? [Completeness, Spec §FR-U05-002 to FR-U05-005] — yes: read, write, list, remove; names; quotas; atomic writes.
- [x] CHK003 Is every moment at which a state is saved, and every moment at which it is not, listed? [Completeness, Spec §FR-U05-010, §FR-U05-011, §FR-U05-014] — yes.
- [x] CHK004 Are all kinds of unreadable state enumerated? [Completeness, Spec §FR-U05-030] — yes: eight kinds, the same list as SC-U05-004 plus a content that does not give its digest.
- [x] CHK005 Is it specified what both resets remove, including values under the prefix and quarantined copies? [Completeness, Spec §FR-U05-040, §FR-U05-041] — yes.
- [x] CHK006 Is it specified whether the saved state counts against the experience's quota? [Completeness, Spec §FR-U05-004] — corrected: the requirement was silent; the saved state and quarantined copies do not count.
- [x] CHK007 Are the areas the inventory covers enumerated? [Completeness, Spec §FR-U05-060] — yes: documents, application support, caches, preferences, temporary files, the defaults domain.

## Requirement Clarity

- [x] CHK008 Is a valid name defined exactly? [Clarity, Spec §FR-U05-003] — yes: length, characters, no leading dot, reserved names.
- [x] CHK009 Is "safe point" replaced by something a test can decide? [Clarity, Spec §FR-U05-011, §Clarifications] — yes: an accepted action, followed by a save within 5 seconds.
- [x] CHK010 Is the bound on the time a save may take stated in a verifiable way? [Clarity, Spec §FR-U05-013] — corrected: "not longer than one save of the largest state takes" could not be decided; now one write of at most 1 MiB, never repeated in a loop.
- [x] CHK011 Is "no deliberate crash on bad data" defined so that a check can decide it? [Clarity, Spec §FR-U05-071] — corrected: now names forced unwraps, forced `try`, traps and preconditions in the sources that read stored data, with a check.
- [x] CHK012 Is the number of quarantined copies and the order of removal stated? [Clarity, Spec §FR-U05-032] — yes: 3, oldest first.
- [x] CHK013 Is "the diagnostics" identified? [Clarity, Spec §FR-U05-013, §FR-U05-031] — corrected: now "the app's diagnostics" (the record of UA-F04).

## Requirement Consistency

- [x] CHK014 Do the save rules agree between the user story and the requirements (a state equal to the stored one is not written)? [Consistency, Spec §US1, §FR-U05-011] — yes after the clarification.
- [x] CHK015 Is the Reset of the message consistent with the reset in the settings? [Consistency, Spec §FR-U05-033, §FR-U05-040, §FR-U05-044] — yes: the message's Reset quarantines and starts afresh; the settings' reset removes the namespace including quarantined copies; both are confirmed actions.
- [x] CHK016 Does the description of a quarantined copy agree with how it is kept? [Consistency, Spec §Key Entities, §FR-U05-032] — corrected: the entity promised a time and a reason with each copy; it now says a numbered name, with the reason in the diagnostics.
- [x] CHK017 Is the handling of the app's own unreadable session state consistent between the edge case and the requirement? [Consistency, Spec §Edge Cases, §FR-U05-052] — corrected: the edge case said "not overwritten before a preference changed", which contradicts restoring the route; both now say one copy is kept before it is overwritten.
- [x] CHK018 Are the limits consistent (1 MiB state, 16 MiB quota, 64 files, 3 copies)? [Consistency, Spec §FR-U05-004, §FR-U05-012, §FR-U05-032] — yes.

## Acceptance Criteria Quality

- [x] CHK019 Does every success criterion carry a count or a percentage a test can decide? [Measurability, Spec §Success Criteria] — yes: ten criteria with numbers.
- [x] CHK020 Is SC-U05-003 decidable without waiting for wall-clock time in a test? [Measurability, Spec §SC-U05-003] — yes: the 5 seconds and the 30 seconds are properties of a schedule that a scripted clock can drive.
- [x] CHK021 Is each success criterion traceable to requirements? [Traceability, Spec §Traceability] — yes.

## Scenario Coverage

- [x] CHK022 Are primary, alternate (leave and reopen), exception (unreadable), and recovery (Reset, Back) flows all specified? [Coverage, Spec §US1, §US2] — yes.
- [x] CHK023 Are requirements defined for a save that fails and for an interrupted save? [Coverage, Spec §FR-U05-013, §FR-U05-015, §Edge Cases] — yes.
- [x] CHK024 Are requirements defined for a failed experience and a cancelled preparation? [Coverage, Spec §FR-U05-014] — yes.
- [x] CHK025 Are suspension, repeated suspension notices and memory pressure covered? [Coverage, Spec §Edge Cases, §FR-U05-010] — yes.
- [x] CHK026 Is the case of an experience that is no longer available covered for stored data and for resets? [Coverage, Spec §Edge Cases, §FR-U05-041] — yes.
- [x] CHK027 Is a reset while an experience is open, and while the message is shown, covered? [Coverage, Spec §FR-U05-042, §Edge Cases] — yes.

## Edge Case Coverage

- [x] CHK028 Are escaping names (parent folders, absolute paths, separators, another prefix) named as cases? [Edge Case, Spec §US3, §SC-U05-001] — yes: 20 attempts.
- [x] CHK029 Is a stored state above the size limit addressed without loading it? [Edge Case, Spec §Edge Cases, §FR-U05-030] — yes.
- [x] CHK030 Is the leftover temporary file of an interrupted save addressed? [Edge Case, Spec §FR-U05-015] — yes.

## Non-Functional Requirements

- [x] CHK031 Are accessibility requirements stated for the one new screen? [Accessibility, Spec §FR-U05-031] — corrected: the message had only "plain words"; string resources, 44-point actions, the largest text size and the audit were added.
- [x] CHK032 Do the requirements exclude sync, network and shared containers? [Privacy, Spec §FR-U05-070] — yes.
- [x] CHK033 Do the requirements exclude stored unlock flags, advertising and tracking values and accounts? [No-advertising, Spec §FR-U05-063] — yes: the allow-list may not contain them.
- [x] CHK034 Is test access required to be absent from release builds? [Security, Spec §FR-U05-073] — yes.
- [x] CHK035 Is the migration of the app's own session state specified measurably? [Measurability, Spec §FR-U05-052] — corrected: "a later version MUST migrate" could not be tested today; now a check fails when a version below the current one has no migration.

## Simulator and device split

- [x] CHK036 Is it stated which outcomes are verified on simulators and which on devices? [Clarity, Spec §Success Criteria, §FR-U05-074] — yes.
- [x] CHK037 Is the device-only work one explicit requirement with its gate? [Completeness, Spec §FR-U05-074] — yes.
- [x] CHK038 Is the provenance rule for system-written items stated so that a simulator observation is not presented as a device fact? [Clarity, Spec §FR-U05-061, §Clarifications] — yes: each entry names its observation.

## Dependencies, Assumptions and Traceability

- [x] CHK039 Are the dependencies on UA-F03 (session, sink) and UA-F04 (session state, resets) documented? [Dependency, Spec §Canonical overrides] — yes.
- [x] CHK040 Is every unique requirement of the absorbed archive feature listed as adopted, adapted or superseded with a reason? [Traceability, Spec §Absorbed source requirements] — yes: 14 rows.
- [x] CHK041 Are the names taken from the brief marked as existing or new? [Traceability, Spec §Canonical overrides] — yes.
- [x] CHK042 Is anything in the requirements in conflict with ADR-0009 or the constitution? [Conflict] — no conflict found: namespaces derive from the canonical ids; no unlock flag is stored; pure logic is host-tested.

## Notes

- 42 items; 34 passed at once, 8 failed and were corrected in spec.md (CHK006, CHK010, CHK011, CHK013, CHK016,
  CHK017, CHK031, CHK035); after the corrections 42 of 42 pass.
- `/speckit-implement` reads the state of this checklist and does not change it.
