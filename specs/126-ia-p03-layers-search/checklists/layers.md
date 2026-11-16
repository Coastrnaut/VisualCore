# Layers, search and descriptions checklist: Interactive Anatomy — Phase 03

**Purpose**: unit tests for the requirements of search, the panel, isolate and ghosts, the saved view and the
VisualCore addition (feature 126).
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it does not mean the work is done.
Evaluated by the lead under the owner's standing delegation on 2026-11-16. Failing items were corrected in the
artifacts before they were ticked.

## Requirement Completeness

- [x] CHK001 Are matching, folding, ranking, the result limit and the empty query all specified for search? [Spec §FR-A17-301, Q1]
- [x] CHK002 Is every field of the panel named, including the text with nothing selected? [Spec §FR-A17-303, Q5]
- [x] CHK003 Are the isolate actions, targets, modes and "Show all" named with their effect on selection? [Spec §Q3, Story 3; corrected: "Show all" keeps the selection]
- [x] CHK004 Is the saved view's content, location, schema, migration and size cap specified? [Spec §FR-A17-307, Q4; corrected: the 65,536-byte cap]

## Requirement Clarity

- [x] CHK005 Is the ghost appearance quantified (layer material at alpha 0.25) and its draw order stated? [Spec §FR-A17-305, Q2]
- [x] CHK006 Is "bit-identical with no translucent items" stated as the measure of the VisualCore change? [Spec §FR-A17-306, SC-A17-303]
- [x] CHK007 Is the content change (version 2, four synonyms) named exactly? [Spec §Q1, Assumptions]

## Requirement Consistency

- [x] CHK008 Do the picking, list and search rules agree that only solid parts are selectable under isolate? [Spec §Q3, FR-A17-302, 305]
- [x] CHK009 Are the layer toggles of A17-P02 and isolate consistent (isolate overrides the toggles for its set until "Show all")? [Spec §Edge Cases, Q3]

## Scenario and Edge Case Coverage

- [x] CHK010 Are the failure paths covered: a failing ghost draw, damaged, newer or too-large files, unknown ids and a failed write? [Spec §Edge Cases, Story 4; corrected: the failed write was added]
- [x] CHK011 Are diacritics, spaces and shared words in queries covered? [Spec §Edge Cases]

## Architecture, Lifecycle, Privacy and Release

- [x] CHK012 Is the translucent stage placed in VisualCore with docs, tests, the API baseline and the reference regression at X-A17? [Spec §FR-A17-306; plan §Constitution II-a]
- [x] CHK013 Is the view stored only locally, and is no network or asset added? [Spec §Negative Requirements]
- [x] CHK014 Is the regeneration of the generated sources document and its failing check specified? [Spec §FR-A17-308, Q5]
- [x] CHK015 Are the test time limit and runtime stated? [Spec §SC-A17-305]

## Notes

- `/speckit-implement` reads this checklist's state; it does not change the markers.
