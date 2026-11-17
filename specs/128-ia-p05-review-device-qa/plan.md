# Implementation Plan: Interactive Anatomy — Phase 05 Scientific review and device QA

**Branch**: `128-ia-p05-review-device-qa` (spec directory only; work on `main`) | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

This phase builds G-REVIEW with no VisualCore change.

- **Core:**
  - the review record, a resource `knee-right.review.json`: a `DocumentEnvelope` of kind `a17.review-record`,
    schema 1, holding 14 editorial entries;
  - `AnatomyReviewRecord` with its validation against the pack;
  - `AnatomyReview` to make the panel's review lines and the model statement;
  - `AnatomyPanel` extended with the review lines and the statement;
  - the generated review table in `docs/apps/interactive-anatomy/review.md`.
- **Experience:**
  - the panel shows the statement and the review lines;
  - an "About this model" row;
  - a list-only test that proves the VoiceOver fixture.
- **Docs:** `device-campaign.md` with the {device} rows.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract: [contracts/review.md](contracts/review.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6.
- **Dependencies:** existing ones only (VisualCorePersistence `DocumentEnvelope`; VisualCoreMath).
- **Storage:** one more bundle resource (the record, ≤ 64 KB).
- **Testing:** core and experience tests on sim-27.2; app build and unit; runner; packages, catalog, contract,
  documented API, scripts.
- **Constraints:** tests under 10 s. No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I, III | PASS: no rendering change |
| II | PASS: envelope reused |
| II-a | N/A: no VisualCore change |
| IV | PASS: record and lines tested without a GPU |
| V | PASS: record schema 1 with typed refusals; content version bound |
| VI | PASS |
| VII | PASS: list-only fixture; review lines in the panel |
| VIII | PASS: bundled |
| IX | PASS |
| X–XIII | PASS |

A17 rules: no clinical claim (only the owner adds a clinical entry); the not-reviewed label and the schematic-model
statement are always shown: PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/InteractiveAnatomy/Core/Content/knee-right.review.json                     new
Packages/ExperiencesCreative/InteractiveAnatomy/Core/{AnatomyReviewRecord,AnatomyReview}.swift          new
Packages/ExperiencesCreative/InteractiveAnatomy/Core/AnatomyPanel.swift (review lines, statement)       modify
Packages/ExperiencesCreative/InteractiveAnatomy/CoreTests/{ReviewRecordTests,ReviewDocumentTests}.swift  new; PanelTests modify
Packages/ExperiencesCreative/InteractiveAnatomy/Experience/AnatomyControls.swift (statement, review lines, About row) modify
Packages/ExperiencesCreative/InteractiveAnatomy/ExperienceTests/AnatomyListOnlyTests.swift              new
docs/apps/interactive-anatomy/{review.md, device-campaign.md}                                           new
docs/apps/interactive-anatomy/visualcore-contract.json (G-REVIEW closed)                                modify
```

**Dependency direction:** unchanged.

**Lifecycle:** the record is decoded once with the pack and cached. A record that fails validation leaves the content
usable: every part shows only the not-reviewed label, and the failure is counted (`AnatomyReview.recordProblem`).

**Migration:** none (record schema 1). **Rollback:** revert the commits; the panel falls back to A17-P04's lines.

## Parallel work

- **Agent C:** the core files, the record and the core tests.
- **Agent E, after C:** the experience changes and the list-only test.
- **Lead:** review.md prose, device-campaign.md, contract, runs, commits.
