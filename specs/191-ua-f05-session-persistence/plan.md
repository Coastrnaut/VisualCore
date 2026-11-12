# Implementation Plan: UA-F05 — Session state, per-experience persistence, reset and restore

**Branch**: `191-ua-f05-session-persistence` (spec directory only; work stays on `main`) | **Date**: 2026-11-12 |
**Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/191-ua-f05-session-persistence/spec.md`; the UA-F05 `/speckit-plan`
prompt of Auto-Creator.md section 20, verbatim in the invocation. The clarification decisions are binding.

## Summary

Each experience gets a storage handle that is confined to its own folder and its own defaults prefix. The app
stores the snapshot the session already hands out — at a suspension, at a close and five seconds after an
accepted action — as one atomically written file per experience, and gives it back at the next open. A stored
state that cannot be read never starts an experience: the app shows a message with Reset and Back, and Reset
moves the file to a quarantined copy before a fresh start. Resets also clear the defaults prefix. A migration
check binds every experience with a schema above 1 to an example of every earlier version, and an inventory of
the container, read in debug builds by an interface test, proves that only listed files and keys exist.

## Technical Context

**Language/Version**: Swift 6 (toolchain 6.4.2, strict concurrency); Python 3 standard library for one tool.

**Primary Dependencies**: Foundation; the existing modules VisualCorePersistence, VisualCoreExperience,
VisualCoreExperienceHost; SwiftUI in the app. No third-party package.

**Storage**: per experience the folder `Application Support/Experiences/<id>/` with `state.json` (the snapshot's
text, format 1), `quarantine-<n>.json` and the experience's own files; defaults keys `exp.<id>.<name>`; the
app's `vc.shell.preferences` (schema 1) and `vc.shell.preferences.unreadable`.

**Testing**: Swift Testing on the host for the pure types; package tests on the iOS 27.2 and iOS 26.5 simulators
for the session; XCTest unit tests and XCUITest interface tests in the app's bundles; `unittest` for the tool.

**Target Platform**: iOS and iPadOS 26.0.

**Project Type**: additions to one pure module, two small additions to the host module, changes to the app, one
tool option.

**Performance Goals**: none claimed. A save of the largest state (1 MiB) happens on the main thread; its time is
bounded by the size limit, not measured as a device claim.

**Constraints**: no sync, no network; no deliberate crash on stored data; test access absent from release
builds; experience sources use no container path and no shared defaults; every command under ten minutes.

**Scale/Scope**: 5 new pure source files and 5 test files; 2 host files changed and 1 new test file; about 8
app files changed, 1 new view, 1 new interface test file; 1 tool option; about 60 new public declarations.

## Constitution Check

*GATE: passed before Phase 0 research and re-checked after Phase 1 design (same result).*

| Principle | Result |
|---|---|
| I. Proven Renderer Only | pass: no rendering code changes; an unreadable state stops an open before a render host exists |
| II. App-Neutral Public API | pass: handle, store, check and inventory are generic; documentation, baseline, tests and reference regression are tasks |
| II-a. Preserve the Reference | pass: submodule untouched; the seven-step regression in two chunks is a task |
| III. GPU Lifecycle and Thread Ownership | pass: saving happens on the main actor through the session's existing sink; nothing touches GL |
| IV. Host-Testable Domain Logic, Test-First | pass: every rule is pure and host-tested before the code |
| V. Implementation Before Devices | pass: simulators only; one `{device}` task for after the lock |
| VI. Evidence Over Assertion | pass: evidence through `run-check`; the inventory lists what is really in the container and never skips an unknown item |
| VII. Native, Accessible UI | pass: the message is a native view with two buttons of at least 44 points, string resources, part of the audited routes |
| VIII. Public Apple APIs, Privacy | pass: Foundation file and defaults interfaces already declared in the privacy manifest; nothing leaves the device |
| IX. Bounded Untrusted Input | pass: stored files are read up to a limit and validated; names, sizes, counts and quarantined copies are bounded |
| X. Licensing and Provenance | pass: no new dependency |
| XI. One App and Stable Experience Identity | pass: namespaces derive from the canonical experience ids |
| XII. One Purchase and No Advertising | pass: no store code; the allow-list has no entry for an unlock flag or a tracking value |
| XIII. Code-Driven Visuals | pass: no art |
| Development Workflow | pass: `main`, FR-U05 namespace, one commit per task, Spec Kit skills in order |

No violation; Complexity Tracking stays empty.

## Project Structure

### Source Code (repository root)

```text
Packages/VisualCore/
├── Sources/VisualCoreExperience/
│   ├── ExperienceStorage.swift                    new     StorageQuota, StorageError, ExperienceStorage
│   ├── SavedStateStore.swift                      new     SavedStateProblem, SavedStateLoad, SavedStateStore
│   ├── SnapshotMigrationCheck.swift               new     MigrationExample, SnapshotMigrationCheck
│   ├── ContainerInventory.swift                   new     InventoryRule, InventoryError, ContainerInventory
│   └── ShellModel.swift                           modify  ShellPreferences: unreadableCopyKey, migratedVersions
└── Tests/VisualCoreExperienceTests/
    ├── ExperienceStorageTests.swift, SavedStateStoreTests.swift, SnapshotMigrationCheckTests.swift,
    │   ContainerInventoryTests.swift                                                           new
    └── ShellModelTests.swift                      modify

