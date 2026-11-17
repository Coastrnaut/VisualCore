# Implementation Plan: Digital Zen Garden — Phase 04 Persistence, accessibility and still export

**Branch**: `148-zg-p04-library-a11y` (spec directory only; work on `main`) | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

## Summary

This phase closes G-LIBRARY and G-A11Y and adds a still picture:
- **Library:** `GardenLibrary` over the experience's storage, with at most 12 named gardens and refusals for damaged,
  newer and oversized files; opening restores the document through the shell and restarts the history.
- **Accessibility:** spoken labels and values for every control, the garden described in words, announcements, and
  controls that stack at the accessibility text sizes.
- **Bounded history:** a fixture of 10,000 commands proves the history and document stay within their bounds.
- **Still:** a 1600 × 1200 PNG from the session's still renderer handed to the share sheet; the registration declares
  `photo-library-add`.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/library.md](contracts/library.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, SwiftUI.
- **Dependencies:** unchanged; `ExperienceStorage`, `experienceStillRenderer`, `StillImageEncoder`, `TemporaryFolder`
  (VisualCorePersistence) and `ShareLink`.
- **Testing:** the A20 package tests; the app build and unit tests; `app-usage-descriptions`; the runner on iOS 27.
- **Performance:** each test under 10 s; the bounded-history fixture applies 10,000 commands with strokes of at most
  64 points (arithmetic bound on memory, no device claim).
- **Constraints:** iOS 27 only; no VisualCore change. No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II | PASS: reuses `ExperienceStorage`, the still renderer, the PNG encoder, `TemporaryFolder` and the app's usage string |
| IV | PASS: the library's file format and caps are tested without the GPU |
| VIII | PASS: no network; the add-only Photos string is used only by the share sheet; no PhotoKit |
| IX | PASS: labels, values, description, announcements, stacking at large text |

A20 rules (constitution 2.16.0): PASS: bounded (caps and the history bound), offline and private.

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/DigitalZenGarden/Experience/GardenLibrary.swift                 new     files, index, caps, refusals
Packages/ExperiencesCreative/DigitalZenGarden/Experience/GardenStill.swift                   new     still export, one temporary file
Packages/ExperiencesCreative/DigitalZenGarden/Experience/{GardenControls,GardenPresenter,DigitalZenGardenExperience}.swift   modify  library and share controls, announcements, description, storage
Packages/ExperiencesCreative/DigitalZenGarden/ExperienceTests/{LibraryTests,AccessibilityTests,BoundedHistoryTests,StillTests}.swift   new
Catalog/registrations.json                                                                      modify  permissions ["photo-library-add"]
docs/apps/digital-zen-garden/visualcore-contract.json                                          modify  G-LIBRARY, G-A11Y closed
```

- **Lifecycle:** the library reads its index when the experience opens and writes atomically; the still's file is
  replaced by the next export and removed after a failure.
- **Migration:** library schema 1, the first version. **Rollback:** revert the commits; saved gardens of this version
  stay readable by it.

## Parallel work

- **Agent E:** the library, the still, the controls and their tests (one writer).
- **Lead:** the registration's permission, the contract, the runs and the commits.
