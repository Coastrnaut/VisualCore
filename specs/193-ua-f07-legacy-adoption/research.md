# Research: UA-F07 — Adoption of the existing apps A01 to A04 as experiences

The read-only audit was done on 2026-11-12 by an audit agent at `0ca7ebb`. The lead checked the facts the design
rests on again at `HEAD` (after UA-F09). The decisions follow; the clarifications of spec.md are binding.

## 1. Audit

### Steering and migration documents

- **Auto-Creator.md section 17**: adapters come first and the sources stay where they are; parity is proven before
  any `git mv`; the standalone target is retired last; one experience at a time, each revertible alone; records
  are never rewritten. The order per experience is: adapter and registration → conformance and session tests →
  ported interface tests with a name table → verification runner on both runtimes → move along the path map →
  remove the target → record X-A01 to X-A03. X-A04 waits for A04-P04 to P06.
- **docs/migration/migration-plan.md section 2.1**: per app, `Core` sources move to
  `Packages/ExperiencesCreative/<Name>/Core`, Core tests to `…/CoreTests`, the `App` folder to `…/Experience`
  (the `@main` file is retired), unit tests to `…/ExperienceTests`, interface tests to
  `Apps/VisualCore/Tests/UI/<Name>`, and shaders to `…/Shaders`. Each `Package.swift` merges into
  `Packages/ExperiencesCreative/Package.swift`. Asset catalogs are retired; privacy manifests merge (UA-F11).
- **docs/migration/path-map.json**: 33 planned A01–A04 entries, all pending. `Catalog/path-map.json` has no move.
- **Migration ledger**: X-A01 to X-A03 depend on UA-F07, UA-F05, UA-F06 and UA-F09, all now pass except UA-F07.
  X-A04 also needs legacy A04-P04 to P06, which are pending.
- **Catalog**: the four entries are free, in category `create`, with `quality_tiers: []` and `available: false`.
  `Catalog/registrations.json` is empty.

### The four apps (sizes, domain, rendering, storage, input)

| | A01 Generative Art Studio | A02 Fluid Art Playground | A03 Fractal Explorer | A04 Particle Universe |
|---|---|---|---|---|
| App sources | 14 files, 1,166 lines | 8 files, 1,548 lines | 9 files, 1,368 lines | 5 files, 876 lines |
| Core package | 10 sources, 31 tests | 13 sources, 56 tests | 10 sources, 38 tests | 7 sources, 41 tests |
| App unit tests | 40 | 76 | 64 | none |
| UI tests | 14 in 8 classes | 9 in 7 classes | 10 in 6 classes | 23 in 7 classes |
| Domain state | `ArtDocument` (Codable) + family, preset, `SceneClock` | `FluidConfiguration` (Codable), `SplatQueue`; fluid in GPU textures | `FractalState` (not Codable), `Bookmark` (Codable framing) | `SceneSimulation` (fixed 1/120 s steps, commands), `ParticleScene` (Codable) |
| Rendering | `FullScreenShaderScene` / `ParticlesArtScene` via `ArtSceneFactory`, shaders from `Bundle.main` | `EffectScene(FluidFieldsScene)`, inline GLSL | `FullScreenShaderScene` (inline GLSL) | `ParticleLayerScene` with a per-frame source |
| Storage | `CompositionLibrary` (`DocumentStore`), `@AppStorage` | temporary captures | `BookmarkLibrary` (`NamedLibrary`) | none |
| Input | native controls | canvas strokes and pinch (`host.pointerHandler`) | canvas pan and pinch (`host.pointerHandler`), buttons, text | canvas tap and drag (`DragGesture`) |
| Clock use | `SceneClock` by frame delta | `CACurrentMediaTime` quality policy | `systemUptime` for tours and palette | `Date` fallback, stepping in the render callback |

- **Fixtures**: the four A01 `library-v1` documents, A03 `bookmark-v1.json` and A04 `replay-v1.json` match their
  SHA-256 in `docs/migration/pre-fable-baseline.json`.
