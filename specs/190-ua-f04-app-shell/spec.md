# Feature Specification: UA-F04 — The VisualCore app shell: launcher, navigation, settings and onboarding

**Feature Branch**: `190-ua-f04-app-shell` (spec directory only; work stays on `main`)

**Created**: 2026-11-12

**Status**: Draft

**Ledger gate**: UA-F04 (migration ledger) · ID namespace FR-U04-###, SC-U04-###, T-U04-###

**Input**: User description: the UA-F04 `/speckit-specify` prompt of Auto-Creator.md section 20
(`docs/catalog/unified-app-features.json`), verbatim in the invocation.

Canonical overrides:
- **Feature directory and ids:** `specs/190-ua-f04-app-shell`; requirement ids FR-U04-###, success criteria
  SC-U04-###, task ids T-U04-###.
- **Names from the brief:** the app folder `Apps/VisualCore/`, the application target VisualCore with its unit and
  UI test targets in `project.yml`, the placeholder bundle identifier `dev.visualcore.VisualCore`, the display
  name VisualCore, the identifiers `vc.tile.<id>`, the launch argument `-openExperience <id>`, the module
  VisualCoreUI and the tool `scripts/check_compliance.py`. Names of new types are proposals until `/speckit-plan`
  confirms them. Other modules are not named here.
- **Who the users are:** a person who installs the app, finds an experience, opens it, changes a setting and comes
  back later; and the later features that plug into the shell: persistence (UA-F05), quality (UA-F06), the
  adoption of the first four experiences (UA-F07), the purchase (UA-F08) and the verification runner (UA-F09).
- **Out of scope:** StoreKit and the paywall (UA-F08) and every individual experience.
- **Device-only item:** launcher layout and a VoiceOver spot check on D1, D2 and D3 (manual VoiceOver is
  non-gating). **Owner-only item:** verifying that the App Store name VisualCore is available and choosing the
  final bundle identifier before distribution.
- **What exists today:** the runtime catalog with 100 launch experiences, none of them available yet (no
  integration gate has passed); the session and its host view (UA-F03); accessibility settings and
  acknowledgements views in VisualCoreUI; a project file with the Showcase and four standalone apps, none of them
  the unified app.

## Clarifications

### Session 2026-11-12

Questions asked and answered under the owner's standing delegation (recommended option first).

- Q: Where does the experience used by the interface tests live, given that the sample of the framework may be
  linked by test targets only? → A: In the app target's own sources, in one folder that compiles only in debug
  builds, together with the test catalog and the handling of test launch arguments (recommended). A check on the
  release build proves that none of it is shipped.
- Q: Where are the shell's preferences kept? → A: As one versioned value in the app's own preferences storage
  (recommended); experience data lies in one folder per storage namespace inside the app's Application Support
  folder. A reset removes exactly these. Nothing is stored outside the app's container.
- Q: Where does the shell's pure logic live? → A: In the existing pure experience module, next to the catalog it
  works on (recommended): launcher sections, route restoration, first-run decision, preferences value and reset
  plan. No new module.
- Q: How does the catalog get into the app? → A: The app bundles the tracked files of the `Catalog` folder
  directly (recommended); no copy is kept in the app folder, so the bundle and the validated catalog cannot drift.
- Q: On which simulators do the interface tests run? → A: On one phone and one tablet of each runtime, chosen by
  runtime and kind, never by a recorded identifier (recommended).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - There is one app, and it builds (Priority: P1) 🎯

The project defines exactly one shippable application, VisualCore, with a unit test target and an interface test
target. It builds without signing for the simulator. The Showcase, the harnesses and the four standalone apps
stay what they are: development targets that are never shipped.

**Why this priority**: ADR-0009 D-01 and Principle XI. Everything that follows is tested inside this target.

**Independent Test**: generate the project, build the app and its tests for the generic simulator, and read the
target list.

**Acceptance Scenarios**:

1. **Given** the repository, **When** the project is generated and the app is built for the generic simulator
   without signing, **Then** the build succeeds and the product is named VisualCore with the bundle identifier
   `dev.visualcore.VisualCore`.
