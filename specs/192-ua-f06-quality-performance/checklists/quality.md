# Requirements Quality Checklist: UA-F06 — Quality profiles and performance observability

**Purpose**: Unit tests for the requirements of UA-F06: completeness, clarity, consistency, measurability,
lifecycle and failure coverage, privacy and no-advertising constraints, accessibility, the split between
simulator-verifiable and device-only requirements, and traceability to the sources.
**Created**: 2026-11-12
**Feature**: [spec.md](../spec.md)
**Depth**: standard · **Audience**: reviewer before `/speckit-tasks`

**Ownership**: `[x]` means the reviewer found the requirements-quality criterion satisfied; it says nothing
about the implementation. Under the owner's standing delegation the lead evaluated every item on 2026-11-12; the
evaluation follows each item. Items that failed at first are marked "corrected" with what was changed in spec.md.

## Requirement Completeness

- [x] CHK001 Are requirements present for each of the six acceptance items of the brief? [Completeness, Spec §Traceability] — yes: the traceability table maps each item to requirements and success criteria.
- [x] CHK002 Are the budgets a quality level states enumerated with their ranges? [Completeness, Spec §FR-U06-002] — yes: four budgets with ranges and the ordering rule.
- [x] CHK003 Are all fields of the performance record listed in one requirement? [Completeness, Spec §FR-U06-040] — corrected: the frame-rate cap, the resolution factor, the pin, the rebuilds and the memory-pressure events were named in FR-U06-014 and the edge cases but missing from FR-U06-040; added.
- [x] CHK004 Is it specified who may change the level and when (open, running, suspended, closed)? [Completeness, Spec §FR-U06-010, §FR-U06-011, §FR-U06-013] — yes.
- [x] CHK005 Are requirements defined for the moment a launch time starts and ends? [Completeness, Spec §FR-U06-024] — corrected: the start was defined, "first start after an installation" was not; now defined as a start without stored preferences, and the unobservable part is named.
- [x] CHK006 Is the document of budgets specified with its required columns and its check? [Completeness, Spec §FR-U06-060, §FR-U06-061] — yes.

## Requirement Clarity

- [x] CHK007 Is "on time" for a display refresh defined with a number? [Clarity, Spec §FR-U06-030] — corrected: FR-U06-030 counted on-time refreshes without defining them; the one-and-a-half-period rule was added.
- [x] CHK008 Is "interactive" defined, so that a late compilation can be told from an early one? [Clarity, Spec §FR-U06-022] — corrected: defined as the moment the session runs after the activation.
- [x] CHK009 Is "no unbounded growth" quantified? [Clarity, Spec §FR-U06-051] — yes: warm-up tenth, graphics bytes not above the warm-up maximum, footprint margin of 8 MiB or 5%.
- [x] CHK010 Is "ten minutes" unambiguous? [Clarity, Spec §Clarifications, §FR-U06-050] — yes: 72,000 steps, at least 36,000 drawn frames, experience time.
- [x] CHK011 Is the meaning of an absent value distinguished from zero? [Clarity, Spec §FR-U06-021] — yes.
- [x] CHK012 Is the Low Power level stated as a number? [Clarity, Spec §FR-U06-010] — yes: level 1, or the only level.

## Requirement Consistency

- [x] CHK013 Do the requirements for a pinned level agree between this feature and the override of UA-F04? [Consistency, Spec §FR-U06-012, §FR-U06-015] — yes: same range, undeclared level becomes the last level, no schema change.
- [x] CHK014 Are the level limits consistent (8 levels in the profile, override 0 to 7, 8 catalog names)? [Consistency, Spec §FR-U06-001, §Assumptions] — yes.
- [x] CHK015 Is the statement that shaders compile "during prepare" consistent with a preparation that has no display context? [Consistency, Spec §Clarifications] — yes after clarification 1; FR-U06-020 says set-up after the preparation.
- [x] CHK016 Do the frame-pacing reaction that exists and the new level decisions have a stated relation? [Consistency, Spec §FR-U06-014] — yes: both stay, they multiply, both are in the record.
- [x] CHK017 Does the rule "no on-screen meter" agree with the frame meter of Auto-Creator.md section 12.6? [Consistency, Spec §FR-U06-043, §Assumptions] — corrected: the section's meter was not mentioned; an assumption now gives it to UA-F09 on top of this feature's counts.

## Acceptance Criteria Quality