Packages/VisualCoreRendering/
├── Sources/VisualCoreExperienceHost/
│   ├── ExperienceOpenRequest.swift                modify  refusedSnapshotFails
│   └── ExperienceSession.swift                    modify  failure at the restore stage; checkpoint()
└── Tests/VisualCoreExperienceHostTests/SessionRestoreTests.swift      new

Apps/VisualCore/
├── App/AppModel.swift                             modify  sink, load at open, checkpoints, unreadable notice, resets
├── App/ExperienceRegistry.swift                   modify  ExperienceLaunch.storage; migrationProblems
├── App/PreferencesStore.swift                     modify  copy of an unreadable value
├── App/UnreadableStateView.swift                  new
├── App/ExperienceRouteView.swift, RootView.swift, AppStrings.swift, SettingsView.swift      modify
├── App/DebugSupport/DebugLaunch.swift             modify  -vcDamageState, -vcStrayItems, -vcSeedData through the handle
├── App/DebugSupport/DebugInventory.swift          new     the allow-list and the container reader (debug only)
├── App/DebugSupport/DebugExperience.swift         modify  uses its storage handle for one value
├── Resources/Localizable.xcstrings                modify
├── Tests/Unit/AppModelTests.swift, StoreTests.swift                    modify
└── Tests/UI/PersistenceUITests.swift              new

scripts/check_app_isolation.py                     modify  --no-direct-storage, --no-crash-on-stored-data
scripts/test_scripts.py                            modify
docs/api/visualcore-public-api.txt                 modify  baseline
Auto-Creator.md (sections 11.4, 11.7, 15.1, 16)    modify  as built
```

## Module and dependency direction

Unchanged: `VisualCoreExperience` depends on `VisualCoreMath`, `VisualCoreSimulation`, `VisualCorePersistence`,
`VisualCoreDiagnostics`; the host module on it; the app on both. No new edge. The new pure types use Foundation
(`FileManager`, `UserDefaults`) as `VisualCorePersistence` does; nothing in them is UIKit or GL.

## Public API

See [contracts/persistence-api.md](contracts/persistence-api.md). Additions only; `ExperienceOpenRequest` gains
one stored property with a default, so existing call sites compile unchanged.

## Lifecycle and thread-ownership contracts

- The stores are values without mutable state; the app uses them on the main actor. `ExperienceStorage` may be
  used by an experience from its own code; each operation is one atomic file or defaults operation.
- Open: `load` → no state: open fresh; state: open with it and `refusedSnapshotFails`; unreadable: no open, the
  notice. A failure at the restore stage becomes the same notice; the session is taken back to idle first.
- Save: the session's sink (suspension, close, `checkpoint()`) calls `save`; equal text writes nothing; a
  failure is recorded and never stops the session. The app schedules a checkpoint 5 seconds after the action
  port's revision changed, once per change burst, and cancels it when the experience closes.
- Reset: close (which saves), remove the folder, remove the values, clear the notice; for all data also the
  preferences and their unreadable copy.
- Start: leftover temporary files are removed once, before the first open.

## Data schemas

The saved state is `ExperienceSnapshot` format 1 (existing); its schema version is the experience's. No new
schema. `ShellPreferences` stays schema 1 and gains the place where a later version registers its migrations.

## Tests of each layer

| Layer | Tests |
|---|---|
| Host (`swift test`) | `ExperienceStorageTests`, `SavedStateStoreTests`, `SnapshotMigrationCheckTests`, `ContainerInventoryTests`, `ShellModelTests` additions |
| Package tests, iOS 27.2 and 26.5 simulators | the same pure tests; `SessionRestoreTests` |
| App unit tests | restore, checkpoints, unreadable notice, Reset and Back, resets, the registry's migration check, leftovers |
| App interface tests | `PersistenceUITests`: restore after an end of the app, damaged states, Reset and Back, inventory, stray items |
| Tool | `--no-direct-storage`, `--no-crash-on-stored-data` |

## Build and test commands

See [quickstart.md](quickstart.md). When the framework changes: `python3 scripts/check_public_api.py --update`,
`python3 scripts/check_documented_api.py`, and the seven-step ProjectM reference regression in two chunks.

## Migration and rollback

Additive. Before this feature no saved state exists on any installation, so there is nothing to migrate.
Rollback is `git revert` of the feature's commits in reverse order; stored `state.json` files are then ignored
(the reset of UA-F04 still removes the folders).

## Complexity Tracking

No violation to justify.