2. **Given** the project definition, **When** its application targets are listed, **Then** exactly one is marked
   as the shippable app, and it has one unit test target and one interface test target.
3. **Given** the built app, **When** its contents are inspected, **Then** it holds the runtime catalog, no code of
   the reference engine, no test fixture and no sample experience.

---

### User Story 2 - The launcher shows what can be opened, and says honestly what cannot (Priority: P1)

A person sees the available experiences as tiles, grouped by category, and can search them. Each tile says in
words whether the experience is free or premium. An experience that is not available in this build does not
appear. When nothing is available, the launcher says so plainly.

**Why this priority**: the launcher is the app's front door; an entry that opens nothing would be a false claim.

**Independent Test**: start the app with a test catalog of several available experiences and search; start it
with the real catalog of today and read the empty state.

**Acceptance Scenarios**:

1. **Given** a catalog with available experiences in three categories, **When** the launcher appears, **Then**
   each category has a heading and its tiles, in the order of the catalog, and each tile carries the identifier
   `vc.tile.<id>` and its tier as text.
2. **Given** the launcher, **When** a search text is entered, **Then** the tiles are those the catalog's search
   returns for that text, in its order, and an empty result says that nothing matches.
3. **Given** a catalog in which no experience is available, **When** the launcher appears, **Then** it shows one
   plain statement that no experience is available in this build, and no tile.
4. **Given** a catalog entry that is available but has no registered experience, or a registered experience with
   no available entry, **When** the app starts, **Then** that entry is not shown, and the mismatch is reported in
   the app's diagnostics.
5. **Given** a damaged catalog, **When** the app starts, **Then** the launcher shows a recoverable message and the
   app does not crash.

---

### User Story 3 - Every route works on phone and tablet, at every text size (Priority: P1)

A person moves between the catalog, an experience, the settings and the about screen. On a phone the routes
follow one another; on a tablet the catalog stays beside the content where there is room. At the largest text
size no control is cut off.

**Why this priority**: acceptance item 3 and E-12.

**Independent Test**: interface tests on a phone and a tablet simulator of both runtimes walk the four routes at
the default and at the largest text size and run the accessibility audit on each.

**Acceptance Scenarios**:

1. **Given** the app on a phone, **When** a tile is activated, **Then** the experience route opens with the
   experience running and a way back to the catalog; **When** back is chosen, **Then** the experience is closed
   and the catalog returns.
2. **Given** the app on a tablet, **When** it is in a regular-width layout, **Then** catalog and content are
   visible side by side; in a compact width it behaves as on a phone.
3. **Given** any route at the largest accessibility text size, **When** it is shown, **Then** every control is
   reachable and no label is truncated to nothing.
4. **Given** the app was terminated on a route, **When** it starts again, **Then** it returns to the last route,
   the last experience and the last catalog filter.
5. **Given** any input from outside the app (a link, a file, a shortcut), **When** it arrives, **Then** no route
   opens because of it: the app declares no URL scheme and no document type.

---

### User Story 4 - First run leads straight to a working experience (Priority: P1)

A person starts the app for the first time. No account, no purchase and no permission is asked for. A short
welcome names what the app is and leads to the launcher; one more tap opens a free experience that runs.

**Why this priority**: acceptance item 4; the first minute decides whether the app is kept.

**Independent Test**: an interface test starts the app with erased data and a test catalog and counts the
prompts and taps until a free experience is running.

**Acceptance Scenarios**:

1. **Given** a first start, **When** the app appears, **Then** no system prompt, sign-in or purchase screen is
   shown, and after the welcome the launcher is visible.
2. **Given** the welcome, **When** its one primary action is taken, **Then** the first free experience of the
   catalog opens and reaches the running state.
3. **Given** a later start, **When** the app appears, **Then** the welcome is not shown again.
4. **Given** the test launch argument `-openExperience <id>` in a build made for testing, **When** the app
   starts, **Then** that experience opens directly; in a release build the argument has no effect.

---

### User Story 5 - Settings are few, native and reversible (Priority: P2)

A person opens the settings and finds: the choices for reduced motion and reduced flashing, a quality override, a
reset for one experience's data and for all data, the privacy statement, and the acknowledgements.

