# Requirements Quality Checklist: Effects Composer — Phase 06 release

**Purpose**: Unit tests for the requirements of feature 185 (completeness, privacy, ownership, lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-19; failures were corrected in the artifacts.

## Requirement Completeness

- [x] CHK001 Is every stored item named with its place and removal? [Completeness, Spec §FR-A25-601, Clarifications]
- [x] CHK002 Is the only permission (add-only Photos) named with its usage string and when it is asked? [Completeness, Clarifications]
- [x] CHK003 Are all nine sample files and their expected outcomes listed? [Completeness, Clarifications, data-model]
- [x] CHK004 Are the known limitations to publish listed? [Gap → corrected: Spec §FR-A25-606]
- [x] CHK005 Is the artifact inventory (`requiredDocs`) defined? [Completeness, data-model release.json]

## Requirement Clarity

- [x] CHK006 Is the refused vocabulary of the claims scan listed word by word? [Clarity, Clarifications Q2]
- [x] CHK007 Is the source scan's allow rule (one file, each surface required) unambiguous? [Clarity, Clarifications Q3]
- [x] CHK008 Are the checklist statuses enumerated? [Clarity, Clarifications Q1]

## Requirement Consistency

- [x] CHK009 Is the export folder's lifetime consistent with A25-P05 (removed before the next export and on close)? [Consistency, Clarifications]
- [x] CHK010 Is the catalog summary rule consistent with the catalog search tests (keeps "shader", ≤ 300 characters)? [Consistency, Spec §FR-A25-605]
- [x] CHK011 Do the device rows referenced match `device-campaign.md` (EC-D1 … EC-D7)? [Consistency, Clarifications Q1]

## Acceptance Criteria Quality

- [x] CHK012 Are all success criteria countable (0 uses, 100% files, 9 of 9, < 60 s)? [Measurability, Spec §SC-A25-601…606]

## Scenario Coverage

- [x] CHK013 Are recovery requirements defined for a drawing failure with saved looks? [Recovery, Spec §FR-A25-603]
- [x] CHK014 Are migration requirements defined for newer and damaged files of every stored kind? [Exception, Spec §FR-A25-604]
- [x] CHK015 Is the first-session flow defined? [Primary, Spec §US4]

## Edge Case Coverage

- [x] CHK016 Are leftovers of a killed session and oversized look files addressed? [Edge Case, Spec §Edge Cases]

## Non-Functional Requirements

- [x] CHK017 Is privacy covered by both a document and a scan? [Privacy, Spec §FR-A25-601, 602]
- [x] CHK018 Are accessibility requirements traced (spoken labels in the journey; audits on devices)? [Gap → corrected: Clarifications Q5]
- [x] CHK019 Is it explicit that no performance number is claimed before the device campaign? [Performance, Spec §Negative Requirements]

## Dependencies & Assumptions

- [x] CHK020 Is the release checker's discovery of `release.json` stated? [Dependency, plan Technical Context]
- [x] CHK021 Are owner-only steps stated as owner actions? [Release, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
