# Implementation Plan: Generative Art Studio — Phase 03 Save and restore compositions

**Branch**: `014-gas-p03-save-restore` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md) | **Gate**: A01-P03

## Summary

The generic `DocumentStore` is built in VisualCorePersistence (gap G-PERSIST). It provides:
- a versioned envelope;
- atomic writes;
- listing that reports problems per file;
- a migration chain;
- kind and size checks.

The app adds four pieces:
- `CompositionLibrary` (Core): entries with name, favorite and times; ordering; duplicate, rename and delete; the
  envelope kind and version;
- `LibraryView`;
- save from the scene screen;
- a leak test for rapid edits.

## Technical Context

**Language/Version**: Swift 6.4.2 · **Primary Dependencies**: Foundation only for VisualCorePersistence (rule R2) ·
**Storage**: app container `Application Support/Compositions/<uuid>.json`, default data protection ·
**Testing**:
- host `swift test` for the store and the library: temporary directories, interrupted writes, migrations, bad files;
- hosted app tests: save → reload in a new store → identical image; the rapid-edit leak test;
- UI tests: save, library, favorite, duplicate, rename and delete on both runtimes;
- the ProjectM regression; API and contract checks.

**Target Platform**: iOS/iPadOS 26.0+ · **Performance Goals**: none claimed (libraries are small; files ≤ 256 KiB) ·
**Constraints**: offline, no permissions, no automatic deletion of user files · **Scale/Scope**: 1 VisualCore type
family, 1 Core type, 1 view, 2 scene-screen changes.

## Constitution Check

| Principle | Status |
|---|---|
| I Renderer | PASS: no GL changes |
| II Maximize reuse | PASS: the store is in VisualCorePersistence |
| II-a Reference | PASS: regression after the VisualCore change |
| III Lifecycle | PASS: rapid edits reuse one host, with leak counts checked |
| IV Host-testable | PASS: the store and library are pure Foundation |
| V Simulator only | PASS |
| VI Evidence | PASS |
| VII Accessible UI | PASS: labelled actions, confirmation dialog, Dynamic Type |
| VIII Privacy | PASS: own container only, default protection, nothing leaves the device |
| IX Bounded input | PASS: size limit, kind and version checks, files never trusted |
| X Licensing | PASS: no assets |
| A01 rules | PASS |

## Project Structure

```text
Packages/VisualCore/Sources/VisualCorePersistence/{Envelope,DocumentStore,Migration}.swift   (+ VisualCorePersistenceTests)
Packages/VisualCore/Package.swift                                       # VisualCorePersistenceTests target
Apps/GenerativeArtStudio/Core/Package.swift                              # + VisualCorePersistence product
Apps/GenerativeArtStudio/Core/Sources/GenerativeArtStudioCore/CompositionLibrary.swift (+ CompositionLibraryTests)
Apps/GenerativeArtStudio/App/{LibraryView,SaveFlow}.swift; SceneScreen.swift (Save; entry identity); GalleryView.swift (Library button)
Apps/GenerativeArtStudio/Tests/Unit/LibraryRenderTests.swift (reload equivalence + rapid-edit leak)
Apps/GenerativeArtStudio/Tests/UI/LibraryUITests.swift
project.yml                                                              # + VisualCorePersistence product on the app
docs/apps/generative-art-studio/visualcore-contract.json                # G-PERSIST closed; M08 available
```

**Dependency direction**:
- App → Core → VisualCorePersistence, VisualCoreParameters and VisualCoreSimulation.
- VisualCorePersistence → Foundation.

**Lifecycle**:
- `LibraryModel` (app, `@MainActor @Observable`) owns one `CompositionLibrary` over the store directory and loads it
  on appear.
- Saving writes through the library, which writes the store atomically.
- The scene screen keeps the entry identity of an opened composition so that saves update in place.

**Data migration**: none needed for existing users (first persisted format). The store's migration chain is in place
for later versions.

**Rollback**: revert the phase commits. Saved files stay readable by any build with the same format, and older builds
ignore the folder.

## Complexity Tracking

None.