- **Name collisions**: `AppAutomation`, `HomeView`, `SceneModel` and `SettingsView` exist in several apps. All
  four apps have UI test classes named `AccessibilityAuditUITests` and `LaunchSmokeUITests`.
- **Paths read by tests**: some tests read files by `#filePath` (A01 `CrashRecoveryTests`, A03 `MigrationTests`,
  the `IconRenderTests` of A01–A03, the `CopyTests` of A02/A03). `docs/apps/*/visualcore-contract.json` cite
  `Apps/...` paths that `check_app_contract.py` requires. `release_check.py` derives per-app steps from the `Apps/*`
  folders and from `docs/apps/*/release.json`.
- **Host**: `ExperienceHostView` shows `RenderSurface` and the controls. No canvas pointer reaches an experience.
  `RenderHost.pointerHandler: ((PointerEvent) -> Void)?` exists (`RenderView+Touches.swift:54`), and
  `PointerEvent { id, phase, location: Vec2, timestamp }` is a pure type in `VisualCoreScenes`.
- **Verification**: `scripts/verify_experiences.py` (UA-F09) plays scenario manifests in the app for registered
  experiences. `ExperienceRegistration.scenarioManifest` and `controls` exist.

## 2. Decisions

### R1. Where the adapters live before the move

**Decision**: one framework target per experience in `project.yml`: `GenerativeArtStudioExperience`,
`FluidArtPlaygroundExperience`, `FractalExplorerExperience` and `ParticleUniverseExperience`. Each compiles its
app's `App` folder, minus the `@main` file and the app-only files listed in data-model.md section 1, plus a new
`Adapter/` folder with the core, presenter, controls and manifest. The unified app links the four frameworks.
They are frameworks, not app targets, so rule 1 holds (one app target, one bundle identifier).

The standalone targets keep compiling the same files until their retirement. After parity is proven, the
`git mv` moves both the app sources and the adapter to `Packages/ExperiencesCreative/<Name>/Experience`, and the
framework target is replaced by the package target.

**Rationale**: "adapters first, sources stay" (section 17.1). Separate modules avoid the name collisions.
**Alternatives**: compiling the app sources into the unified app's module (name collisions); moving at once
(against FR-U07-040).

### R2. The canvas touch path (clarification 5)

**Decision**:
- `ExperiencePresenter` gains `func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort)`,
  with a default that does nothing.
- `Experience` gains `handlePointer(_:viewSize:)`, forwarded by `ExperienceShell`.
- `ExperienceSession` sets `renderHost.pointerHandler` for the open experience while it runs and clears it at
  every close.
- The presenter turns events into domain actions with positions normalized to 0…1 of the view (for example
  `stroke [x, y, phase, id]`, `pan [dx, dy]`, `place [x, y]`) and sends them through the port. A scenario can
  therefore send the same actions without touches.

**Rationale**: every input stays a recordable, deterministic action. The pointer type already exists in pure code.
**Alternatives**: SwiftUI gestures in the controls view (A04's `DragGesture` on the canvas would need the canvas
in the controls); raw pointer events as actions (positions in points depend on the device).

### R3. A02's GPU state (clarification 1)

**Decision**: `FluidArtCore` holds:
- the `FluidConfiguration`;
- the control choices (palette, edges, detail, paused);
- `pendingSplats` (bounded by `SplatQueue.maxPending`);
- `stepIndex` and the seed.

Strokes become splats in `apply`, and `update(step:)` moves pending splats to the "applied at step n" list that the
presenter reads once. The presenter runs the GPU passes for the steps since its last draw, and its fields restart
from `DyeSeed.pattern(seed:)` after a restore or a context loss. ADR-0011 records that the fluid picture is
presentation, not an outcome.