- [x] CHK018 Does every success criterion carry a count or a percentage that a test can decide? [Measurability, Spec §Success Criteria] — yes: ten criteria, each with numbers.
- [x] CHK019 Can SC-U06-006 be verified exactly, given that percentiles depend on the method? [Measurability, Spec §SC-U06-006, §FR-U06-032] — yes: bounded data implies a fixed method; the plan fixes bins, and the expected values follow from it.
- [x] CHK020 Is each success criterion traceable to requirements? [Traceability, Spec §Traceability] — yes.

## Scenario Coverage

- [x] CHK021 Are requirements defined for an open that fails and for one that is cancelled? [Coverage, Spec §Edge Cases, §FR-U06-021] — yes.
- [x] CHK022 Are requirements defined for suspension, resume and interruptions for both the level and the pacing? [Coverage, Spec §FR-U06-011, §FR-U06-031] — yes.
- [x] CHK023 Are requirements defined for a replaced display context? [Coverage, Spec §FR-U06-022] — yes: a rebuild, never a late compilation.
- [x] CHK024 Are requirements defined for memory pressure? [Coverage, Spec §Edge Cases, §FR-U06-040] — corrected with CHK003: the event count is now in the record; the level is unchanged by it.
- [x] CHK025 Are requirements defined for a damaged or newer performance record? [Coverage, Spec §FR-U06-041] — yes.
- [x] CHK026 Is the retry of a failed open covered for the level in force? [Coverage, Spec §FR-U06-013] — yes.

## Edge Case Coverage

- [x] CHK027 Are one-level experiences, oscillating conditions and clock anomalies addressed? [Edge Case, Spec §Edge Cases] — yes.
- [x] CHK028 Is the case without a display addressed for the first present time? [Edge Case, Spec §Edge Cases] — yes: absent, and the record says nothing was presented.
- [x] CHK029 Is a run of arbitrary length addressed for the memory of the measurements? [Edge Case, Spec §FR-U06-032] — yes.

## Non-Functional Requirements

- [x] CHK030 Are privacy requirements for the record specified (content, transmission)? [Privacy, Spec §FR-U06-042, §FR-U06-072] — yes: nothing identifying beyond the evidence record, never leaves the device, declared reasons where needed.
- [x] CHK031 Do the requirements exclude advertising, analytics, tracking and network use? [No-advertising, Spec §FR-U06-072] — yes.
- [x] CHK032 Are accessibility requirements stated for the one interface change? [Accessibility, Spec §FR-U06-015] — corrected: the settings text had no accessibility requirement; string resource, wrapping at the largest size and the audit were added.
- [x] CHK033 Is the measuring itself required not to change results? [Determinism, Spec §FR-U06-034] — yes.
- [x] CHK034 Is test access required to be absent from release builds? [Security, Spec §FR-U06-043] — yes.

## Simulator and device split

- [x] CHK035 Is it stated which outcomes are verified on simulators and that none is device performance? [Clarity, Spec §Success Criteria] — corrected: a sentence now says all ten are host or simulator outcomes and names the device task.
- [x] CHK036 Is the device-only work one explicit requirement with its sample count and its gate? [Completeness, Spec §FR-U06-073] — yes.
- [x] CHK037 Do the requirements forbid presenting simulator numbers as results, with a check? [Coverage, Spec §FR-U06-061, §FR-U06-062] — yes.
- [x] CHK038 Are conditions that a simulator cannot produce (heat, Low Power Mode, battery) given a stated way of proof or exclusion? [Assumption, Spec §Assumptions] — yes: scripted conditions; battery is device-only.

## Dependencies, Assumptions and Traceability

- [x] CHK039 Is the dependency on UA-F09 for the complete evidence record and its tool documented? [Dependency, Spec §Clarifications, §Canonical overrides] — yes.
- [x] CHK040 Is every unique requirement of the absorbed archive features listed as adopted, adapted or superseded with a reason? [Traceability, Spec §Absorbed source requirements] — yes: 16 rows.
- [x] CHK041 Are the names taken from the brief marked as existing or new? [Traceability, Spec §Canonical overrides] — yes: `QualityProfile` is new, the five others exist.
- [x] CHK042 Is anything in the requirements in conflict with ADR-0009 or the constitution? [Conflict] — no conflict found: one app, no new renderer, pure logic in the pure package, public interfaces only.

## Notes

- 42 items; 34 passed at once, 8 failed and were corrected in spec.md (CHK003, CHK005, CHK007, CHK008, CHK017,
  CHK024, CHK032, CHK035); after the corrections 42 of 42 pass.
- `/speckit-implement` reads the state of this checklist and does not change it.
