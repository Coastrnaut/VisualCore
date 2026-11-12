---

description: "Task list for feature 190 — UA-F04 the VisualCore app shell (migration ledger gate UA-F04)"
---

# Tasks: UA-F04 — The VisualCore app shell

**Input**: `specs/190-ua-f04-app-shell/` (spec, plan, research, data-model, contracts/shell-api.md, quickstart).

**Tests** are required by the specification (acceptance items 1 to 7): Swift Testing for the shell model on the
host, XCTest unit tests and XCUITest interface tests in the app's test bundles on a phone and a tablet simulator
of both runtimes, and `unittest` in `scripts/test_scripts.py`. A test file is written before the code it proves;
where an agent writes test and code of one unit together, the tick says so.

**Conventions**: ids `T-U04-###`; one commit and push per task through `scripts/tick_task.py`; a test task and the
implementation it proves are committed together so that `main` is never red; the API baseline is updated in every
commit that adds a public framework symbol; gate evidence through
`python3 scripts/migration_ledger.py run-check --gate UA-F04 --name <check-name> -- <command>` (simulator and
reference commands with `--timeout 600`). "The commit before the feature" is `7b5b87d`. Signatures are those of
contracts/shell-api.md; identifiers those of data-model.md section 6. `[P]` marks a task whose files no other open
task writes; such tasks may go to parallel agents, which write files only; the lead builds, tests, ticks and
commits. Review checkpoint after each phase.

**Device-only**: T-U04-031. **Owner-only**: T-U04-032.

## Phase 1: Setup