**Why this priority**: acceptance item 5; settings are what a careful person looks at before trusting an app.

**Independent Test**: interface tests change each setting, restart the app and read it back; reset tests check
that exactly the stated data is gone.

**Acceptance Scenarios**:

1. **Given** the settings, **When** reduced motion or reduced flashing is changed, **Then** the choice is kept
   across a restart and is the value experiences receive.
2. **Given** the settings, **When** the quality override is set to a tier or back to automatic, **Then** the
   choice is kept across a restart and is the value a newly opened experience receives.
3. **Given** data of two experiences, **When** one experience's data is reset after a confirmation, **Then** only
   that experience's data is gone; **When** all data is reset after a confirmation, **Then** every experience's
   data and the shell's preferences are gone and the app is as after a first start.
4. **Given** the settings, **When** the privacy statement is opened, **Then** it states that the app collects
   nothing, uses no network and shows no advertising, in plain words.
5. **Given** the about screen, **When** acknowledgements are opened, **Then** the licence inventory of the
   repository is shown.

---

### User Story 6 - The app never talks to a network (Priority: P2)

The compliance check of the repository covers the app's sources and its built product: no networking code, no
advertising or tracking framework, no usage description that the app does not need.

**Why this priority**: acceptance item 6 and Principle XII.

**Independent Test**: run the compliance and isolation checks on the app folder and the built app; add a scratch
violation and see the check fail.

**Acceptance Scenarios**:

1. **Given** the app's sources and the built app, **When** the checks run, **Then** they pass and report the
   number of files read.
2. **Given** a scratch source with a networking call, **When** the check runs, **Then** it fails and names the
   file.

---

### Edge Cases

- **No experience available** (the state of the real catalog today): the launcher's empty statement; the welcome
  leads to the launcher without offering an experience to open.
- **Experience fails to open:** the session's failure view with Retry and Back appears inside the experience
  route; the catalog stays usable.
- **Leaving while an experience prepares:** back cancels the preparation and returns to the catalog.
- **Backgrounding and interruptions:** the route stays; the session suspends and resumes the experience.
- **Memory warning:** the session's message appears in the experience route with Back.
- **Damaged or newer preferences:** unreadable preferences are replaced by defaults with a recorded note; the app
  starts.
- **Last experience no longer available:** on restart the app returns to the catalog instead.
- **Unknown id in `-openExperience`:** the launcher is shown and the diagnostics note the unknown id.
- **Rotation and split view:** layouts change between compact and regular without losing the route or the
  running experience.
- **Reset while an experience is open:** the experience is closed first.

## Requirements *(mandatory)*

### Functional Requirements

**The app target**

- **FR-U04-001**: The project MUST define exactly one shippable application target, VisualCore, with the bundle
  identifier `dev.visualcore.VisualCore` and the display name VisualCore, and one unit test target and one
  interface test target for it. No other target MUST be described as shippable.
- **FR-U04-002**: The app MUST build without signing for the generic simulator from a freshly generated project.
- **FR-U04-003**: The app MUST bundle the tracked runtime catalog files of the `Catalog` folder directly, with no
  copy elsewhere, and MUST load them through the validated loader.
- **FR-U04-004**: A release build of the app MUST contain no test fixture, no sample experience, no test launch
  argument handling and no code of the reference engine.
- **FR-U04-005**: The app's own module MUST have a name different from the framework package, so that the two
  cannot be confused in code.
- **FR-U04-006**: This feature MUST NOT add an app icon or any other raster picture; the icon is generated by a
  script in the release preparation, and until then the target builds without one.

**Registry and availability**

- **FR-U04-010**: The app MUST hold one explicit list of registered experiences: for each an id and a factory.
  Nothing is discovered or loaded dynamically.
- **FR-U04-011**: At start the app MUST compare the registered ids with the available entries of the catalog. A
  free experience MUST be shown only when it is available in the catalog and registered; an available premium
  entry is shown with its tier text and opens only the statement of FR-U04-012. Every mismatch MUST be
  recorded in the app's diagnostics and MUST fail the app's unit tests.
