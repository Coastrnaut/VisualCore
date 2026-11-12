# Quickstart: validate UA-F04

Run from the repository root on `main`. Every command finishes within ten minutes.

## Evidence commands

Each is recorded with `python3 scripts/migration_ledger.py run-check --gate UA-F04 --name <check-name> --
<command>` (simulator and reference commands with `--timeout 600`).

| Check name | Command | Expected |
|---|---|---|
| `xcodegen` | `xcodegen generate --spec project.yml` | the project is generated |
| `app-build` | `xcodebuild build -project VisualCore.xcodeproj -scheme VisualCore -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO` | BUILD SUCCEEDED |
| `app-phone-ios27-a/-b/-c/-d`, `app-tablet-ios27-a/-b/-c/-d`, `app-phone-ios26-a/-b/-c/-d`, `app-tablet-ios26-a/-b/-c/-d` (each run is four chunks of whole test classes with `--only-testing`, see data-model.md section 7) | `python3 scripts/xcodebuild_app.py --scheme VisualCore --runtime 27.2 --kind phone` (and `tablet`, and runtime `26.5`): the brief's `xcodebuild test -project VisualCore.xcodeproj -scheme VisualCore -destination "platform=iOS Simulator,id=<udid>" -test-timeouts-enabled YES -default-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO`, followed by `python3 scripts/check_test_enumeration.py --sources Apps/VisualCore/Tests --log <log>` | TEST SUCCEEDED and the enumeration guard passes |
| `compliance` | `python3 scripts/check_compliance.py` | pass, with `Apps/VisualCore` scanned |
| `app-isolation` | `python3 scripts/check_app_isolation.py --app Apps/VisualCore --require-sources --built-app <built app>` | pass: no network, no shim import, no usage description |
| `release-symbols`, `release-automation`, `debug-symbols-present` | `python3 scripts/check_release_symbols.py --app <release app> --forbid DebugLaunch DebugExperience openExperience vcFixtureCatalog projectm ProjectM`; the same tool without `--forbid`; and with `--expect-present` on the debug app | 0 found in the release build; all four debug names found in the debug build |
| `host-visualcore` | `swift test --package-path Packages/VisualCore` | pass |
| `rendering-ios27`, `rendering-ios26` | the rendering package tests on both simulator runtimes (the app links its products) | TEST SUCCEEDED |
| `release-tool` | `python3 scripts/release_check.py --list` | the unsigned simulator build of the scheme VisualCore is a step |
| `pure-ios27`, `pure-ios26` | the pure package tests on both simulator runtimes | TEST SUCCEEDED |
| `public-api`, `dependencies`, `documented-api-*` | as in every framework gate | pass |
| `reference-a`, `reference-b` | the two chunks of the ProjectM reference regression | 3 of 3 and 4 of 4 |
| `script-tests`, `docs`, `steering` | `python3 scripts/test_scripts.py`, `python3 scripts/validate_docs.py`, `python3 scripts/validate_autocreator.py` | pass |

## Validation scenarios

1. One shippable target with two test targets; unsigned simulator build.
2. Launcher: six tiles under three headings with the fixture catalog; empty statement with the real catalog.
3. Routes on phone and tablet at default and largest text size, with the accessibility audit.
4. First run: at most two taps to a running free experience, no prompt.
5. Settings survive a restart; resets remove exactly what they name.
6. Offline and isolation checks; no usage description; no debug support in the release build.

Details: [contracts/shell-api.md](contracts/shell-api.md), [data-model.md](data-model.md).
