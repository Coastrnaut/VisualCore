# Quickstart: validate UA-F05

Run from the repository root on `main`. Every command finishes within ten minutes.

## Evidence commands

Each is recorded with `python3 scripts/migration_ledger.py run-check --gate UA-F05 --name <check-name> --
<command>` (simulator and reference commands with `--timeout 600`).

| Check name | Command | Expected |
|---|---|---|
| `persistence-host` | `swift test --package-path Packages/VisualCore --filter 'VisualCoreExperienceTests|VisualCorePersistenceTests'` | every test passes (storage handle, saved-state store, migration check, inventory) |
| `host-visualcore` | `swift test --package-path Packages/VisualCore` | every test passes |
| `pure-ios27`, `pure-ios26` | `python3 scripts/xcodebuild_package.py --package Packages/VisualCore --scheme VisualCore-Package --destination sim-27.2 --action test` (and `sim-26.5`) | TEST SUCCEEDED |
| `rendering-ios27`, `rendering-ios26` | `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --result-name ua-f05-ios27` (and `sim-26.5`, `ua-f05-ios26`) | TEST SUCCEEDED |
| `app-<kind>-ios<nn>-e` | `python3 scripts/xcodebuild_app.py --scheme VisualCore --runtime 27.2 --kind phone --only-testing VisualCoreUITests/PersistenceUITests` (phone and tablet, 27.2 and 26.5). The runner issues the brief's command `xcodebuild test -project VisualCore.xcodeproj -scheme VisualCore -only-testing:VisualCoreUITests/PersistenceUITests -destination "platform=iOS Simulator,id=<udid>" CODE_SIGNING_ALLOWED=NO` with the simulator chosen by runtime and kind | tests and enumeration guard pass |
| `app-<kind>-ios<nn>-a/-b/-c/-d` | the four existing chunks of the app tests on the same four combinations | tests and enumeration guard pass |
| `storage-rule` | `python3 scripts/check_app_isolation.py --no-direct-storage Apps/VisualCore/App/DebugSupport/DebugExperience.swift Packages/VisualCore/Sources/VisualCoreTestSupport/SampleExperienceCore.swift` | pass |
| `stored-data-rule` | `python3 scripts/check_app_isolation.py --no-crash-on-stored-data Packages/VisualCore/Sources/VisualCoreExperience/SavedStateStore.swift Packages/VisualCore/Sources/VisualCoreExperience/ExperienceStorage.swift Apps/VisualCore/App/PreferencesStore.swift` | pass |
| `release-symbols` | `python3 scripts/check_release_symbols.py --app <release app> --forbid DebugLaunch DebugExperience vcDamageState vcStrayItems vc.inventory` | 0 found |
| `privacy-manifest`, `compliance`, `app-isolation` | `python3 scripts/check_privacy_manifest.py --app <release app>`, `python3 scripts/check_compliance.py`, `python3 scripts/check_app_isolation.py --app Apps/VisualCore --require-sources --built-app <release app>` | pass |
| `public-api`, `documented-api-*`, `dependencies` | `python3 scripts/check_public_api.py` (after `--update`), `python3 scripts/check_documented_api.py --sources …`, `python3 scripts/check_dependencies.py` | pass |
| `build-<Scheme>` | the seven consumer builds | exit 0 |
| `reference-a`, `reference-b` | the two chunks of the ProjectM reference regression | 3 of 3 and 4 of 4 |
| `script-tests`, `docs`, `steering` | `python3 scripts/test_scripts.py`, `python3 scripts/validate_docs.py`, `python3 scripts/validate_autocreator.py` | pass |

## Validation scenarios

1. **Isolation**: `ExperienceStorageTests` — two handles, 20 escaping names, quotas, reserved names, atomic write
   with an interruption at each step.
2. **Saved state**: `SavedStateStoreTests` — round trip, equal text writes nothing, 8 unreadable files, quarantine
   keeps 3, leftovers removed, no write over an unreadable file.
3. **Session**: `SessionRestoreTests` (simulator) — a refused snapshot with `refusedSnapshotFails` fails at the
   restore stage with no host and no sink call; `checkpoint()` hands a snapshot to the sink.
4. **Migration**: `SnapshotMigrationCheckTests` — the sample's version 1 example passes; a missing example and a
   wrong digest fail.
5. **App unit tests**: restore after a close and after a new model on the same storage; a checkpoint 5 seconds
   after an accepted action (with a scripted clock); no write without an action; unreadable states give the
   notice; Reset quarantines and opens afresh; Back changes nothing; resets remove folders and values.
6. **Interface tests** (`PersistenceUITests`): taps survive an end of the app; the three damaged states give the
   message; Reset and Back; the inventory after a scripted use is clean; stray items fail it.
7. **Inventory**: `ContainerInventoryTests` — rules, a stray file, a stray key, a system rule without an origin.

## Device and owner tasks

`{device}`: the container inventory on D1, D2 and D3 after the device campaign. `{owner}`: none.