- **FR-U04-012**: A premium experience MUST NOT be opened by this feature: until the purchase feature exists,
  premium tiles are shown with their tier text and open a plain statement that premium experiences are not yet
  available in this build.

**Launcher**

- **FR-U04-020**: The launcher MUST show every available and registered experience as a tile, grouped under its
  category in the order of the category list, tiles in catalog order.
- **FR-U04-021**: Each tile MUST carry the accessibility identifier `vc.tile.<id>`, a label made of the title and
  the tier, the tier as visible text ("Free" or "Premium"), and a picture drawn by the interface from the
  entry's two colors and its seed. The launcher MUST create no rendering context.
- **FR-U04-022**: The launcher MUST offer a search field that takes at most 100 characters. The result MUST be
  what the catalog's search returns, in its order. A search without a result MUST show a plain statement.
- **FR-U04-023**: When no experience is available the launcher MUST show one plain statement and no tile.
- **FR-U04-024**: A catalog that cannot be loaded MUST lead to a recoverable message with the error's code, never
  to a crash.

**Routes**

- **FR-U04-030**: The app MUST have the routes catalog, experience, settings and about, each with the identifier
  `vc.route.<name>` on its root.
- **FR-U04-031**: The experience route MUST show the session's host view for the opened experience and a control
  that returns to the catalog; returning MUST close the experience.
- **FR-U04-032**: In a regular-width layout the catalog and the content MUST be visible side by side; in a
  compact width the routes MUST follow one another.
- **FR-U04-033**: The last route, the last experience and the last catalog filter (the search text) MUST be
  restored after termination. When the last experience is no longer available the catalog is shown.
- **FR-U04-034**: The app MUST declare no URL scheme, no document type and no other entry that lets an outside
  input open a route.
- **FR-U04-035**: Every route MUST stay usable at the largest accessibility text size on the smallest supported
  phone and on a tablet: every control reachable, no label cut to nothing, touch targets of at least 44 by 44
  points.

**First run**

- **FR-U04-040**: On the first start the app MUST show a welcome with one primary action and MUST NOT show an
  account, purchase or permission prompt.
- **FR-U04-041**: The welcome's primary action MUST open the first available free experience of the catalog; when
  none is available it leads to the launcher.
- **FR-U04-042**: The welcome MUST be shown once; a later start goes to the restored route.
- **FR-U04-043**: In builds made for testing, the launch argument `-openExperience <id>` MUST open that
  experience directly, and further test arguments MAY select a test catalog and erase the app's data. In a
  release build these arguments MUST have no effect and their handling MUST be absent.

**Settings and about**

- **FR-U04-050**: Settings MUST offer the reduced-motion and reduced-flashing choices through the existing
  accessibility settings section, and MUST keep them across restarts.
- **FR-U04-051**: Settings MUST offer a quality override: automatic, or a tier from 0 (best) to 7. The choice MUST
  be kept and MUST be applied to an experience when it opens; a stored tier that an experience did not declare
  MUST be replaced by that experience's last declared tier.
- **FR-U04-052**: Settings MUST offer a reset of one experience's data and a reset of all data, each behind a
  confirmation. The reset of one experience MUST remove only what is stored under that experience's storage
  namespace; the reset of all data MUST also remove the shell's preferences. An open experience MUST be closed
  first.
- **FR-U04-053**: Settings MUST show the privacy statement: nothing collected, no network, no advertising, no
  account.
- **FR-U04-054**: The about screen MUST show the app's name and version and the acknowledgements through the
  existing acknowledgements view and licence inventory.

**Preferences**

- **FR-U04-060**: The shell's preferences (welcome seen, last route, last experience, catalog filter, quality
  override, accessibility choices) MUST be one versioned value in the app's own preferences storage; experience
  data MUST lie in one folder per storage namespace inside the app's Application Support folder; nothing MUST be
  stored outside the app's container. An unreadable or newer value MUST be replaced by
  defaults, with a recorded note, and MUST NOT stop the app.
- **FR-U04-061**: Pure decisions of the shell (which tiles to show, route restoration, first-run decision, the
  rules of a reset) MUST be host-testable logic in the pure experience module, next to the catalog.

