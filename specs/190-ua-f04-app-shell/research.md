# Research: UA-F04 — The VisualCore app shell

Date: 2026-11-12. Read-only audit of the sources the brief names, then the plan's decisions.

## 1. Audit

| Surface | Where | What was verified |
|---|---|---|
| Project definition | `project.yml` | XcodeGen project `VisualCore` with the packages `VisualCore`, `VisualCoreRendering` and four app cores; application targets Showcase and four standalone apps, each with unit and UI test bundles, an `info` block that generates the Info.plist, the post-build scripts "Bundle licenses" (`scripts/bundle_licenses.py`) and "Dependency audit" (`scripts/audit_showcase_dependencies.py`), and one scheme per app. No target named VisualCore exists. |
| VisualCoreUI | `Packages/VisualCoreRendering/Sources/VisualCoreUI/` | `AccessibilitySettingsSection(preferences:system:)`, `SystemAccessibilityObserver`, `AcknowledgementsView(inventory:identifierPrefix:)`, `LicenseInventory(bundle:)`, `RenderSurface`. `AccessibilityPreferences` and `SystemAccessibility` are pure types in `VisualCoreSimulation`. |
| Catalog | `Packages/VisualCore/Sources/VisualCoreExperience/` and `Catalog/` | `CatalogManifest(data:categories:)` with typed errors, `search(_:)`, `registryReport(registered:)`, `CategoryList`; files `Catalog/experiences.json` (100 entries, 0 available) and `Catalog/categories.json`. |
| Session | `…/VisualCoreExperienceHost/` (UA-F03) | `ExperienceSession`, `ExperienceOpenRequest`, `ExperienceHostView(session:)`; a tier is set through `Experience.setQualityTier(_:)`. |
| Public scenes | `…/VisualCoreRendering/SampleScenes.swift` | `ClearColorScene` (public, settable colour) lets app code draw without any direct GL call. |
| Compliance | `scripts/check_compliance.py`, `scripts/check_app_isolation.py` | The compliance scan reads sources, project files and plists under `Packages/`, `Apps/` and more; the isolation tool takes `--app <folder> [--built-app] [--require-sources]` (UA-F03). |
| Test tools | `scripts/check_test_enumeration.py`, `scripts/release_check.py`, `scripts/xcodebuild_package.py` | The enumeration guard compares declared and passed XCTest methods of a log. Simulator identifiers are resolved by runtime for the first iPhone only; no tool resolves a tablet. |
| Test support rule | `scripts/check_dependencies.py` R5 | `VisualCoreTestSupport` may be a dependency of test targets only, so the app cannot link the framework's sample experience. |

## 2. Names of the brief, confirmed or corrected

| Name | Result |
|---|---|
| `Apps/VisualCore/` | new: `App/`, `App/DebugSupport/`, `Resources/`, `Tests/Unit/`, `Tests/UI/`, `Generated/` |
| target VisualCore, module name | target and product VisualCore; `PRODUCT_MODULE_NAME` is `VisualCoreApp`, so the module differs from the package `VisualCore` |
| `vc.tile.<id>` | confirmed; routes use `vc.route.<name>` as section 11.7 states |
| `xcodebuild test … id=<27.x udid>` | the identifier is resolved at run time by a new tool, `scripts/xcodebuild_app.py`, by runtime and kind (phone or tablet); no identifier is written down |
| `scripts/check_test_enumeration.py --sources Apps/VisualCore/Tests --log <log>` | confirmed; the new tool writes the log and can run the guard right after the tests |

## 3. Decisions

### R1. Pure shell model in VisualCoreExperience
`ShellRoute`, `ShellPreferences` (schema 1, tolerant decoding with a note), `LauncherModel` (sections, tiles, states),
`ShellStartup` (welcome and restored route) and `ResetPlan` are values in the pure module, tested on the host.
The app's views only render them. *Alternative rejected:* a new module (one more product for a handful of types).

### R2. Explicit registry in the app
`ExperienceRegistry.all` is a literal list of `(ExperienceID, factory)`. It is empty in this feature: no experience
is integrated. A unit test runs `registryReport` against the bundled catalog and fails on any mismatch.

### R3. Debug support folder
`Apps/VisualCore/App/DebugSupport/` is wholly inside `#if DEBUG`: launch arguments (`-openExperience <id>`,
`-vcFixtureCatalog`, `-vcResetData`, `-vcSkipWelcome`), a fixture catalog built in code (six available experiences
in three categories, one of them premium) and one small debug experience (a pure core and a presenter that draws
through the public `ClearColorScene`). `scripts/check_release_symbols.py` style proof: the release app is searched
for the debug type names.

### R4. Storage
Preferences: one JSON value under the key `vc.shell.preferences` in the app's `UserDefaults`. Experience data:
`Application Support/Experiences/<storage namespace>/`. `ResetPlan` names what to remove; the app's
`ExperienceDataStore` removes folders and reports what it removed. The privacy manifest declares the required
reason for `UserDefaults`.

### R5. Layout
`NavigationSplitView` with the catalog as sidebar; it collapses to a stack in compact width. Settings and about are
destinations of the same navigation. The experience route hosts `ExperienceHostView`.

### R6. Quality override and accessibility choices
The app passes the stored tier to the experience after a successful open when the override is not automatic, and
keeps `AccessibilityPreferences` in the preferences value; experiences receive both through the open path. What a
tier means is UA-F06.

### R7. Running app tests on simulators
New tool `scripts/xcodebuild_app.py --scheme VisualCore --runtime 27.2 --kind phone|tablet [--only-testing …]`:
resolves the simulator by runtime and kind, runs the brief's `xcodebuild test` command with the timeouts, writes
the log under `.autonomy/logs/`, and runs the enumeration guard on it. Physical devices cannot be named.

### R8. No app icon in this feature
The icon is generated by a script in the release preparation (UA-F14, section 6.3 item 3). The target builds
without one; the plan states it so that nobody adds a raster by hand.

### R9. Limits
Search text 100 characters; preferences value 64 KiB; welcome shown once; at most 2 taps to a running experience.

## 4. Not verified here
- Layout and VoiceOver on devices: a `{device}` task. Name availability and bundle identifier: an `{owner}` task.
