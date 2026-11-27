# Requirements Quality Checklist: R02-G21-09 simulator integration and full app lock

**Purpose**: Unit tests for the requirements of feature 509 (identifiers, interface journeys, schema examples,
release configuration, candidate availability, prerequisites, evidence)
**Created**: 2026-11-27
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-27, following feature 499's checklist, after the
items were generated in this skill invocation; failures were corrected in the artifacts.

## Identifiers

- [x] CHK001 Is every panel control the tests use named with its exact identifier and the shared prefix, and is the
  full list pinned and checked unique? [Completeness, Spec §FR-R02G2109-001; Clarifications Q1]
- [x] CHK002 Is it stated which panel texts are not controls and carry no identifier (the level line), so FR-001's
  scope is exact? [Clarity, Spec §Clarifications Q1]
- [x] CHK003 Is the alignment rule stated for names that prerequisites 505 … 507 build differently? [Consistency, Spec
  §Clarifications Q1]

## Interface journeys

- [x] CHK004 Is the end-to-end journey stated step by step (open, dismiss the tutorial, choose star 2, the luminosity
  change counted by the actions left, Run) with the texts the tests read? [Clarity, Spec §Clarifications Q2]
- [x] CHK005 Is the save point before a relaunch addressed (background before terminate)? [Edge Case, Spec §Edge Cases]
- [x] CHK006 Is each interface test bounded in time (under 90 s plus setup, inside the 180 s allowance) and placed in a
  named serial chunk whose key is unique? [Clarity, Spec §Clarifications Q2]

## Schema examples

- [x] CHK007 Are both earlier schemas (1 and 2) covered with their exact contents (the schema-1 action named, the
  certified count defined without the run) and the expected restore into schema 3? [Completeness, Spec
  §Clarifications Q3]
- [x] CHK008 Is the registration comment's correction stated? [Consistency, Spec §Clarifications Q3]

## Release and availability

- [x] CHK009 Is release exclusion of test-only code stated with the symbols and the checks that prove it? [Completeness,
  Spec §Clarifications Q4]
- [x] CHK010 Are both sides of candidate availability defined (unavailable without the testing argument, openable with
  it)? [Coverage, Spec §Clarifications Q5]
- [x] CHK011 Is all-level solvability tied to a named regression with a measurable result (100 of 100)?
  [Measurability, Spec §Success Criteria]

## Prerequisites and evidence

- [x] CHK012 Is the prerequisite state current (R02-G21-04 recorded; 05 … 08 recorded before implementation)?
  [Consistency, Spec §Canonical overrides]
- [x] CHK013 Are both build configurations and the reference regression named as required evidence? [Completeness,
  Spec §Success Criteria]
- [x] CHK014 Are device-only journeys separated as {device} with their later feature (510)? [Scope, Spec
  §SC-R02G2109-006]
- [x] CHK015 Is it stated that this feature adds no visuals and no new layout (identifiers, tests and examples only)?
  [Consistency, Spec §Negative Requirements]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK002, CHK007 and CHK012 failed at first reading and were corrected in the spec: the level line was not named as a
  non-control; the schema-1 action was left unnamed and the certified count's treatment of the run unstated; and the
  header still called R02-G21-04 pending although it was recorded the same day.