**Privacy and boundaries**

- **FR-U04-070**: The app MUST make no network request and MUST contain no advertising, analytics or tracking
  code. The offline and isolation checks of the repository MUST cover `Apps/VisualCore` and its built product,
  and MUST fail when sources are missing.
- **FR-U04-071**: The built app MUST declare no usage description, because the shell needs no permission.
- **FR-U04-072**: The feature MUST NOT add StoreKit code, a paywall or an individual experience, and MUST NOT
  change the reference submodule or the vendored tree.

**Verification**

- **FR-U04-080**: Interface tests MUST run on the iOS 27.x and iOS 26.5 simulators, on a phone and on a tablet
  chosen by runtime and kind,
  with the enumeration guard (a run that enumerates no test is a failure), and MUST include the accessibility
  audit of every route.
- **FR-U04-081**: The interface tests MUST use a test catalog and a test experience that live in one folder of
  the app's sources that compiles only in debug builds; a check on the release build MUST find none of it.
- **FR-U04-082**: Every public symbol added to the framework MUST have documentation, the API baseline MUST be
  updated, package tests MUST pass on the host and on both simulator runtimes, and the reference regression MUST
  pass.
- **FR-U04-083**: The launcher layout and a VoiceOver spot check on D1, D2 and D3 MUST be listed as a device task
  and MUST NOT be claimed from simulator runs.
- **FR-U04-084**: The availability of the App Store name and the choice of the final bundle identifier MUST be
  recorded as an owner action and MUST NOT be performed by the agent.

### Key Entities

- **Experience registration**: id and factory.
- **Launcher model**: sections (category, tiles), search text, empty and error states.
- **Tile**: id, title, summary, tier text, two colors, seed.
- **Route**: catalog, experience (with id), settings, about.
- **Shell preferences**: schema version, welcome seen, last route, last experience, filter, quality override,
  accessibility choices.
- **App diagnostics**: catalog state, registry mismatches, unknown test arguments, preference notes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-U04-001**: The project has exactly 1 shippable application target with 2 test targets; the unsigned
  simulator build succeeds from a freshly generated project.
- **SC-U04-002**: With a test catalog of 6 available experiences in 3 categories the launcher shows 6 tiles under
  3 headings; 100% of the tiles have the identifier `vc.tile.<id>` and a visible tier text; with the real catalog
  of today it shows 0 tiles and the empty statement.
- **SC-U04-003**: A table of 10 search texts gives, for each, exactly the ids the catalog's search returns.
- **SC-U04-004**: The four routes pass their interface tests on a phone and a tablet simulator of both runtimes,
  at the default and at the largest accessibility text size: 16 route checks per runtime, 0 clipped controls, 0
  accessibility audit issues.
- **SC-U04-005**: From a first start, a free test experience is running after at most 2 taps, with 0 system
  prompts, 0 sign-in screens and 0 purchase screens.
- **SC-U04-006**: Each of the 3 settings (two accessibility choices, quality override) survives a restart; the
  reset of one experience removes 100% of that experience's stored items and 0 of another's; the reset of all
  data removes both and the preferences.
- **SC-U04-007**: The offline and isolation checks pass on the app's sources and built product and fail on 1 of 1
  scratch violation; the built app declares 0 usage descriptions.
- **SC-U04-008**: A release build of the app contains 0 symbols of the test experience and of the test argument
  handling.
- **SC-U04-009**: After a termination the app returns to the last route, experience and filter in 3 of 3 tested
  cases, and to the catalog when the last experience is not available.
- **SC-U04-010**: 100% of the new public framework symbols are documented, the API baseline check passes with no
  removed line, package tests pass on the host and both runtimes, and the reference regression passes 7 of 7.

## Assumptions

- No experience is available in the real catalog until the first integration gate passes (UA-F07 and the X
  gates). Until then the shipping launcher truthfully shows its empty statement, and "first run reaches a running
  free experience" is proven with a test catalog and a test experience that exist only in test builds.
- Stored data of experiences is the subject of UA-F05. This feature defines what a reset removes (everything
  under an experience's storage namespace, and the shell's preferences) and removes it; UA-F05 decides the
  layout below that namespace.