- [X] T-U04-001 Add to `project.yml` the application target `VisualCore` (sources `Apps/VisualCore/App` and `Apps/VisualCore/Resources`; resources `Catalog/experiences.json` and `Catalog/categories.json` bundled from the repository's `Catalog` folder; generated Info.plist at `Apps/VisualCore/Generated/Info.plist` with display name VisualCore, no usage description, no URL type, no document type; `PRODUCT_BUNDLE_IDENTIFIER` `dev.visualcore.VisualCore`, `PRODUCT_NAME` `VisualCore`, `PRODUCT_MODULE_NAME` `VisualCoreApp`; dependencies on the products VisualCoreExperience, VisualCoreSimulation, VisualCoreExperienceHost, VisualCoreUI and VisualCoreRendering; the post-build scripts "Bundle licenses" and "Dependency audit" as the other apps have them), the targets `VisualCoreTests` (`Apps/VisualCore/Tests/Unit`) and `VisualCoreUITests` (`Apps/VisualCore/Tests/UI`), and the scheme `VisualCore`; create `Apps/VisualCore/App/VisualCoreApp.swift` with a minimal app type, `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy` (no tracking, no collected data, the required reason for the preferences storage) and one placeholder-free test in each test folder (the bundle identifier and display name; the app launches). Proof: `xcodegen generate --spec project.yml` and `xcodebuild build -project VisualCore.xcodeproj -scheme VisualCore -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO` succeed (FR-U04-001, FR-U04-002, FR-U04-003, FR-U04-005, FR-U04-006, FR-U04-034, FR-U04-071). — Verified 2026-11-12: xcodegen generate --spec project.yml: project created; xcodebuild build -project VisualCore.xcodeproj -scheme VisualCore -destination generic/platform=iOS Simulator CODE_SIGNING_ALLOWED=NO: BUILD SUCCEEDED (including the licence and dependency-audit scripts); check_compliance.py, check_dependencies.py, validate_autocreator.py and test_scripts.py (184 tests) pass; check_app_isolation.py --app Apps/VisualCore --require-sources: PASS
- [X] T-U04-002 [P] Add `AppTestRunnerTests` to `scripts/test_scripts.py` and create `scripts/xcodebuild_app.py` as contracts/shell-api.md states (simulator chosen by runtime and kind from the list of available simulators; the brief's `xcodebuild test` arguments; the log under `.autonomy/logs/app-tests/`; the enumeration guard afterwards; no device destination; exit codes). Tests cover the choice of a phone and of a tablet from a fixture list, the refusal when none exists, the exact command, and the exit codes with an injected runner (FR-U04-080). Proof: `python3 scripts/test_scripts.py` passes. — Verified 2026-11-12: scripts/xcodebuild_app.py and AppTestRunnerTests written by a parallel agent; python3 scripts/test_scripts.py run by the lead: Ran 201 tests, OK; the tool then ran the app's tests on an iPhone simulator of iOS 27.2 chosen by runtime and kind: PASS with the enumeration guard

## Phase 2: Foundational (pure shell model)

- [X] T-U04-003 [P] Write `Packages/VisualCore/Tests/VisualCoreExperienceTests/ShellModelTests.swift`: `ShellRoute` text round trip for the four routes and nil for malformed text; `ShellPreferences` defaults, encode and decode round trip, defaults with the note `preferences.unreadable` for damaged data and for data above 64 KiB and `preferences.newer` for schema 2, a search text cut to 100 characters, a quality override outside 0…7 dropped; `LauncherModel.state` gives `error` with the catalog error's code, `empty` for the real catalog fixture (0 available), `sections` in category-list order with tiles in catalog order for a manifest with six available and registered experiences in three categories, only experiences that are both available and registered, `noMatch` for a search without result and the search order for a search with results (a table of 10 search texts against `CatalogManifest.search`); tiles carry `vc.tile.<id>` and the tier text `Free` or `Premium`; `ShellStartup.decide` for the five rows of data-model.md section 3; `ResetPlan` namespaces and the preferences flag (FR-U04-011, FR-U04-020 to FR-U04-024, FR-U04-033, FR-U04-041, FR-U04-042, FR-U04-052, FR-U04-060, FR-U04-061; SC-U04-003). — Verified 2026-11-12: ShellModelTests.swift written by a parallel agent with the model; swift test --package-path Packages/VisualCore --filter ShellModelTests run by the lead: 25 tests passed
- [X] T-U04-004 [P] Create `Packages/VisualCore/Sources/VisualCoreExperience/ShellModel.swift` with `ShellRoute`, `AccessibilityChoice`, `ShellPreferences`, `LauncherTile`, `LauncherSection`, `LauncherState`, `LauncherModel`, `ShellStartup` and `ResetPlan`. Proof: `swift test --package-path Packages/VisualCore --filter ShellModelTests` passes. — Verified 2026-11-12: swift test --package-path Packages/VisualCore --filter ShellModelTests: 25 tests passed; tile colours are two #RRGGBB texts taken from the palette or derived from the seed, and a catalog error's code is catalog.<case>

## Phase 3: User Stories 1 to 5 - the app (Priority: P1 and P2) 🎯 MVP

**Goal**: the app shell. **Independent Test**: unit and interface tests of the scheme on a phone and a tablet.

- [X] T-U04-005 [P] [US2] Create `Apps/VisualCore/App/DebugSupport/DebugLaunch.swift` and `DebugExperience.swift`, both wholly inside `#if DEBUG`: the launch arguments `-openExperience <id>`, `-vcFixtureCatalog`, `-vcResetData`, `-vcSkipWelcome`, `-vcEmptyRegistry`; a fixture catalog built in code with six available experiences in three categories (five free, one premium) plus two that are not available; and a debug experience (a pure core with one control and a presenter that draws through the public `ClearColorScene`) registered for the five free fixture ids (FR-U04-043, FR-U04-081). — Verified 2026-11-12: DebugLaunch.swift and DebugExperience.swift (parallel agent), both wholly inside #if DEBUG; xcodebuild build-for-testing of the scheme VisualCore: TEST BUILD SUCCEEDED; the fixture is the bundled catalog with six entries switched to available; proven by the interface tests of the iPhone run on iOS 27.2 (57 tests passed)
- [X] T-U04-006 [P] [US1] Write `Apps/VisualCore/Tests/Unit/AppModelTests.swift` and `StoreTests.swift`: the bundled catalog loads and has 100 experiences; the registry and the bundled catalog agree (`registryReport` without problems; today: no experience registered and none available); the app model's launcher state for the real catalog is `empty` and for the fixture catalog six tiles in three sections; opening a premium fixture tile gives the premium notice and no session; opening a free fixture experience with a quality override of 7 applies the experience's last declared tier, with an override of 1 applies tier 1, and with automatic applies none (FR-U04-051); the preferences store keeps a value across two instances on a private suite and replaces damaged data by defaults with a note; the data store creates, lists and removes a folder per storage namespace in a temporary directory, removes only the named one for `.experience`, and all of them and the preferences for `.all`; the built bundle declares no usage description, no URL type and no document type, and has the bundle identifier `dev.visualcore.VisualCore` (FR-U04-001, FR-U04-003, FR-U04-010 to FR-U04-012, FR-U04-034, FR-U04-052, FR-U04-060, FR-U04-071; SC-U04-006). — Verified 2026-11-12: AppModelTests.swift (13 tests) and StoreTests.swift (9 tests) by a parallel agent; python3 scripts/xcodebuild_app.py --scheme VisualCore --runtime 27.2 --kind phone run by the lead: PASS, all unit tests passed
- [X] T-U04-007 [P] [US2] Write `Apps/VisualCore/Tests/UI/LauncherUITests.swift`: with `-vcFixtureCatalog` six tiles under three headings, each with `vc.tile.<id>` and a visible tier text; a search narrows the tiles and an unmatched search shows `vc.nomatch`; without the fixture the launcher shows `vc.empty` and no tile; the premium tile opens `vc.premium.notice`; the accessibility audit of the catalog route passes at the default and at the largest accessibility text size (FR-U04-020 to FR-U04-023, FR-U04-012; SC-U04-002). — Verified 2026-11-12: LauncherUITests.swift (6 tests, parallel agent): passed in the iPhone run on iOS 27.2, including the accessibility audit at the default and the largest text size after the lead fixed two findings in the app (header and reset-row text colour; the search field wraps instead of clipping)
- [ ] T-U04-008 [P] [US3] Write `Apps/VisualCore/Tests/UI/RoutesUITests.swift`: the routes catalog, experience, settings and about each show their `vc.route.<name>` root, at the default and at the largest accessibility text size, with the accessibility audit; activating a tile opens the experience route with the canvas (`session.canvas`) and `vc.experience.back` returns to the catalog; after terminating and relaunching, the app returns to the last route, the last experience and the last search text, and to the catalog when the last experience is not available (relaunch without the fixture); on a tablet in landscape the catalog and the content are visible together (FR-U04-030 to FR-U04-035; SC-U04-004, SC-U04-009).
- [ ] T-U04-009 [P] [US4] Write `Apps/VisualCore/Tests/UI/FirstRunUITests.swift`: with `-vcResetData -vcFixtureCatalog` the welcome (`vc.welcome`) appears with no alert, sheet or sign-in; `vc.welcome.start` opens the first free fixture experience, which shows `session.canvas` after at most two taps from launch; a second launch shows no welcome; `-openExperience <id>` opens that experience directly and an unknown id shows the catalog (FR-U04-040 to FR-U04-043; SC-U04-005).
- [ ] T-U04-010 [P] [US5] Write `Apps/VisualCore/Tests/UI/SettingsUITests.swift`: the two accessibility choices and the quality override (`vc.settings.quality`) survive a relaunch; `vc.settings.reset.all` asks for confirmation and afterwards the welcome appears again; the privacy statement (`vc.settings.privacy`) contains the words for no data collection, no network and no advertising; the about route shows name, version and `vc.about.acknowledgements`; the accessibility audit of settings and about passes at both text sizes (FR-U04-050 to FR-U04-054; SC-U04-006).
- [ ] T-U04-011 [US1] Create the app sources in `Apps/VisualCore/App/`: `AppModel.swift`, `ExperienceRegistry.swift` (the explicit list, empty), `PreferencesStore.swift`, `ExperienceDataStore.swift`, `RootView.swift`, `LauncherView.swift`, `TileView.swift`, `ExperienceRouteView.swift`, `WelcomeView.swift`, `SettingsView.swift`, `AboutView.swift`, `AppStrings.swift`, the final `VisualCoreApp.swift`, and `Apps/VisualCore/Resources/Localizable.xcstrings`, rendering the shell model and using the session, `ExperienceHostView`, `AccessibilitySettingsSection` and `AcknowledgementsView` (FR-U04-010 to FR-U04-061). Proof: `python3 scripts/xcodebuild_app.py --scheme VisualCore --runtime 27.2 --kind phone` reports TEST SUCCEEDED and the enumeration guard passes.
- [ ] T-U04-012 [US3] Acceptance of US1 to US5: record `run-check --gate UA-F04 --name us-phone-ios27 --timeout 600 -- python3 scripts/xcodebuild_app.py --scheme VisualCore --runtime 27.2 --kind phone`, `us-tablet-ios27` (`--kind tablet`), `us-phone-ios26` and `us-tablet-ios26` (`--runtime 26.5`); in all four the unit tests and the four interface test classes passed and the enumeration guard passed.

## Phase 4: User Story 6 - the app never talks to a network (Priority: P2)

- [ ] T-U04-013 [US6] Compliance and isolation: `python3 scripts/check_compliance.py` passes and its output shows that `Apps/VisualCore` was scanned; `python3 scripts/check_app_isolation.py --app Apps/VisualCore --require-sources --built-app <the built simulator app>` passes; a scratch copy of the app folder with one networking call makes the isolation check fail with file and line; record `run-check --name compliance` and `--name app-isolation` (FR-U04-070, FR-U04-071; SC-U04-007).
- [ ] T-U04-014 [US6] Release contents: build the app for the generic simulator in the Release configuration into `Build/DerivedData/ua-f04-release` and search its binary's symbols and strings for the debug support names (`DebugLaunch`, `DebugExperience`, `-openExperience`, `vcFixtureCatalog`) and for reference-engine names: 0 found; the debug build contains them (the search can see them). The search is a new option of `scripts/check_release_symbols.py`, `--forbid <text> …` (symbols and strings of every binary of the app; exit 1 on a hit, inverted by `--expect-present`), with tests in `scripts/test_scripts.py`; record `run-check --name release-symbols -- python3 scripts/check_release_symbols.py --app <release app> --forbid DebugLaunch DebugExperience openExperience vcFixtureCatalog` (FR-U04-004; SC-U04-008).

## Phase 5: Framework obligations and documents

- [ ] T-U04-015 Documentation: README (the app target and how to run its tests), `docs/getting-started.md`, Auto-Creator.md sections 11.1, 11.7 and 16 brought in line with what was built, notes and states in `docs/migration/path-map.json`. Proof: `python3 scripts/render_autocreator.py --check`, `python3 scripts/validate_autocreator.py` and `python3 scripts/validate_docs.py` pass.
- [ ] T-U04-016 API baseline, rules and boundaries (FR-U04-072, FR-U04-082; SC-U04-010): `python3 scripts/check_public_api.py --update` leaves no difference and the check passes with 0 undocumented symbols; the baseline lost no line since `7b5b87d`; `git diff --stat 7b5b87d -- External Vendor Showcase Harnesses Apps/GenerativeArtStudio Apps/FluidArtPlayground Apps/FractalExplorer Apps/ParticleUniverse` prints nothing; no StoreKit, network, advertising or tracking name in `Apps/VisualCore`; record `public-api`, `dependencies` and the three `documented-api` checks.
- [ ] T-U04-017 Consumers: after `python3 scripts/release_check.py --only xcodegen`, build for testing into `Build/DerivedData/ua-f04-<Scheme>` the schemes `Showcase`, `GenerativeArtStudio`, `FluidArtPlayground`, `FractalExplorer`, `ParticleUniverse` and the harness projects `InteractiveDemo` and `SecondConsumer`, recorded as `build-<Scheme>`: exit 0 seven times, no tracked file changed.

## Phase 6: Evidence and convergence

- [ ] T-U04-018 Evidence `xcodegen`: `xcodegen generate --spec project.yml`.
- [ ] T-U04-019 Evidence `app-build`: `xcodebuild build -project VisualCore.xcodeproj -scheme VisualCore -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO` (SC-U04-001).
- [ ] T-U04-020 Evidence `app-phone-ios27`: `python3 scripts/xcodebuild_app.py --scheme VisualCore --runtime 27.2 --kind phone` (the brief's `xcodebuild test` command with the resolved simulator, then `check_test_enumeration.py --sources Apps/VisualCore/Tests --log <log>`).
- [ ] T-U04-021 Evidence `app-tablet-ios27`: the same with `--kind tablet`.
- [ ] T-U04-022 Evidence `app-phone-ios26`: the same with `--runtime 26.5 --kind phone`.
- [ ] T-U04-023 Evidence `app-tablet-ios26`: the same with `--runtime 26.5 --kind tablet`.
- [ ] T-U04-024 Evidence `compliance`, `app-isolation` and `release-symbols` on the final sources.
- [ ] T-U04-025 Evidence `host-visualcore`, `pure-ios27` and `pure-ios26`: `swift test --package-path Packages/VisualCore` and the pure package tests on both simulator runtimes.
- [ ] T-U04-026 Evidence `rendering-ios27` and `rendering-ios26`: the rendering package tests on both simulator runtimes (the app links its products).
- [ ] T-U04-027 Evidence `reference-a` and `reference-b`: the two chunks of the ProjectM reference regression (3 of 3 and 4 of 4).
- [ ] T-U04-028 Evidence `script-tests`, `docs`, `steering`; then confirm that the `ci` and `push-scan` runs of the last pushed commit succeeded.
- [ ] T-U04-029 (FR-U04-002) Add the app to the release tooling where the other apps are listed (`scripts/release_check.py`: xcodegen already covers it; add the unsigned simulator build of the scheme `VisualCore` as a step) with a test in `scripts/test_scripts.py`. Proof: `python3 scripts/release_check.py --list` shows the step and `python3 scripts/test_scripts.py` passes.
- [ ] T-U04-030 Run `/speckit-converge` for UA-F04; run `/speckit-implement` for every task it appends and `/speckit-converge` again, until a run appends nothing; then `python3 scripts/migration_ledger.py seal --gate UA-F04` and `python3 scripts/migration_ledger.py record --gate UA-F04`.
- [ ] T-U04-031 {device} After ImplementationLock-100, on D1, D2 and D3: check the launcher layout in portrait and landscape at the default and the largest text size, and make a VoiceOver spot check of the launcher, one experience route and the settings (manual VoiceOver is non-gating) (FR-U04-083). Stays open; does not block the gate.
- [ ] T-U04-032 {owner} Verify that the App Store name VisualCore is available and choose the final bundle identifier before distribution (OD-01, OD-02; FR-U04-084). Never performed by the agent; recorded for the owner; does not block the gate.

## Analyze fixes (2026-11-12, owner delegation)

`/speckit-analyze` run 1 found no critical or high finding and three medium ones, all applied before run 2:

- U1: T-U04-014 names the tool option that searches the release app (`check_release_symbols.py --forbid`).
- C1: T-U04-006 tests the quality override, including a tier the experience did not declare.
- I1: quickstart.md lists the rendering-package runs and the release-tool step; T-U04-029 names FR-U04-002.

`/speckit-analyze` run 2: 39 of 39 functional requirements and 10 of 10 success criteria are named by a task; 32
tasks, each mapped; plan.md and tasks.md name the same files; every check name of quickstart.md has a task; no
constitution conflict. No critical, high or medium finding remains.

## Dependencies & Execution Order

- T-U04-001 first. T-U04-003/004 block the app sources. T-U04-005 to T-U04-010 (debug support and tests) before
  T-U04-011. T-U04-013 and T-U04-014 need the built app.
- Evidence (T-U04-018 to T-U04-028) runs on the final sources, one heavy build at a time.

### Parallel Opportunities

- After T-U04-001: 002 (tool), 003+004 (pure model), 005 (debug support), 006 to 010 (five test files) in
  parallel agents; the lead integrates and one agent or the lead writes 011.

## Implementation Strategy

MVP is the target that builds and a launcher that shows what the catalog and the registry allow. Routes, first
run and settings follow in the same app sources and are proven by their own interface test classes.

## Notes

- A test task is committed together with the implementation task that follows it.
- An agent's report is not evidence: every proof command is run by the lead before the task is ticked.
- The real catalog has no available experience yet; the interface tests therefore use the debug fixture, and the
  shipping launcher's empty statement is itself tested.
