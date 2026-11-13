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
commands up to `stepIndex`. A test measures the replay of 30 simulated minutes on both simulators.

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