- The quality override is stored and passed on here; what a tier means is UA-F06.
- Premium experiences cannot be opened before UA-F08; their tiles appear, when available, with the tier text.
- The tablet layout uses the system's split navigation; the phone layout a navigation stack.
- Texts are English and live in string resources.
- The name VisualCore and the bundle identifier are placeholders approved by the owner (OD-01, OD-02).
- Simulator results are not device evidence; the device task covers layout and a VoiceOver spot check.

## Absorbed source requirements

R02-F25 "Shared native iOS shell and evidence-friendly UI" and R02-F26 "Games input, accessibility and haptics
contract" (shell-level parts), archive round 2.

| Source requirement | Decision | Where and why |
|---|---|---|
| R02-F25: SwiftUI menus (launcher, navigation) | adopted | FR-U04-020 to FR-U04-035 |
| R02-F25: progress display | adapted | Level progress belongs to the games; the shell shows the session's preparing view (UA-F03) |
| R02-F25: pause and resume | adopted | Through the session of UA-F03; the route survives backgrounding (Edge Cases) |
| R02-F25: transparent render hosting | adopted | FR-U04-031: the experience route shows the session's host view |
| R02-F25: evidence-friendly interface (stable identifiers) | adopted | FR-U04-021, FR-U04-030, FR-U04-043 |
| R02-F25: accessibility of the shell | adopted | FR-U04-035, FR-U04-080 |
| R02-F26: Reduce Motion and Reduce Flashing | adopted | FR-U04-050: the shell stores the choices and hands them to experiences |
| R02-F26: color independence | adopted | FR-U04-021: the tier is text; SC-U04-002 |
| R02-F26: VoiceOver mirrors of game state | adapted | The canvas label comes from the experience contract (UA-F02); the shell's own views are native and labelled |
| R02-F26: gesture arbitration | superseded | Inside an experience; the shell adds no gesture of its own to the canvas |
| R02-F26: haptics | superseded | Not a shell concern; experiences decide, and devices verify |
| Both: price range and "no IAP" of the round 2 text | superseded | ADR-0009 and Principle XII; the purchase is UA-F08 |

## Traceability

| Source | Requirement |
|---|---|
| Acceptance 1 (one application target with unit and UI tests; unsigned simulator build) | FR-U04-001–006, US1, SC-U04-001 |
| Acceptance 2 (launcher by category with search; `vc.tile.<id>`; tier as text) | FR-U04-010–012, FR-U04-020–024, US2, SC-U04-002, SC-U04-003 |
| Acceptance 3 (routes on phone and tablet through the largest text size) | FR-U04-030–035, US3, SC-U04-004, SC-U04-009 |
| Acceptance 4 (first run reaches a running free experience without prompts) | FR-U04-040–043, US4, SC-U04-005 |
| Acceptance 5 (settings: accessibility, quality override, data reset, privacy statement) | FR-U04-050–054, FR-U04-060, FR-U04-061, US5, SC-U04-006 |
| Acceptance 6 (no network request; the offline rule covers the app) | FR-U04-070–072, US6, SC-U04-007 |
| Acceptance 7 (UI tests and audits on both runtimes with the enumeration guard; `-openExperience`) | FR-U04-043, FR-U04-080, FR-U04-081, SC-U04-004, SC-U04-008 |
| Scope: acknowledgements, placeholder identifier, display name | FR-U04-001, FR-U04-054 |
| Device-only and owner-only items | FR-U04-083, FR-U04-084 |
| Auto-Creator.md sections 11.1 and 11.7 | FR-U04-001–005, FR-U04-010, FR-U04-021, FR-U04-030–034, FR-U04-040–043, FR-U04-050–054 |
| ADR-0009 D-01 | FR-U04-001 |
| Constitution VII, VIII, IX, XI, XII | FR-U04-035, FR-U04-070, FR-U04-071, FR-U04-024, FR-U04-060, FR-U04-001, FR-U04-012 |
| Framework obligations | FR-U04-082, SC-U04-010 |
| R02-F25, R02-F26 | section "Absorbed source requirements" |