**Rationale**: E-04, and clarification 1. **Alternatives**: the CPU `FluidSolver` as the authority (changes the
domain behaviour and the cost).

### R4. Quality levels (clarification 2)

**Decision**: `qualityProfile` per adapter:
- A01: one level.
- A02: Full, Reduced and Minimal, applied by the presenter to the solver's iterations and the splat cap of the
  picture.
- A03: one level.
- A04: four levels from `SceneQuality`, applied as a draw cap. The simulation keeps the requested limit.

The level names go to the catalog through the registration's profile.

### R5. A04 snapshot as a replay (clarification 3)

**Decision**: the payload is `{ scene: ParticleScene, commands: [(step, SceneCommand-equivalent)], stepIndex,
playing, … }`. `restore(payload:seed:)` prepares `SceneSimulation` from the scene and seed and replays the
commands up to `stepIndex`. A short test measures the replay's cost per step on both simulators, and the longest
state within the limit follows from it (corrected 2026-11-13: the owner's rule that tests are short).

### R6. Candidates (clarification 4)

**Decision**: `ExperienceRegistry.candidates: [ExperienceRegistration]` holds the adopted experiences, each with
its scenario manifest. `ScenarioLaunch.targets` reads `all + candidates`. The debug argument
`-vcCandidates` makes the launcher show candidates under a fixture catalog in which their entries are available.
The registry agreement test still compares `all` with the catalog. Recording X-A0n moves the registration from
`candidates` to `all` and lets `build_catalog.py` mark it available.

### R7. Ported interface tests

**Decision**: each app's UI tests are copied into `Apps/VisualCore/Tests/UI/<Name>/` with class names prefixed by
the app (`GASAccessibilityAuditUITests` …). Locators change to `experience.<id>.<control>`, and launches use
`-vcResetData -vcSkipWelcome -vcCandidates -openExperience <id>`. The old files stay in the standalone targets until
their retirement.

`specs/193-ua-f07-legacy-adoption/test-map.csv` is the mapping table, with the columns
`app, old_class, old_method, new_class, new_method, note`. A new check, `scripts/check_test_map.py`, fails when an
old test method is missing from the table, when a new name in it does not exist in the sources, or when it did not
pass in a given log.

### R8. Order and gates

A01 is adopted, verified, moved and retired first, then A02, A03 and A04. A04 is adopted and verified, and its
sources move, but its target is retired only when X-A04 can pass; until then its standalone target stays.
X-A01 to X-A03 are recorded by this feature with the runner's commands (Auto-Creator.md 22.2). The plan splits the
work into one phase per app so that each can be reverted alone.

### R9. Paths after a move

A test that reads a repository path by `#filePath` gets the path expression changed in the commit of the move.
`check_app_contract.py` resolves a cited path through `Catalog/path-map.json` when the old path is gone. The
`release_check.py` steps derived from `Apps/*` gain the experience packages
(`Packages/ExperiencesCreative/Package.swift` host tests), and `app-release-*` steps are skipped for retired
schemes. Icons and store listings that tests read are read from their history paths (`docs/apps`) or the tests are
mapped (FR-U07-033).

### R10. Records

`docs/apps/<slug>/README.md` (new, one paragraph) states that the store listing is superseded by the unified app.
The dossier files are not edited. The legacy ledger is untouched; its hash is compared before and after.

## 3. Baseline (2026-11-13, before any adapter)

| Core package | Tests that pass |
|---|---|
| `Apps/GenerativeArtStudio/Core` | 31 (Swift Testing) |
| `Apps/FluidArtPlayground/FluidArtPlaygroundCore` | 56 (XCTest) |
| `Apps/FractalExplorer/FractalExplorerCore` | 12 (XCTest) + 26 (Swift Testing) |
| `Apps/ParticleUniverse/ParticleUniverseCore` | 40 (Swift Testing) + 1 (XCTest) |

- `python3 scripts/migration_baseline.py verify`: 0 problems; this covers the six fixture hashes.
- Legacy ledger: the SHA-256 of `.autonomy/state.json` is
  `2604ffd8292cc8a877cdc0300e90cdea5c28ffdc4ef8e58b085e40526d44b7ca`.

## 4. Corrections during implementation

- **A01 adapter core location (T-U07-007, T-U07-008, 2026-11-13).** The pure core is a small SwiftPM package,
  `Apps/GenerativeArtStudio/GenerativeArtStudioAdapter/Package.swift` (product `GenerativeArtStudioAdapterCore`), with the core at
  `Adapter/Core/GenerativeArtCore.swift` and its host tests at `Adapter/Tests/GenerativeArtCoreTests.swift`, instead
  of a file compiled only into the framework target. The core then runs under `swift test` on the Mac like the Core
  packages; the presenter, controls and manifest stay in `Adapter/Experience/` and are compiled by the framework
  target. `MigrationChain` is in `VisualCorePersistence`, which the package lists. The core's six differences from
  the standalone app are in its file header (FR-U07-003): fixed-step time, Reduce Motion as the control `rate`, a
  deterministic `seed.shuffle`, `family` as one control, `open`/`value.<name>`/`rebase` for opening a saved
  composition, and `save` counting saves for the outcome `work-saved`.
- **A01 framework, manifest, probe and export (T-U07-009 to T-U07-011, 2026-11-13).**
  - `GenerativeArtStudioExperience` is a *static* framework (`framework.static`). A dynamic framework and the app
    would each link their own copy of the Swift packages they share, so types such as `ExperienceShell` would exist
    twice. The static framework has no bundle of its own, so the app copies `Apps/GenerativeArtStudio/Shaders` as a
    folder resource and the presenter loads it through `Bundle(for:)`, which is the app's bundle.
  - `LaunchComposition.swift` stays in the framework, because `GalleryView` uses it (data-model section 1 corrected).
  - The manifest is in the pure package (`Adapter/Core/GenerativeArtManifest.swift`), so that its committed digests
    and result codes are checked against the engine by `swift test`. The five `fixture-<n>` scenarios follow the five
    fixtures of the A01 card. Export dimensions and colour profile cannot be scripted as actions; fixture 4 checks
    the state at an explicit time. The export itself is covered by the ported interface tests.
  - The frame probe: the runner needs one probe whose colour class follows from the state. Gradient noise and tiling
    span the whole palette, so no pixel of theirs has a known class. The Particles background corner is a palette
    colour over a known range, scaled by a known factor. Its class is derived on the CPU (the GPU's `vc_palette`
    equals `Palette.sample`) and declared only when it is the same class at every point of that range with ±4 levels
    of margin, and only while no particle can reach the corner. A preparation therefore opens the Particles family
    (core difference 4).
  - Export needs the session's render host, which an experience never sees. VisualCoreExperienceHost gains
    `ExperienceSession.renderStill(width:height:)` and the environment value `experienceStillRenderer`, which
    `ExperienceHostView` sets on the controls. This is a new public API: the baseline was updated, `StillRenderTests`
    was added, and the reference regression was run. The controls offer the PNG through `ShareLink` without
    writing a file (FR-U07-020).
- **A01 verification (T-U07-013, 2026-11-13).**
  - `Catalog/registrations.json` gains A01's entry (capabilities, `level-0`, the Sunset tile colours, no content) and
    the key `manifest`, which `verify_experiences.py` already read and `build_catalog.py` now accepts. It names
    `Apps/GenerativeArtStudio/GenerativeArtStudioAdapter/scenario-manifest.json`, the manifest's JSON form with the control ids, which
    a host test keeps equal to the Swift manifest. A registration does not make an entry available; only X-A01 does.
  - The runner's reducer-bypass audit rejects an action of an undeclared control in a manifest, so the
    `rejection` scenario uses a wrong value count instead of an unknown control. JSON cannot hold infinity, so
    fixture 2 uses an out-of-range value instead of a non-finite one.
  - The first run failed teardown-reentry on iOS 27.2 with `grew(gpu_bytes, by: 2560)` (check `a01-verify-27`, kept).
    Each cycle opens the Particles fountain from empty, and its instance buffer grows over the first frames to the
    same peak in every cycle. The growth rule's warm-up was a fixed tenth (6 of 60 samples). `GrowthRule` gains
    `judge(_:warmUp:)`, and teardown-reentry takes its first whole cycle (12 frames) as the warm-up. Growth now
    means a later cycle holding more than the first reached. Covered by `growthRuleWarmUpOfOneCycle`, the host and
    package tests on both runtimes, and the reference regression.
  - The fixture scenarios are validated and played on the engine by the host tests; the runner plays the nine
    standard scenarios (its `SCENARIOS`), as for every experience.
- **A02 core (T-U07-020, 2026-11-13).** The pure core and its manifest are a package like A01's
  (`Apps/FluidArtPlayground/FluidArtPlaygroundAdapter`, product `FluidArtPlaygroundAdapterCore`). `stroke` carries six values
  (position and velocity normalized to the view, phase, pointer) instead of the four of data-model section 2: the
  presenter keeps the app's `PointerVelocityTracker` and `PinchRecognizer`, so the core needs the tracker's velocity
  to make the same splat as `SplatQueue.add` (a host test compares the two). `pinch` and the slider `brush` both carry
  the brush radius. The completion scenario needs an outcome (`ScenarioManifestValidator`), so A02 reports
  `canvas-painted` once a splat reached the fields since the last reset (data-model corrected). The core's six
  differences from the standalone app are in its file header.
- **Adapter folder names (2026-11-13).** SwiftPM takes a local package's identity from its folder name, so two
  packages in folders named `Adapter` collided ("Missing package product 'FluidArtPlaygroundAdapterCore'"). The
  adapters live in `Apps/<App>/<App>Adapter/`, like the Core packages (`FluidArtPlaygroundCore`); the folders
  were renamed with `git mv` and every path in this feature's documents was updated.
- **A01 interface tests (T-U07-015, T-U07-016, 2026-11-13).** Ported by an agent; the lead ran and fixed them.
  - The accessibility audit flagged controls the controls' scroll view clips (their frames lie under the canvas).
    The shared `audit` takes a `visible` frame and ignores a contrast finding outside it; the ported audit passes
    the list's frame above the home indicator.
  - The session host's controls `ScrollView` hides the iOS 26 scroll-edge fade (`scrollEdgeEffectHidden`), as A01's
    standalone controls did, so controls at its edges keep full contrast.
  - The audit waits 0.8 s after each scroll, so that a decelerating list is not measured mid-move. Each audit test
    has a 420 s allowance and runs in its own chunk.
  - The time slider has its own full-width row. The rename alert and remove dialog use `presenting:`. The rename
    test taps once more when the keyboard took the first tap. A confirmation dismissed by tapping outside it taps
    the canvas, because from iOS 26 a phone shows a popover without Cancel.
  - Chunks: `g1` (audit), `g2` (controls, export, gallery), `g3` (library, recovery).
- **A01 move and retirement (T-U07-017, T-U07-018, 2026-11-13).**
  - A01 is in `Packages/ExperiencesCreative`, with these targets:
    - `GenerativeArtStudioCore` and its unchanged Core tests;
    - `GenerativeArtStudioExperience`: the app's scene and screen sources, the adapter under `Experience/Adapter`,
      and the shaders as resources from `Bundle.module`;
    - `GenerativeArtStudioExperienceTests`: the app's 40 unit tests, the adapter's 15 host tests and the 9
      session and parity tests.
  - The package is iOS-only, because the Experience target needs UIKit, so it is tested on both simulators. The one
    app links the product `GenerativeArtStudioExperience`.
  - Three moved unit tests read repository paths, which were updated in the move:
    - the Core fixture, now under `CoreTests/Fixtures`;
    - the standalone icon, kept as history in `docs/apps/generative-art-studio/history`;
    - the Photos add-only usage string, which the one app now declares for the share sheet's "Save Image"
      (`project.yml`).
  - The standalone targets and scheme are retired in the same change, because they compiled the moved files. The
    standalone UI tests are retired; `test-map.csv` and the checks `a01-test-map-r3` and `app-phone-ios27-g1..g3`
    prove each is ported. The asset catalog is retired. `PrivacyInfo.xcprivacy` stays for UA-F11 to merge.
  - The standalone screens (`GalleryView`, the `SceneScreen` view, `SettingsView`, `LibraryView`, `LibraryModel`,
    `ControlsSheet`, `ExportSheet`, `LaunchComposition`, `LaunchCleanup`) moved with the sources. The registry never
    reaches them; the moved unit tests use `SceneModel`, `ExportRunner` and `LibraryModel`. The storage rules
    therefore cover the code the experience runs: the adapter and its presenter, controls, library and factory.
    Retiring the unreachable screens, with their tests mapped, is a convergence item.
- **Photos add-only usage string (2026-11-13).** Saving an exported picture through the share sheet's "Save Image"
  needs `NSPhotoLibraryAddUsageDescription`; without it the save fails. The one app declares only that string, with
  A01's wording (FR-A01-407). `BundleTests` allows exactly that one usage description; the app never calls PhotoKit.
- **X gates after UA-F07 (T-U07-019, 2026-11-13).** In the migration ledger, X-A01, X-A02 and X-A03 depend on UA-F07,
  so they cannot pass before it (`migration_ledger.py show --gate X-A01`: "UNMET: UA-F07"). This feature runs their
  four checks with the commands of Auto-Creator.md 22.2 as UA-F07 checks before its seal. The X gates are recorded
  right after UA-F07, and A01's registration then moves to `all`. FR-U07-051, SC-U07-008 and T-U07-019 are
  corrected. The `host` check runs the package tests on a simulator, because the package's Experience targets need
  UIKit and `swift test` cannot build them.
- **A02 move and retirement (T-U07-022, 2026-11-13).**
  - A02 is in `Packages/ExperiencesCreative/FluidArtPlayground`, laid out like A01. A02 has no shader files (its
    GLSL is inline).
  - `TestMode.swift` and `AppAutomation.swift` moved with the sources. Both compile only under
    `DEBUG || VISUALCORE_AUTOMATION`, and the moved unit tests use them.
  - Four moved unit tests were adapted:
    - `CrashRecoveryTests` calls the capture cleanup that the retired `@main` init ran;
    - `CopyTests` checks A02's catalog summary in place of the retired home text, and resolves a store claim that
      names a retired interface test through `test-map.csv`;
    - `PrivacyTests` reads the one app's single Photos add-only string, and compares the defaults keys and the
      Documents and Library listings before and after the session, because a package test has no app container;
    - `IconRenderTests` reads the icon kept in `docs/apps/fluid-art-playground/history`.
  - With two products, the package's scheme is `ExperiencesCreative-Package`.
- **A03 adapter (T-U07-023, T-U07-024, 2026-11-13).**
  - The core keeps a `PlaneFraming` (centre and span across the shorter side), so its state does not depend on the
    view's size. `pan` and `pinch` carry distances in units of the view's shorter side. A host test and a session
    test show they give the standalone `PlaneViewport` and `ExplorerModel` results for several sizes.
  - The precision limit uses fixed constants (23 mantissa bits, 3 pixels per point, a 1,024-point side).
  - Tours replay the app's `TourTimeline` at the core's elapsed step time, and the palette animates by the core's
    time: neither uses `systemUptime`.
  - The completion scenario's outcome is `deep-zoom` (1,000×).
  - The presenter calls the app's `FractalScene.bind` and renders its inner scene with the core's palette time. There
    is no CPU fallback picture: a shader failure fails the session's setup.
  - The probe is the view's centre, declared only while a 9 × 9 grid around it lies inside the set by the CPU's
    `FractalMath`; the shader draws such points black.
  - `GoToTarget` has no public initializer, so the core applies its rule (span = default width ÷ zoom).
- **A04 replay bound and rebase (T-U07-026, 2026-11-13).** A short replay of 10 simulated seconds (1,200 steps) took
  0.85 s in a debug build on the host. The 10 s preparation limit therefore holds about 2 simulated minutes in
  debug builds. A release build took 0.026 s (about 64 simulated minutes within the limit on this Mac). The owner's
  rule of 2026-11-13 forbids long tests, so the bound comes from the cost per step, and device bounds are measured
  in the device campaign (T-U07-029).
  - A state that grows without limit would exceed any bound, so the core rebases every 10 simulated minutes
    (`maxReplaySteps` = 72,000). It keeps its configuration as an anchor (the scene with its emitters, the force,
    the settings), starts a fresh simulation from it with the next scene seed, and clears the log. A restore replays
    at most 10 simulated minutes. E-05 holds: a host test rebases and restores to the same digest.
  - The visible cost: particles (at most 8 s old) restart once in 10 minutes (adapter difference 6).
  - Debug and simulator builds still need about 45 s to replay a full 10-minute segment. The runner's scenarios are
    short, so they stay within the limit there.
- **A03 interface tests, move and retirement (T-U07-025, 2026-11-13).**
  - The ported audit found two real E-12 issues, fixed in the controls:
    - small red error text only nearly passed contrast; error lines in all three adapters now use the primary
      colour;
    - the go-to fields' placeholders clipped at the largest size; each field now has its name as a wrapping label
      above it and a short placeholder. A vertical field was tried first, but its Return key inserts a newline.
  - The audit was trimmed to seven stops, leaving out tours and the precision notice (same text styles), so that
    each audit runs in its own chunk well under the limit (owner rule: tests are short).
  - The move follows A02:
    - `FractalExplorerApp.cleanUpCaptures()` became `CaptureCleanup.run()` with the retired `@main` type;
    - `bookmark-v1.json` moved bit-identical to `ExperienceTests/Fixtures`, and `MigrationTests` reads it there;
    - `CopyTests` and `PrivacyTests` are adapted as for A02; the privacy test also checks the one app's export
      compliance key.
- **A04 adapter (T-U07-027, 2026-11-13).**
  - The presenter draws the core's particles through VisualCore's `ParticleLayerScene` over the app's world square.
    Its source only reads the core, and the drawn count is capped by the level's share. Taps and drags become
    `force.place` at the world point under the finger, found with `ParticleLayerScene.worldPoint`.
  - The probe is the top middle of the canvas while no particle (by the CPU's positions and sizes) covers it, and
    trails are off; it expects the black background.
  - Under Reduce Motion the controls pause the scene once, as the standalone app starts paused.
  - On the iOS 27.2 simulator (debug), a 10-second replay took 0.25 s, so the 10 s limit holds about 6.8 simulated
    minutes there. That is below the 10-minute rebase interval in a debug simulator build; release builds hold far
    more (0.026 s on the Mac). Device bounds come from the device campaign (T-U07-029). The rebase interval stays at
    10 minutes, and a shorter interval for debug builds is left to that measurement.
- **A04 move (T-U07-028, 2026-11-13).**
  - A04's Core, its tests with `Fixtures/replay-v1.json` (as package resources), its app sources and the adapter
    moved into `Packages/ExperiencesCreative/ParticleUniverse`.
  - The standalone `ParticleUniverse` target stays until X-A04 (FR-U07-043). Its `@main` file stays in
    `Apps/ParticleUniverse/App`; it compiles the moved sources from the package folder (without the adapter files)
    and takes `ParticleUniverseCore` from the package's product. Its UI tests stay with it until the retirement.
  - The path-map entries of the Core are done; the `App` and `Tests/UI` entries stay pending until X-A04.
- **A04 interface tests (T-U07-028, 2026-11-13).** Ported by an agent; the lead ran them.
  - The first run found a real issue: the Reduce Motion action (A04 pause, A01 half rate) ran once when the
    controls appeared, which can be before the experience is active, so it was refused and never retried. The
    controls now retry it for at most 5 s.
  - One test expected a step to raise the live count; at a steady state a step can lower it, so the test requires a
    change.
  - The standalone app's CPU preview, its quality controller hooks and its renderer texts have no counterpart; their
    rows name the covering tests.
- 2026-11-13, T-U07-032: `check_documented_api.py --sources Apps/VisualCore` failed on 12 names. Eight were the
  public types of `Packages/ExperiencesCreative`, which the script counted as VisualCore API; it now skips
  `Packages/Experiences*` as `check_public_api.py` does, with a script test. `Environment` (SwiftUI's
  `@Environment`, matching `EvidenceRecord.Environment`), `ScenarioStep`, `ScenarioExpectations` and
  `ScenarioRunner.RequestMaker`, used by the app since UA-F09, were not named in a package README; the VisualCore
  and VisualCoreRendering READMEs now have a section each for the verification scenarios and the runner.
- 2026-11-13, T-U07-043 (convergence): the standalone root screens were audited (read-only, every reference by whole
  word). A01's gallery, library and settings screens (`GalleryView.swift`, `LibraryView.swift`, `SettingsView.swift`,
  `LaunchComposition.swift`) had no test, no dossier citation and no use outside each other; they are removed.
  `PaletteSwatch` moved to `ControlsSheet.swift` and `AppAccessibility` to `SceneScreen.swift`, their remaining
  users. The package keeps its 274 test cases on iOS 27.2 and 26.5, the app builds, and A01's runner passes 9 of 9.
  The other screens stay, unreachable from the one app (the factories build only the presenter and the controls):
  - FR-U07-034 requires the app unit tests of A01 to A03 to keep running. They drive `SceneModel`, `ExportRunner`,
    `LibraryModel`, `PlaygroundModel`, `TestMode`, `ExplorerModel`, `TourPlayer` and `BookmarksView`'s helpers,
    and two presenters use constants declared beside the screens (`SceneModel.limiterGraph`,
    `PlaygroundModel.glowGraph`).
  - The dossier contracts that `check_app_contract.py` validates cite `SceneScreen`, `ExportSheet`,
    `PlaygroundView` and `ExplorerView`, and FR-U07-052 forbids changing the dossiers.
  - The sheets those screens present (`ControlsSheet`, `AdjustPanel`, `CaptureSheet`, `GoToView`, `ToursView`)
    cannot go without editing the cited screens.
  The standalone settings of A01 (`gas.a11y.*`) are read only by `SceneScreen`, which the one app never shows. The
  one app's presenters take Reduce Motion and Reduce Flashing from the shell (FR-U07-016).
- 2026-11-13, T-U07-037 and SC-U07-004: the interface evidence is the full set of chunks on the iOS 27.2 phone. The
  phone and tablet of both runtimes would be four passes of about 17 chunks each, several hours, mostly in the
  accessibility audits (7 scroll stops at 2 text sizes, each system audit 30–60 s). The other runtime is already
  covered by the verification runner (27 of 27 and 18 of 18 on iOS 26.5 and 27.2) and the package tests (274 test
  cases on both). The tablet and iOS 26.5 interface runs move to the milestone run before ImplementationLock-100.
  The owner asked on 2026-11-13 why the work moves slowly. This follows the owner's rule that tests are short and
  work keeps moving. A single-method chunk (`i1a`) passes its test but trips the enumeration guard, because the
  guard expects the whole class; the audit chunks run per class.
