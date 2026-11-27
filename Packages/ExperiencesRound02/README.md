# ExperiencesRound02

The round-two game experiences of the one VisualCore app (R02-G01 … R02-G25; ADR-0009, Auto-Creator.md section 16).
Each game has a pure `<Name>Core` (rules, levels, solver; tested on the host with `swift test`) and, from its later
features, an `<Name>Experience` (adapter, scene, shaders, controls; tested on the simulator). The app links an
experience only at its integration gate X-<code>.

## Aurora Loom (R02-G01, `r02-g01.aurora-loom`, free)

`AuroraLoomCore` (feature 301, R02-G01-01) is the playable rule kernel: `AuroraLoomLevel` with `AuroraLoomRibbon` and
`AuroraLoomGate` (immutable, fingerprinted, JSON schema 1), the exact integer phase model `AuroraLoomHarmony` with
`AuroraLoomSteps` and `AuroraLoomMismatch`, the play state `AuroraLoomPlay` with `AuroraLoomStage`, `AuroraLoomEvent`,
`AuroraLoomMove`, `AuroraLoomControl` and append-only `AuroraLoomRecord`s, and `AuroraLoomRules` for the R02-F23 puzzle
contract. Refusals are `AuroraLoomError` with `r02-g01.*` codes. Rules: [docs/architecture/aurora-loom.md](../../docs/architecture/aurora-loom.md).

Feature 302 (R02-G01-02) adds the content pipeline: `AuroraLoomManifest` (the 100 planned levels), `AuroraLoomSolver`
(`AuroraLoomSolution`, `AuroraLoomSolveMethod`), `AuroraLoomDifficulty`, `AuroraLoomGenerator` (`AuroraLoomBandProfile`,
`AuroraLoomGenerated`, the pinned catalog digest) and `AuroraLoomWitness` (`AuroraLoomCounterexample`), whose 100 files
live in [docs/games/aurora-loom/levels/](../../docs/games/aurora-loom/levels/). After an intended rule change:

```bash
AURORA_LOOM_WRITE_WITNESSES=1 swift test --package-path Packages/ExperiencesRound02 --filter AuroraLoomCatalogTests
```

```bash
swift test --package-path Packages/ExperiencesRound02
```

Feature 303 (R02-G01-03) adds the experience: in the Core the adapter `AuroraLoomExperienceCore`, the immutable
`AuroraLoomSceneSnapshot` with `AuroraLoomPalette` and `AuroraLoomTier`, the geometry and CPU reference
`AuroraLoomSceneGeometry` and the GLSL sources `AuroraLoomShaders`; in the iOS-only target `AuroraLoomExperience` the
presenter, the GL scene and a minimal control panel. The Experience targets' rendering dependencies are conditional on
iOS and their sources sit in `#if os(iOS)`, so `swift test` still runs the Cores on the macOS host; the simulator tests:

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test
```

Feature 304 (R02-G01-04) adds the touch controls: `AuroraLoomHandles` (an anchor rail and a dial per ribbon, step ↔
position mappings, R02-F22 spatial handles), `AuroraLoomOrbit` with the orbit-aware camera, and the host-tested
`AuroraLoomGestureController` (one move per gesture, two-finger orbit, selection); the presenter routes canvas touches
through it and the scene draws the rails, dials and the selected ribbon's outline.

Feature 305 (R02-G01-05) adds teaching and progression: `AuroraLoomSolver.solve(_:from:)`, `AuroraLoomHints`
(`AuroraLoomHint` in three levels: ribbon, control, exact step; `AuroraLoomFailureExplanation`), and in
`AuroraLoomProgress.swift` the `AuroraLoomTutorialStep`, `AuroraLoomMode` (campaign, practice, daily) and
`AuroraLoomProgress` (open levels, best moves, stars, the clock-free daily level). The adapter writes snapshot schema 2
with a migration from schema 1; the panel shows the instruction, hints, the failure explanation with Undo and Retry, a
level picker and the three modes.

Feature 306 (R02-G01-06) adds polish and accessibility: `AuroraLoomFeedbackPlan` (announcements and haptics through the
shared feedback route), `AuroraLoomLights` (eased gate and win lights, slow fades under Reduce Flashing) and
`AuroraLoomSoundRecipe` in the Core; in the experience, `AuroraLoomSound` (the ambient loop), a scrolling Dynamic Type
panel with labels and values for every control and a Sound toggle.

Feature 307 (R02-G01-07) adds persistence and replay: each result keeps its winning trace and `verified`
(`AuroraLoomProgress.record(level:moves:shortest:trace:)`), `AuroraLoomReconciliation` drops restored results whose
traces do not replay, the adapter writes snapshot schema 3 (migrations 1 → 2 → 3) and offers `replay.start`,
`replay.step` and `replay.stop`; the panel shows Replay, Step and Stop and the presenter announces dropped results once.

Feature 308 (R02-G01-08) adds the regression net: `AuroraLoomGolden` (16 code-computed golden frame descriptions pinned
in `AuroraLoom/golden-frames.json`), the solver regression over all 100 levels, simulator golden-frame and memory
checks, and `python3 scripts/aurora_loom_regression.py` to run every part with one summary.

Feature 309 (R02-G01-09) integrates Aurora Loom into the one app on the simulator: `AuroraLoomSchemaExamples`
(schema-1 and schema-2 examples registered), panel identifiers, pending stepper steps with Apply and Clear, opening at
level 1, app unit tests, the interface chunk `i3` and the Release symbol check.

Feature 310 (R02-G01-10) prepares the device campaign without touching a device: `docs/apps/aurora-loom/device-rows.json`
and `device-campaign.md` (rows AL-D1 … AL-D8), checked by `python3 scripts/check_device_rows.py --experience
r02-g01.aurora-loom`.

## Lissajous Labyrinth (R02-G02, `r02-g02.lissajous-labyrinth`, free)

`LissajousLabyrinthCore` (feature 311, R02-G02-01) is the playable rule kernel: the integer `LissajousLabyrinthSine`,
`LissajousLabyrinthLevel` with `LissajousLabyrinthBall`, `LissajousLabyrinthDials` and `LissajousLabyrinthDial`
(immutable, fingerprinted, JSON schema 1), the exact lap `LissajousLabyrinthLap` with `LissajousLabyrinthPoint` and
`LissajousLabyrinthVerdict`, the play state `LissajousLabyrinthPlay` with `LissajousLabyrinthStage`,
`LissajousLabyrinthEvent`, `LissajousLabyrinthAction` and append-only `LissajousLabyrinthRecord`s, and
`LissajousLabyrinthRules` for the R02-F23 puzzle contract. Refusals are `LissajousLabyrinthError` with `r02-g02.*` codes.
Rules: [docs/architecture/lissajous-labyrinth.md](../../docs/architecture/lissajous-labyrinth.md).

Feature 312 (R02-G02-02) adds the content pipeline: `LissajousLabyrinthManifest` (the 100 planned levels),
`LissajousLabyrinthSolver` (every legal setting decided exactly, shortest path by breadth-first search),
`LissajousLabyrinthDifficulty`, `LissajousLabyrinthGenerator` (`LissajousLabyrinthBandProfile`, the pinned catalog
digest) and `LissajousLabyrinthWitness`, whose 100 files live in
[docs/games/lissajous-labyrinth/levels/](../../docs/games/lissajous-labyrinth/levels/). After an intended rule change:

```bash
LISSAJOUS_LABYRINTH_WRITE_WITNESSES=1 swift test --package-path Packages/ExperiencesRound02 --filter LissajousLabyrinthCatalogTests
```

Feature 313 (R02-G02-03) adds the experience: in the Core the adapter `LissajousLabyrinthExperienceCore`, the
immutable `LissajousLabyrinthSceneSnapshot` with `LissajousLabyrinthPalette` and `LissajousLabyrinthTier`, the geometry
and CPU reference `LissajousLabyrinthSceneGeometry`, the GLSL sources `LissajousLabyrinthShaders` and the scenarios; in
the iOS-only target `LissajousLabyrinthExperience` the presenter, the GL thread scene and a minimal control panel. It is
a registered candidate of the one app until X-R02-G02.

Feature 314 (R02-G02-04) adds the touch controls: in the Core the dial-independent stage and content spheres and the
camera orbit `LissajousLabyrinthOrbit` (`LissajousLabyrinthSceneGeometry`), the four dial rings
`LissajousLabyrinthHandles`, the host-tested `LissajousLabyrinthGestureController` (one action per turn, two-finger
orbit, selection) and the pending-value planner `LissajousLabyrinthPending`; in the experience the presenter's pointer
route, the drawn rings, knobs, selection outline and turn preview, and a panel whose steppers set pending values with
Apply, Clear and Reset view.

Feature 315 (R02-G02-05) adds teaching and progression: `LissajousLabyrinthSolver.solve(_:from:winning:)`,
`LissajousLabyrinthHints` with `LissajousLabyrinthFailureExplanation`, and `LissajousLabyrinthProgress` with
`LissajousLabyrinthMode` and `LissajousLabyrinthTutorialStep`; the adapter gains level selection, daily, practice and
campaign modes, the tutorial controls and snapshot schema 2; the panel shows the instruction, hints, the failure
explanation, the goal, the modes and a level picker.

Feature 316 (R02-G02-06) adds polish and accessibility: `LissajousLabyrinthFeedbackPlan` (announcements and haptics),
`LissajousLabyrinthLights` (eased fades, Reduce Flashing) and `LissajousLabyrinthSoundRecipe` in the Core, and
`LissajousLabyrinthSound` with a Sound toggle, labels, wrapping rows and a readable width in the experience.

Feature 317 (R02-G02-07) adds persistence and replay: results with winning traces and a `verified` flag,
`LissajousLabyrinthReconciliation` on restore, the `replay(level)` mode with `replay.start/step/stop`, and snapshot
schema 3 migrating from 1 and 2.

Feature 318 (R02-G02-08) adds the regression net: solver regression over the 100 levels, `LissajousLabyrinthGolden` with
the pinned `LissajousLabyrinth/golden-frames.json`, simulator golden-frame and memory tests, and
`python3 scripts/lissajous_labyrinth_regression.py`. After a reviewed visual change:

Feature 319 (R02-G02-09) integrates Lissajous Labyrinth into the one app on the simulator while it stays a candidate:
`LissajousLabyrinthSchemaExamples` (schema-1 and schema-2 examples registered), panel identifiers
`experience.r02-g02.lissajous-labyrinth.<name>`, app unit tests, the interface chunk `k3` (`LLPlayUITests`,
`LLReplayUITests`) and the Release symbol check.

Feature 320 (R02-G02-10) prepares the device campaign without touching a device:
`docs/apps/lissajous-labyrinth/device-rows.json` and `device-campaign.md` (rows LL-D1 … LL-D8), checked by `python3
scripts/check_device_rows.py --experience r02-g02.lissajous-labyrinth`.

```bash
LISSAJOUS_LABYRINTH_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 --filter LissajousLabyrinthRegressionGoldenTests
```

## Wave Knot Keeper (R02-G03, `r02-g03.wave-knot-keeper`, free)

`WaveKnotKeeperCore` (feature 321, R02-G03-01) is the playable rule kernel: `WaveKnotKeeperLevel` with
`WaveKnotKeeperPoint`, `WaveKnotKeeperGate` and `WaveKnotKeeperTarget` (immutable, fingerprinted, JSON schema 1), the
exact integer geometry `WaveKnotKeeperGeometry` (sweep test, xy-projection crossings and writhe, simplicity, tension)
with `WaveKnotKeeperSummary`, the play state `WaveKnotKeeperPlay` with `WaveKnotKeeperStage`, `WaveKnotKeeperEvent`,
`WaveKnotKeeperMove`, `WaveKnotKeeperDirection` and append-only `WaveKnotKeeperRecord`s, and `WaveKnotKeeperRules` for
the R02-F23 puzzle contract. Refusals are `WaveKnotKeeperError` with `r02-g03.*` codes. Rules:
[docs/architecture/wave-knot-keeper.md](../../docs/architecture/wave-knot-keeper.md).

Feature 322 (R02-G03-02) adds the content pipeline: `WaveKnotKeeperManifest` (100 planned levels), the seeded
`WaveKnotKeeperGenerator`, the breadth-first `WaveKnotKeeperSolver`, `WaveKnotKeeperDifficulty` and versioned witness
files (`WaveKnotKeeperWitness`) under `docs/games/wave-knot-keeper/levels/`, with a pinned catalog digest.

Feature 323 (R02-G03-03) adds the experience: the adapter `WaveKnotKeeperExperienceCore`, the immutable scene snapshot,
the glass-rope geometry and GLSL sources in the Core, and the iOS-only `WaveKnotKeeperExperience` target (presenter,
rope scene, minimal panel) registered as a candidate with a 94-scenario manifest.

Feature 324 (R02-G03-04) adds spatial play: `WaveKnotKeeperHandles` (picking, drag to one lattice step),
`WaveKnotKeeperGestureController` (drag, tap, two-finger orbit, reset) and the orbit camera; the panel gains "Reset
view".

Feature 325 (R02-G03-05) adds teaching and progression: `WaveKnotKeeperSolver.solve(_:from:depth:)`,
`WaveKnotKeeperHints` with `WaveKnotKeeperFailureExplanation`, and `WaveKnotKeeperProgress` with `WaveKnotKeeperMode`
and `WaveKnotKeeperTutorialStep`; the adapter gains level selection, daily, practice and campaign modes, the tutorial
controls and snapshot schema 2; the panel shows the instruction, hints, the failure explanation, the goal, the modes and
a level picker.

Feature 326 (R02-G03-06) adds polish and accessibility: `WaveKnotKeeperFeedbackPlan` (announcements and haptics),
`WaveKnotKeeperLights` (eased crossing, match and win levels; slow fades under Reduce Flashing), crossing weights from
the lights in `WaveKnotKeeperSceneGeometry`, `WaveKnotKeeperSoundRecipe` and the iOS `WaveKnotKeeperSound`; the panel
labels every control, shows refusals in words, wraps at large text sizes and adds a Sound toggle.

Feature 327 (R02-G03-07) adds persistence and replay: results carry their winning trace and `verified`
(`WaveKnotKeeperProgress`), `WaveKnotKeeperReconciliation` re-checks them on restore, the adapter writes snapshot schema
3 with a 2 → 3 migration and adds `replay.start/step/stop`; the panel offers Replay best solution with Step and Stop.

Feature 328 (R02-G03-08) adds the regression net: the solver regression over all 100 witnesses, `WaveKnotKeeperGolden`
(16 code-computed golden frames pinned in `WaveKnotKeeper/golden-frames.json`; regenerate on purpose with
`WAVE_KNOT_KEEPER_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 --filter
WaveKnotKeeperRegressionGoldenTests`), simulator golden-frame and memory tests, and
`scripts/wave_knot_keeper_regression.py`.

Feature 329 (R02-G03-09) integrates the game into the one app as a candidate: panel identifiers,
`WaveKnotKeeperSchemaExamples.swift` (stored schema-1 and schema-2 examples), interface tests in
`Apps/VisualCore/Tests/UI/WaveKnotKeeper` (chunk `l3`) and app unit tests.

Feature 330 (R02-G03-10) prepares the device campaign: `docs/apps/wave-knot-keeper/device-rows.json` (rows WK-D1 …
WK-D8, all pending) and `device-campaign.md`, checked by the release step `device-rows-r02-g03`.

## Hue Compass (R02-G04, `r02-g04.hue-compass`, free)

`HueCompassCore` (feature 331, R02-G04-01) is the playable rule kernel: the exact wheel `HueCompassWheel` (96 bearings,
24 hue bands, the integer sector rule, circular distances, arcs) with `HueCompassClue` and `HueCompassAction`,
`HueCompassLevel` (immutable, fingerprinted, JSON schema 1), the play state `HueCompassPlay` with `HueCompassStage`,
`HueCompassEvent`, `HueCompassFailure` and append-only `HueCompassRecord`s, and `HueCompassRules` for the R02-F23 puzzle
contract. Refusals are `HueCompassError` with `r02-g04.*` codes. Rules:
[docs/architecture/hue-compass.md](../../docs/architecture/hue-compass.md).

Feature 332 (R02-G04-02) adds the content pipeline: `HueCompassManifest` (100 planned levels), the seeded
`HueCompassGenerator` with `HueCompassBandProfile`, the deduction solver `HueCompassSolver` (smallest probe set, depth 2),
`HueCompassDifficulty` and versioned witness files (`HueCompassWitness`) under `docs/games/hue-compass/levels/`, with a
pinned catalog digest.

Feature 333 (R02-G04-03) adds the experience: the adapter `HueCompassExperienceCore`, the immutable scene snapshot,
the compass geometry and GLSL sources in the Core, and the iOS-only `HueCompassExperience` target (presenter, compass
scene, fallback, a minimal control panel); the experience is registered as a candidate with 94 scenarios.

Feature 334 (R02-G04-04) adds spatial play: `HueCompassOrbit`, `HueCompassDial` (projected centre, swipe angle, hub) and
the host-tested `HueCompassGestureController` (swipe to turn, tap the hub to probe, two-finger orbit, reset); the panel
gains "Reset view".

Feature 335 (R02-G04-05) adds teaching and progression: `HueCompassHints` with `HueCompassFailureExplanation`, and
`HueCompassProgress` with `HueCompassMode` and `HueCompassTutorialStep`; the adapter gains level selection, daily,
practice and campaign modes, the tutorial and snapshot schema 2.

Feature 336 (R02-G04-06) adds polish and accessibility: `HueCompassFeedbackPlan` (announcements, haptics, refusal
words, the summary text), `HueCompassLights` (eased marks and win glow, Reduce Flashing fades) and
`HueCompassSoundRecipe` in the Core (which now uses VisualCoreAudioDSP), and `HueCompassSound` with the presenter's
feedback route, the eased scene marks, a summary element, wrapping rows, a 520-point panel and a Sound toggle in the
experience.

Feature 337 (R02-G04-07) adds persistence and replay: results carry their winning trace and `verified`
(`HueCompassProgress`), `HueCompassReconciliation` replays them on restore, the mode gains `replay(level:)` and the
adapter writes snapshot schema 3 (migrating 1 → 2 → 3) with `replay.start/step/stop`; the panel offers Replay with Step
and Stop and announces dropped results once.

Feature 338 (R02-G04-08) adds the regression net: the solver regression over all 100 witnesses, `HueCompassGolden` (16
code-computed golden frames pinned in `HueCompass/golden-frames.json`; regenerate on purpose with
`HUE_COMPASS_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 --filter
HueCompassRegressionGoldenTests`), simulator golden-frame and memory tests, and `scripts/hue_compass_regression.py`.

Feature 339 (R02-G04-09) adds the in-app integration: panel identifiers (`HueCompassControls.identifierNames`), the
stored schema-1 and schema-2 examples (`HueCompassSchemaExamples`), app unit tests, and the interface tests
`HCPlayUITests` and `HCReplayUITests` in serial chunk `m3`.

Feature 340 (R02-G04-10) prepares the device campaign without touching a device: `docs/apps/hue-compass/device-rows.json`
(rows HC-D1 … HC-D8, pending) and `docs/apps/hue-compass/device-campaign.md`, checked by
`scripts/check_device_rows.py --experience r02-g04.hue-compass`.

## Colorfall Canyons (R02-G05, `r02-g05.colorfall-canyons`, free)

`ColorfallCanyonsCore` (feature 341, R02-G05-01) is the playable rule kernel: `ColorfallCanyonsLevel` with
`ColorfallCanyonsColor`, `ColorfallCanyonsGround`, `ColorfallCanyonsSpring` and `ColorfallCanyonsBasin` (immutable,
fingerprinted, JSON schema 1), the exact fluid state `ColorfallCanyonsFluid` (synchronous downhill routing, whole-unit
colour sharing, exact conservation) with `ColorfallCanyonsVerdict` and `ColorfallCanyonsFailure`, the play state
`ColorfallCanyonsPlay` with `ColorfallCanyonsAction`, `ColorfallCanyonsStage`, `ColorfallCanyonsEvent` and append-only
`ColorfallCanyonsRecord`s, and `ColorfallCanyonsRules` for the R02-F23 puzzle contract. Refusals are
`ColorfallCanyonsError` with `r02-g05.*` codes. Rules: [docs/architecture/colorfall-canyons.md](../../docs/architecture/colorfall-canyons.md).

Feature 342 (R02-G05-02) adds the content pipeline: `ColorfallCanyonsManifest` (100 planned levels), the seeded
`ColorfallCanyonsGenerator` with `ColorfallCanyonsBandProfile` and `ColorfallCanyonsGenerated`, the edit-set solver
`ColorfallCanyonsSolver` (`ColorfallCanyonsEdit`, `ColorfallCanyonsSolution`, depth 3), `ColorfallCanyonsDifficulty` and
versioned witness files (`ColorfallCanyonsWitness`, `ColorfallCanyonsCounterexample`) under
[docs/games/colorfall-canyons/levels/](../../docs/games/colorfall-canyons/levels/). After an intended rule change:

```bash
COLORFALL_CANYONS_WRITE_WITNESSES=1 swift test --package-path Packages/ExperiencesRound02 --filter ColorfallCanyonsCatalogTests
```

Feature 343 (R02-G05-03) adds the experience: in the Core the adapter `ColorfallCanyonsExperienceCore`, the immutable
`ColorfallCanyonsSceneSnapshot` with `ColorfallCanyonsPalette`, `ColorfallCanyonsPattern` and `ColorfallCanyonsTier`, the
geometry and CPU reference `ColorfallCanyonsSceneGeometry`, the GLSL sources `ColorfallCanyonsShaders` and the scenario
manifest `ColorfallCanyonsScenarios` (`scenario-manifest.json`; `UPDATE_SCENARIO_MANIFEST=1` rewrites it); the iOS-only
target `ColorfallCanyonsExperience` (presenter, GL canyon scene with fallback, control panel) and its simulator tests. A
registered candidate until X-R02-G05.

Feature 344 (R02-G05-04) adds touch controls: in the Core the constrained `ColorfallCanyonsOrbit` with
`ColorfallCanyonsSceneGeometry.camera(_:aspect:orbit:)`, the analytic `ColorfallCanyonsPicker` (`ColorfallCanyonsPick`),
the drag highlight ring `highlightPart(_:_:)` and `ColorfallCanyonsGestureController` (`ColorfallCanyonsGestureAction`:
drag to carve, tap a valve, two-finger orbit, double-tap reset); in the experience the presenter's pointer entry and
"Reset view". Host tests compare 500 seeded picks and 4,500 seeded gestures with independent computations and win all
100 levels through panel actions.

Feature 345 (R02-G05-05) adds teaching and progression: `ColorfallCanyonsSolver.plan(_:from:budget:)` (a smallest edit
set from the current fluid), `ColorfallCanyonsHints` with `ColorfallCanyonsHint` and
`ColorfallCanyonsFailureExplanation`, and `ColorfallCanyonsProgress` with `ColorfallCanyonsMode` and
`ColorfallCanyonsTutorialStep`; the adapter gains `level.select`, `mode.daily`, `mode.practice`, `mode.campaign` and
`tutorial.dismiss` with snapshot schema 2; the panel shows the tutorial, hints, failure text with Undo and Retry, modes
and a level picker.

Feature 346 (R02-G05-06) adds polish and accessibility: `ColorfallCanyonsFeedbackPlan` (announcements and haptics),
`ColorfallCanyonsLights` (eased sheet, emitter and win-glow levels with a flash-rate measure) and
`ColorfallCanyonsSoundRecipe` (an ambient loop from the basins) in the Core, `ColorfallCanyonsSound` and the panel's
labels, values, summary element, Sound toggle and accessibility-size layout in the experience.

Feature 347 (R02-G05-07) adds persistence and replay: results keep their winning trace and a verified flag,
`ColorfallCanyonsReconciliation` replays each trace on restore and drops what does not verify, the adapter writes
snapshot schema 3 (with the sound choice, not digested) with migrations from 1 and 2, and `replay.start`, `replay.step`
and `replay.stop` replay a stored solution.

Feature 348 (R02-G05-08) adds the regression net: solver and witness checks for all 100 levels with twelve named
alterations, `ColorfallCanyonsGolden` (test builds only) with 16 pinned golden frame descriptions in
`ColorfallCanyons/golden-frames.json` (`COLORFALL_CANYONS_WRITE_GOLDEN=1` rewrites them), simulator golden-frame and
memory tests, a CI step and `scripts/colorfall_canyons_regression.py`.

Feature 349 (R02-G05-09) adds Colorfall Canyons's in-app integration: panel identifiers
(`ColorfallCanyonsControls.identifierNames`), the stored schema-1 and schema-2 examples
(`ColorfallCanyonsSchemaExamples`), app unit tests, and the interface tests `CCPlayUITests` and `CCReplayUITests` in
serial chunk `n3`.

Feature 350 (R02-G05-10) prepares the device campaign without touching a device:
`docs/apps/colorfall-canyons/device-rows.json` (rows CC-D1 … CC-D8, pending) and
`docs/apps/colorfall-canyons/device-campaign.md`, checked by `scripts/check_device_rows.py --experience
r02-g05.colorfall-canyons`.

## Chrono Constellator (R02-G06, `r02-g06.chrono-constellator`, free)

`ChronoConstellatorCore` (feature 351, R02-G06-01) is the playable rule kernel: `ChronoConstellatorLevel` with
`ChronoConstellatorStar` and `ChronoConstellatorShape` (immutable, fingerprinted, JSON schema 1), the timeline
`ChronoConstellatorTimeline` with `ChronoConstellatorHold` (closed-form star positions at any tick, edits in use, a
fingerprint as the signed snapshot), `ChronoConstellatorEvaluation` with `ChronoConstellatorVerdict` and
`ChronoConstellatorFailure`, the play state `ChronoConstellatorPlay` with `ChronoConstellatorAction`,
`ChronoConstellatorStage`, `ChronoConstellatorEvent` and append-only `ChronoConstellatorRecord`s, and
`ChronoConstellatorRules` for the R02-F23 puzzle contract. Refusals are `ChronoConstellatorError` with `r02-g06.*`
codes. Rules: [docs/architecture/chrono-constellator.md](../../docs/architecture/chrono-constellator.md).

Feature 352 (R02-G06-02) adds Chrono Constellator's content pipeline: `ChronoConstellatorManifest` (100 levels),
`ChronoConstellatorGenerator` with `ChronoConstellatorBandProfile`, the integer-tick phase search
`ChronoConstellatorSolver` with its lower-bound proof, `ChronoConstellatorDifficulty`, and `ChronoConstellatorWitness`
files in `docs/games/chrono-constellator/levels/` (rewritten only with `CHRONO_CONSTELLATOR_WRITE_WITNESSES=1`).

Feature 353 (R02-G06-03) adds the experience: in the Core the adapter `ChronoConstellatorExperienceCore`, the immutable
`ChronoConstellatorSceneSnapshot` with `ChronoConstellatorPalette` and `ChronoConstellatorTier`, the geometry and CPU
reference `ChronoConstellatorSceneGeometry`, the GLSL sources `ChronoConstellatorShaders` and the scenario manifest
`ChronoConstellatorScenarios` (`scenario-manifest.json`; `UPDATE_SCENARIO_MANIFEST=1` rewrites it); the iOS-only target
`ChronoConstellatorExperience` (presenter, GL sky scene with fallback, control panel) and its simulator tests. A
registered candidate until X-R02-G06.

Feature 354 (R02-G06-04) adds touch controls: in the Core the constrained `ChronoConstellatorOrbit` with
`ChronoConstellatorSceneGeometry.camera(_:aspect:orbit:)` and `candidatePart(_:_:)`, the analytic `ChronoConstellatorPicker`
(`ChronoConstellatorPick`) and `ChronoConstellatorGestureController` (`ChronoConstellatorGestureAction`: star drags,
timeline scrubs, hold presses, star taps, orbit, double-tap reset); in the experience the presenter's pointer entry, the
candidate ring and "Reset view"; host tests with an independent pick, all 100 levels won through the panel, and
simulator wiring tests.

Feature 355 (R02-G06-05) adds teaching and progression: `ChronoConstellatorHints` (`ChronoConstellatorPlan`,
`ChronoConstellatorHint`, `ChronoConstellatorFailureExplanation`), `ChronoConstellatorProgress` with
`ChronoConstellatorMode` and `ChronoConstellatorTutorialStep`; the adapter's level, mode and tutorial controls and
snapshot schema 2 with a migration from 1; the panel's instruction, hints, failure text with Undo, Rewind and Retry,
modes and level picker.

Feature 356 (R02-G06-06) adds polish and accessibility: in the Core `ChronoConstellatorFeedbackPlan` (announcements and
haptics), `ChronoConstellatorLights` (eased fades, slower under Reduce Flashing) and `ChronoConstellatorSoundRecipe`
(a synthesized ambient loop); in the experience `ChronoConstellatorSound`, the feedback route, the lights in the scene
and an accessible panel (labels, values, summary, Sound toggle, large-text layout).

Feature 357 (R02-G06-07) adds persistence and replay: results with winning traces and `ChronoConstellatorReconciliation`
(replay-verified scores on restore), snapshot schema 3 with the 2 → 3 migration, the replay mode (`replay.start`,
`replay.step`, `replay.stop`) and the saved sound choice (`settings.sound`); the panel's Replay, Step and Stop.

Feature 358 (R02-G06-08) adds the regression net: solver and witness checks for all 100 levels with twelve named
alterations, `ChronoConstellatorGolden` (test builds only) with 16 pinned golden frame descriptions in
`ChronoConstellator/golden-frames.json` (`CHRONO_CONSTELLATOR_WRITE_GOLDEN=1` rewrites them), simulator golden-frame and
memory tests, a CI step and `scripts/chrono_constellator_regression.py`.

Feature 359 (R02-G06-09) adds Chrono Constellator's in-app integration: panel identifiers
(`ChronoConstellatorControls.identifierNames`), the stored schema-1 and schema-2 examples
(`ChronoConstellatorSchemaExamples`), app unit tests, and the interface tests `CRPlayUITests` and `CRReplayUITests` in
serial chunk `o3`.

Feature 360 (R02-G06-10) prepares the device campaign without touching a device:
`docs/apps/chrono-constellator/device-rows.json` (rows CR-D1 … CR-D8, pending) and
`docs/apps/chrono-constellator/device-campaign.md`, checked by `scripts/check_device_rows.py --experience
r02-g06.chrono-constellator`.

## Amethyst Escape (R02-G07, `r02-g07.amethyst-escape`, free)

`AmethystEscapeCore` (feature 361, R02-G07-01) is the playable rule kernel: `AmethystEscapeLevel` with
`AmethystEscapeShell` (immutable, fingerprinted, JSON schema 1), the crystal state `AmethystEscapeCrystal` with
`AmethystEscapePocket` and `AmethystEscapeTransition` (shell offsets, the pearl's pocket, exact rotation and the one
transition of an advance), the play state `AmethystEscapePlay` with `AmethystEscapeAction`, `AmethystEscapeStage`,
`AmethystEscapeEvent`, `AmethystEscapeFailure` and append-only `AmethystEscapeRecord`s, and `AmethystEscapeRules` for
the R02-F23 puzzle contract. Refusals are `AmethystEscapeError` with `r02-g07.*` codes. Rules:
[docs/architecture/amethyst-escape.md](../../docs/architecture/amethyst-escape.md).

Feature 362 (R02-G07-02) adds the content pipeline: `AmethystEscapeManifest` (100 levels), the seeded
`AmethystEscapeGenerator` with `AmethystEscapeBandProfile` and `AmethystEscapeGenerated`, the breadth-first
`AmethystEscapeSolver` (`AmethystEscapeSolution`), `AmethystEscapeDifficulty` and versioned witness files
(`AmethystEscapeWitness`, `AmethystEscapeCounterexample`) under `docs/games/amethyst-escape/levels/`; regenerate them on
purpose with:

```bash
AMETHYST_ESCAPE_WRITE_WITNESSES=1 swift test --package-path Packages/ExperiencesRound02 --filter AmethystEscapeCatalogTests
```

Feature 363 (R02-G07-03) adds the experience: in the Core the adapter `AmethystEscapeExperienceCore`, the immutable
`AmethystEscapeSceneSnapshot` with `AmethystEscapePalette` and `AmethystEscapeTier`, the geometry and CPU reference
`AmethystEscapeSceneGeometry` (wedges emitted back to front, `AmethystEscapeColouredMesh` parts for the fallback), the
GLSL sources `AmethystEscapeShaders` and the scenario manifest `AmethystEscapeScenarios` (`scenario-manifest.json`;
`UPDATE_SCENARIO_MANIFEST=1` rewrites it); the iOS-only target `AmethystEscapeExperience` (presenter, GL crystal scene
with fallback, control panel) and its simulator tests. A registered candidate until X-R02-G07.

Feature 364 (R02-G07-04) adds touch controls: in the Core the constrained `AmethystEscapeOrbit` with
`AmethystEscapeSceneGeometry.camera(_:aspect:orbit:)` and the isolation shade (`crystalMesh(_:tier:isolated:)`), the
analytic `AmethystEscapePicker` (`AmethystEscapePick`), the drag preview `AmethystEscapeSceneSnapshot.previewing(shell:sectors:)`
and `AmethystEscapeGestureController` (`AmethystEscapeGestureAction`: shell drags, pearl taps, shell picks, double-tap
isolation and view reset, orbit); in the experience the presenter's pointer entry, the preview and "Show all layers" and
"Reset view"; host tests with an independent pick and angle, all 100 levels won through the panel, and simulator wiring
tests.

Feature 365 (R02-G07-05) adds teaching and progression: the solver's search from any crystal
(`AmethystEscapeSolver.solve(_:from:maxDepth:)`), `AmethystEscapeHints` (`AmethystEscapePlan`, `AmethystEscapeHint`) and
`AmethystEscapeFailureExplanation`, `AmethystEscapeProgress` with `AmethystEscapeMode` and `AmethystEscapeTutorialStep`;
the adapter gains `level.select`, `mode.daily`, `mode.practice`, `mode.campaign` and `tutorial.dismiss` and snapshot
schema 2 with a migration from 1; the panel shows the tutorial, hints, failure text, goal, stars and modes.

Feature 366 (R02-G07-06) adds polish and accessibility: `AmethystEscapeFeedbackPlan` (announcements and haptics through
the shared `ExperienceFeedback`), `AmethystEscapeLights` (eased glows and amber under Reduce Flashing) and
`AmethystEscapeSoundRecipe` in the Core; the geometry draws the eased levels; the experience gains `AmethystEscapeSound`
(the ambient loop), a feedback log, an adjustable shell picker, a summary element, a Sound toggle and Dynamic Type layout.

Feature 367 (R02-G07-07) adds persistence and replay: results carry their winning trace and `verified`;
`AmethystEscapeReconciliation` replays every trace on restore and drops results that do not verify; the adapter writes
snapshot schema 3 with a 2 → 3 migration, adds `replay.start`, `replay.step`, `replay.stop` and `settings.sound`; the
panel gains Replay, Step and Stop and announces dropped results once.

Feature 368 (R02-G07-08) adds the regression net: solver and witness checks for all 100 levels with twelve named
alterations, `AmethystEscapeGolden` (test builds only) with 16 pinned golden frame descriptions in
`AmethystEscape/golden-frames.json` (`AMETHYST_ESCAPE_WRITE_GOLDEN=1` rewrites them), simulator golden-frame and memory
tests, a CI step and `scripts/amethyst_escape_regression.py`.

Feature 369 (R02-G07-09) adds Amethyst Escape's in-app integration: panel identifiers
(`AmethystEscapeControls.identifierNames`), the stored schema-1 and schema-2 examples (`AmethystEscapeSchemaExamples`),
app unit tests, and the interface tests `AEPlayUITests` and `AEReplayUITests` in serial chunk `p3`.

Feature 370 (R02-G07-10) prepares Amethyst Escape's device campaign without touching a device:
`docs/apps/amethyst-escape/device-rows.json` (rows AE-D1 … AE-D8, all pending), the written plan
`docs/apps/amethyst-escape/device-campaign.md`, and the release step `device-rows-r02-g07`.

## Faceted Forge (R02-G08, `r02-g08.faceted-forge`, free)

`FacetedForgeCore` (feature 371, R02-G08-01) is the playable rule kernel: exact fractions (`FacetedForgeFraction`), the
13 named plane directions and half-spaces, convex pieces with exact corners, ordered faces, edges and volume
(`FacetedForgePiece`), `FacetedForgeLevel` with `FacetedForgeTargetPiece` (immutable, fingerprinted, JSON schema 1), the
play state `FacetedForgePlay` with `FacetedForgeAction`, `FacetedForgeStage`, `FacetedForgeEvent`, `FacetedForgeFailure`
and append-only `FacetedForgeRecord`s, and `FacetedForgeRules` for the R02-F23 puzzle contract. Refusals are
`FacetedForgeError` with `r02-g08.*` codes. Rules:
[docs/architecture/faceted-forge.md](../../docs/architecture/faceted-forge.md).

Feature 372 (R02-G08-02) adds the content pipeline: `FacetedForgeManifest` (100 planned levels), the band profiles and
seeded `FacetedForgeGenerator`, `FacetedForgeSolver` (a winning sequence of exactly target pieces − 1 cuts, the lower
bound, found with partition pruning and counted work), `FacetedForgeDifficulty`, `FacetedForgeWitness` with the 100
witness files in `docs/games/faceted-forge/levels/` and the pinned catalog digest.

Feature 373 (R02-G08-03) adds the experience: in the Core the adapter `FacetedForgeExperienceCore` (levels certified
directly from their witnesses' candidate indices, the generator as fallback), the immutable `FacetedForgeSceneSnapshot`
with `FacetedForgePalette`, `FacetedForgeTier` and the preview choice `FacetedForgePreviewChoice`, the geometry and CPU
reference `FacetedForgeSceneGeometry` (pieces emitted back to front, `FacetedForgeColouredMesh` parts for the fallback),
the GLSL sources `FacetedForgeShaders` and the scenario manifest `FacetedForgeScenarios` (`scenario-manifest.json`;
`UPDATE_SCENARIO_MANIFEST=1` rewrites it); the iOS-only target `FacetedForgeExperience` (presenter, GL crystal scene
with fallback, control panel) and its simulator tests. A registered candidate until X-R02-G08.

Feature 374 (R02-G08-04) adds the gestures: `FacetedForgeOrbit` and `camera(_:aspect:orbit:)` (framing sphere 1.65,
meshes emitted back to front for the orbit's eye), the analytic `FacetedForgePicker` (rim, plane, pieces, tilt, depth
steps) and `FacetedForgeGestureController` (choose, tilt, slide, commit, orbit, reset) in the Core; the presenter's
pointer entry, the candidate preview and "Reset view" in the experience; the plane faces the camera by default.

Feature 375 (R02-G08-05) adds teaching and progression: `FacetedForgeHints` (plans from any state by the solver's new
`solve(_:from:cutsLeft:workBound:)`, three hint levels, failure explanations), `FacetedForgeProgress` with
`FacetedForgeTutorialStep` and `FacetedForgeMode` (stars by cuts made, daily × 67, practice budget 20), the adapter's
progression controls and snapshot schema 2, and the panel's Hint, tutorial, failure, mode and level rows.

Feature 376 (R02-G08-06) adds polish and accessibility: `FacetedForgeFeedbackPlan` (announcements, haptics, refusal
words, the summary element), `FacetedForgeLights` (eased glow and sliver levels), `FacetedForgeSoundRecipe` and the
experience's `FacetedForgeSound` loop, adjustable pickers and Dynamic Type layout in the panel.

Feature 377 (R02-G08-07) adds persistence and replay: results carry their winning trace (the effective cuts) and
`verified`; `FacetedForgeReconciliation` replays every trace on restore and drops results that do not verify; the
adapter writes snapshot schema 3 with a 2 → 3 migration, adds `replay.start`, `replay.step`, `replay.stop` and
`settings.sound`; the panel gains Replay, Step and Stop and announces dropped results once.

Feature 378 (R02-G08-08) adds the regression net: solver and witness checks for all 100 levels with ten named
alterations, `FacetedForgeGolden` (test builds only) with 16 pinned golden frame descriptions in
`FacetedForge/golden-frames.json` (`FACETED_FORGE_WRITE_GOLDEN=1` rewrites them), simulator golden-frame and memory
tests, a CI step and `scripts/faceted_forge_regression.py`.

Feature 379 (R02-G08-09) adds Faceted Forge's in-app integration: panel identifiers
(`FacetedForgeControls.identifierNames`), the stored schema-1 and schema-2 examples (`FacetedForgeSchemaExamples`), app
unit tests, and the interface tests `FFPlayUITests` and `FFReplayUITests` in serial chunk `q3`.

Feature 380 (R02-G08-10) prepares Faceted Forge's device campaign without touching a device:
`docs/apps/faceted-forge/device-rows.json` (rows FF-D1 … FF-D8, all pending), the written plan
`docs/apps/faceted-forge/device-campaign.md`, and the release step `device-rows-r02-g08`.

## Nocturne Garden (R02-G09, `r02-g09.nocturne-garden`, free)

`NocturneGardenCore` (feature 381, R02-G09-01) is the playable rule kernel: the six named bloom kinds as fixed lattice
outlines (`NocturneGardenKind`), blooms with a kind, anchor cell and size whose shadows are stretched by the sun and
turned into bed cells by an exact integer test (`NocturneGardenBloom`), the shadow mask with its match, leak and boundary
deviation (`NocturneGardenMask`, `NocturneGardenRatio`), `NocturneGardenLevel` (immutable, fingerprinted, JSON schema
1), the play state `NocturneGardenPlay` with `NocturneGardenAction`, `NocturneGardenStage`, `NocturneGardenEvent`,
`NocturneGardenFailure` and append-only `NocturneGardenRecord`s, and `NocturneGardenRules` for the R02-F23 puzzle
contract. Refusals are `NocturneGardenError` with `r02-g09.*` codes. Rules:
[docs/architecture/nocturne-garden.md](../../docs/architecture/nocturne-garden.md).

Feature 382 (R02-G09-02) adds the content pipeline: `NocturneGardenManifest` (100 planned levels), the band profiles and
seeded `NocturneGardenGenerator`, `NocturneGardenSolver` (a winning sequence of exactly the lower bound of moves: a sun
move when needed plus ⌈needed cells / single-plant cover⌉ plants, found with coverage pruning and counted work),
`NocturneGardenDifficulty`, `NocturneGardenWitness` with the 100 witness files in `docs/games/nocturne-garden/levels/`
and the pinned catalog digest.

Feature 383 (R02-G09-03) adds the experience: `NocturneGardenExperienceCore` (the adapter, certifying each level from
its recorded candidate), `NocturneGardenSceneSnapshot`, `NocturneGardenSceneGeometry` (the upright mist bed, the
kernel's exact shadow cells, the target rim, the forbidden hatch, the grown blooms, the lantern and the gauge, with the
camera and the CPU projection reference), `NocturneGardenShaders` and the scenario manifest in the Core, and the
iOS-only `NocturneGardenExperience` target (presenter, garden scene, controls); the experience is a registered
candidate until X-R02-G09.

Feature 384 (R02-G09-04) adds the gestures: `NocturneGardenOrbit`, `NocturneGardenPicker` (lantern, blooms, bed cell),
`NocturneGardenDragPreview` (the exact would-be shadow of a dragged bloom) and `NocturneGardenGestureController` (tap
to plant, drag to move or remove, pinch to resize, lantern drag for the sun, two-finger orbit, double tap to reset) in
the Core, the presenter's pointer entry, the preview outline (material 12) and "Reset view" and "Set sun" in the panel.

Feature 385 (R02-G09-05) adds teaching and progression: a solver entry point from the current state,
`NocturneGardenHints` (three hint levels and the failure explanation), `NocturneGardenProgress` (tutorial steps, stars,
the frontier, the daily level and the modes), the adapter's level and mode controls with snapshot schema 2, and the
panel's tutorial, Hint, Undo/Retry, mode buttons and level picker.

Feature 386 (R02-G09-06) adds polish and accessibility: `NocturneGardenFeedbackPlan` (announcements and haptics),
`NocturneGardenLights` (eased glow and leak crosses, Reduce Flashing) and `NocturneGardenSoundRecipe` in the Core (the
Core gains VisualCoreAudioDSP), `NocturneGardenSound` (the ambient loop over VisualCoreAudio) in the experience, the
presenter's feedback route and log, and the accessible panel (adjustable pickers, summary element, Sound toggle).

Feature 387 (R02-G09-07) adds persistence and replay: results carry their winning trace and `verified`
(`NocturneGardenReconciliation` replays every trace on restore and drops edited results), snapshot schema 3 with a
2 → 3 migration, the replay mode (`replay.start/step/stop`) and `settings.sound`, and the panel's Replay, Step and Stop.

Feature 388 (R02-G09-08) adds the regression net: solver and witness checks for all 100 levels with ten named
alterations, `NocturneGardenGolden` (test builds only) with 16 pinned golden frame descriptions in
`NocturneGarden/golden-frames.json` (`NOCTURNE_GARDEN_WRITE_GOLDEN=1` rewrites them), simulator golden-frame and memory
tests, a CI step and `scripts/nocturne_garden_regression.py`.

Feature 389 (R02-G09-09) adds the in-app integration: identifiers on every panel control, the schema-1 and schema-2
examples (`NocturneGardenSchemaExamples`) stored by the app registration, app unit tests, and the interface tests
`NGPlayUITests` and `NGReplayUITests` (serial chunk `r3`).

Feature 390 (R02-G09-10) prepares Nocturne Garden's device campaign without touching a device:
`docs/apps/nocturne-garden/device-rows.json` (rows NG-D1 … NG-D8, all pending), the written plan
`docs/apps/nocturne-garden/device-campaign.md`, and the release step `device-rows-r02-g09`.

## Backwards Aurora (R02-G10, `r02-g10.backwards-aurora`, free)

`BackwardsAuroraCore` (feature 391, R02-G10-01) is the playable rule kernel: the wave of signed integer samples with
its bends, seam positions, reversals, palindrome test and distance (`BackwardsAuroraWave`), `BackwardsAuroraLevel`
(immutable, fingerprinted, JSON schema 1), the play state `BackwardsAuroraPlay` with `BackwardsAuroraAction`,
`BackwardsAuroraStage`, `BackwardsAuroraEvent`, `BackwardsAuroraFailure` and append-only `BackwardsAuroraRecord`s, and
`BackwardsAuroraRules` for the R02-F23 puzzle contract. Refusals are `BackwardsAuroraError` with `r02-g10.*` codes.
Rules: [docs/architecture/backwards-aurora.md](../../docs/architecture/backwards-aurora.md).

Feature 392 (R02-G10-02) adds the content pipeline: the 100-entry `BackwardsAuroraManifest`, band profiles and the
seeded `BackwardsAuroraGenerator` (k separated reversals of a smooth target whose seams all break the bend limit), the
seam-count bound and iterative-deepening `BackwardsAuroraSolver`, `BackwardsAuroraDifficulty`, and
`BackwardsAuroraWitness` files in `docs/games/backwards-aurora/levels/` checked byte for byte with a pinned catalog
digest.

Feature 393 (R02-G10-03) adds the hero renderer and the experience: `BackwardsAuroraSceneSnapshot` (palette, tiers),
`BackwardsAuroraSceneGeometry` (the ribbon through the kernel's exact samples, trailing layers, ghost trail, checkpoint
rings, kink and tear crosses, section band, reversal gauge, fixed fitted camera and CPU projection reference),
`BackwardsAuroraShaders` (GLSL ES 3.00 shimmer and direction-coded pulses; glow), the adapter
`BackwardsAuroraExperienceCore` with its scenario manifest, and the iOS target `BackwardsAuroraExperience` (presenter,
scene, minimal controls), registered in the one app as a candidate until X-R02-G10.

Feature 394 (R02-G10-04) adds the gestures: `BackwardsAuroraOrbit` and `camera(_:aspect:orbit:)`, the analytic
`BackwardsAuroraPicker` (section ends, band and sample columns on the timeline plane), `BackwardsAuroraFreezePreview`
(the kernel's reversal of the chosen section with its bends and tear, drawn as a dashed ribbon) and
`BackwardsAuroraGestureController` (tap ends, drag ends, swipe to reverse, hold to freeze, two-finger orbit, double-tap
reset), wired through the presenter's pointer entry, with "Reset view" in the panel.

Feature 395 (R02-G10-05) adds teaching and progression: a solver entry point from the current wave,
`BackwardsAuroraHints` (three hint levels and the failure explanation), `BackwardsAuroraProgress` (tutorial steps,
stars, the frontier, the daily level and the modes), the adapter's level and mode controls with snapshot schema 2, and
the panel's tutorial, Hint, goal with band and stars, Undo/Retry, mode buttons and level picker.

Feature 396 (R02-G10-06) adds polish and accessibility: `BackwardsAuroraFeedbackPlan` (announcements and haptics),
`BackwardsAuroraLights` (eased glow, won lift, tear cross and preview, with `u_tearLight` and `u_previewLight` in the
aurora shader), `BackwardsAuroraSoundRecipe` and the experience's `BackwardsAuroraSound`, and the panel's values in
words, adjustable ends, summary element, Sound toggle and Dynamic Type layout.

Feature 397 (R02-G10-07) adds persistence and replay: results with winning traces and `BackwardsAuroraReconciliation`
(replay-verified scores on restore), snapshot schema 3 with migrations from schemas 1 and 2, the replay mode
(`replay.start`, `replay.step`, `replay.stop`) and the saved sound setting, with the panel's replay controls.

Feature 398 (R02-G10-08) adds the regression net: the solver regression over the 100 witnesses, `BackwardsAuroraGolden`
with the pinned `golden-frames.json` (16 code-computed frame descriptions), the simulator golden-frame and memory
classes, `scripts/backwards_aurora_regression.py` and the CI step "Backwards Aurora regression (host)".

Feature 399 (R02-G10-09) adds the in-app integration: identifiers on every panel control, the schema-1 and schema-2
examples (`BackwardsAuroraSchemaExamples`) stored by the app registration, app unit tests, and the interface tests
`BAPlayUITests` and `BAReplayUITests` (serial chunk `s3`).

Feature 400 (R02-G10-10) prepares Backwards Aurora's device campaign without touching a device:
`docs/apps/backwards-aurora/device-rows.json` (rows BA-D1 … BA-D8, all pending), the written plan
`docs/apps/backwards-aurora/device-campaign.md`, and the release step `device-rows-r02-g10`.

## Echo Cartographer (R02-G11, `r02-g11.echo-cartographer`, free)

`EchoCartographerCore` (feature 401, R02-G11-01) is the playable rule kernel: the grid chamber with its rays,
breadth-first path lengths and pulse reports (`EchoCartographerChamber`, `EchoCartographerRay`, `EchoCartographerEcho`),
the player's knowledge of each cell (`EchoCartographerKnowledge`), `EchoCartographerLevel` (immutable, fingerprinted,
JSON schema 1, with the claim rule), the play state `EchoCartographerPlay` with `EchoCartographerAction`,
`EchoCartographerStage`, `EchoCartographerEvent`, `EchoCartographerFailure` and append-only `EchoCartographerRecord`s,
and `EchoCartographerRules` for the R02-F23 puzzle contract. Refusals are `EchoCartographerError` with `r02-g11.*`
codes. Rules: [docs/architecture/echo-cartographer.md](../../docs/architecture/echo-cartographer.md).

Feature 402 (R02-G11-02) adds the content pipeline: the 100-entry `EchoCartographerManifest`, band profiles and the
seeded `EchoCartographerGenerator`, `EchoCartographerSolver` (fitting beacon placements counted by a pruned enumeration;
a greedy pulse plan until exactly one placement fits), `EchoCartographerDifficulty`, `EchoCartographerWitness` and the
100 witness files in `docs/games/echo-cartographer/levels/`, with the pinned catalog digest.

Feature 403 (R02-G11-03) adds the hero renderer and the experience: `EchoCartographerSceneSnapshot` (palette, tiers;
only what the player knows), `EchoCartographerSceneGeometry` (chamber meshes, camera, CPU reference),
`EchoCartographerShaders` (chamber and glow programs with signed-distance shading and the pulse, echo rings and wall
flares), the adapter `EchoCartographerExperienceCore`, the scenario manifest, and the iOS target
`EchoCartographerExperience` (presenter, chamber scene, control panel), registered as a candidate.

Feature 404 (R02-G11-04) adds the gestures: `EchoCartographerOrbit` and the orbiting camera, the analytic
`EchoCartographerPicker` (floor-plane ray, 22-point marker targets) and the host-tested
`EchoCartographerGestureController` (tap to pulse or move the cursor, drag to place or move markers, hold to claim,
double tap to reset, two-finger orbit), wired through the presenter's pointer entry with a "Reset view" button.

Feature 405 (R02-G11-05) adds teaching and progression: `EchoCartographerHints` (three hint levels from the solver's
greedy continuation, `EchoCartographerSolver.continuation`), `EchoCartographerFailureExplanation`,
`EchoCartographerProgress` (tutorial steps, stars by energy spent, unlocks, the daily level × 79, campaign, practice
and daily modes), the adapter's progression controls with snapshot schema 2, and the panel's tutorial, hints, failure
text, goal, stars and level picker.

Feature 406 (R02-G11-06) adds polish and accessibility: `EchoCartographerFeedbackPlan` (announcements and haptics),
`EchoCartographerLights` (eased glow and won brightening; rings and flares at rest under Reduce Flashing),
`EchoCartographerSoundRecipe` with the experience's `EchoCartographerSound` loop, and the panel's labels, values,
adjustable column and row, summary element, Sound toggle and Dynamic Type layout.

Feature 407 (R02-G11-07) adds persistence and replay: results carry their winning traces
(`EchoCartographerReconciliation` replays them on restore and drops what does not verify), snapshot schema 3 with
migrations from 1 and 2, the replay mode (`replay.start`, `replay.step`, `replay.stop`) and the saved sound choice
(`settings.sound`), with the panel's replay controls.

Feature 408 (R02-G11-08) adds the regression net: the solver regression over the 100 witnesses, `EchoCartographerGolden`
with the pinned `golden-frames.json` (16 code-computed frame descriptions), the simulator golden-frame and memory
classes, `scripts/echo_cartographer_regression.py` and the CI step "Echo Cartographer regression (host)".

Feature 409 (R02-G11-09) adds the in-app integration: identifiers on every panel control, the schema-1 and schema-2
examples (`EchoCartographerSchemaExamples`) stored by the app registration, app unit tests, and the interface tests
`ECGPlayUITests` and `ECGReplayUITests` (serial chunk `t3`).

Feature 410 (R02-G11-10) prepares Echo Cartographer's device campaign without touching a device:
`docs/apps/echo-cartographer/device-rows.json` (rows EC-D1 … EC-D8, all pending), the written plan
`docs/apps/echo-cartographer/device-campaign.md`, and the release step `device-rows-r02-g11`.

## Harmonic Bridges (R02-G12, `r02-g12.harmonic-bridges`, free)

`HarmonicBridgesCore` (feature 411, R02-G12-01) is the playable rule kernel: the exact swing table, string resonance,
averaged swings, bridges and the bridge graph's reachability per step (`HarmonicBridgesSwing`, `HarmonicBridgesString`,
`HarmonicBridgesTone`, `HarmonicBridgesResonance`, `HarmonicBridgesReport`), `HarmonicBridgesLevel` (immutable,
fingerprinted, JSON schema 1, with names in words), the play state `HarmonicBridgesPlay` with `HarmonicBridgesAction`,
`HarmonicBridgesStage`, `HarmonicBridgesEvent`, `HarmonicBridgesFailure` and append-only `HarmonicBridgesRecord`s, and
`HarmonicBridgesRules` for the R02-F23 puzzle contract. Refusals are `HarmonicBridgesError` with `r02-g12.*` codes. Rules:
[docs/architecture/harmonic-bridges.md](../../docs/architecture/harmonic-bridges.md).

Feature 412 (R02-G12-02) adds the content pipeline: the 100-entry `HarmonicBridgesManifest`, band profiles and the
constructive seeded `HarmonicBridgesGenerator`, `HarmonicBridgesSolver` (bridge patterns per peg; the minimal set of
retuned strings by increasing size, with the smaller choices as the proof), `HarmonicBridgesDifficulty`,
`HarmonicBridgesWitness` and the 100 witness files in `docs/games/harmonic-bridges/levels/`, with the pinned catalog
digest.

Feature 413 (R02-G12-03) adds the hero renderer and the experience: `HarmonicBridgesSceneSnapshot` (palette, tiers, the
shown step and the kernel's exact report), `HarmonicBridgesSceneGeometry` (island prisms, strings with their sample
marks, membranes, pips and the moves gauge; camera; CPU reference), `HarmonicBridgesShaders` (bridge and glow programs
with signed-distance shading, the presentation wave of the strings and the wave shells), the adapter
`HarmonicBridgesExperienceCore`, the scenario manifest, and the iOS target `HarmonicBridgesExperience` (presenter, bridge
scene, control panel), registered as a candidate.

Feature 414 (R02-G12-04) adds the gestures: `HarmonicBridgesOrbit` and the orbiting camera, the analytic
`HarmonicBridgesPicker` (projected pips, goal and string segments with 22-point targets) and the host-tested
`HarmonicBridgesGestureController` (tap a string to choose and audition it, drag up or down to tune its peg, tap the goal
or a pip to test, double tap to reset, two-finger orbit), wired through the presenter's pointer entry with a "Reset
view" button.

Feature 415 (R02-G12-05) adds teaching and progression: `HarmonicBridgesHints` (three hint levels from the solver's
minimal plan at the current pegs, and the failure explanation), `HarmonicBridgesProgress` (stars, unlocks, the daily
level, practice and the tutorial steps), the adapter's `level.select`, `mode.*` and `tutorial.dismiss` controls with
snapshot schema 2 and its migration, and the panel's tutorial, hint, failure, band and stars text.

Feature 416 (R02-G12-06) adds polish and accessibility: `HarmonicBridgesFeedbackPlan` (announcements and haptics),
`HarmonicBridgesLights` (eased glow and won brightening with Reduce Flashing fades), `HarmonicBridgesSoundRecipe` (the
plucked string's audition and the ambient loop), the shader's won-light uniform, and the accessible panel (labels,
values, the adjustable string and peg, the summary element, Dynamic Type, the Sound toggle).

Feature 417 (R02-G12-07) adds persistence and replay: result traces and `HarmonicBridgesReconciliation` (every saved
result replayed on its certified level on restore), snapshot schema 3 with migrations, `replay.start/step/stop`, the
saved sound choice (`settings.sound`), and the panel's replay controls and dropped-results announcement.

Feature 418 (R02-G12-08) adds the regression net: the solver regression over the 100 witnesses with eleven named
alterations, `HarmonicBridgesGolden` with the pinned `golden-frames.json` (16 code-computed frame descriptions), the
simulator golden-frame and memory classes, `scripts/harmonic_bridges_regression.py` and the CI step "Harmonic Bridges
regression (host)".

Feature 419 (R02-G12-09) adds the in-app integration: the pinned identifier list of the panel, the schema-1 and
schema-2 examples (`HarmonicBridgesSchemaExamples`) stored by the app registration, app unit tests, and the interface
tests `HBPlayUITests` and `HBReplayUITests` (serial chunk `u3`).

Feature 420 (R02-G12-10) prepares Harmonic Bridges's device campaign without touching a device:
`docs/apps/harmonic-bridges/device-rows.json` (rows HB-D1 … HB-D8, all pending), the written plan
`docs/apps/harmonic-bridges/device-campaign.md`, and the release step `device-rows-r02-g12`.

## Acoustic Constellator (R02-G13, `r02-g13.acoustic-constellator`, free)

`AcousticConstellatorCore` (feature 421, R02-G13-01) is the playable rule kernel: the exact 12-step phase clock, the
clamped whole-number coupling, snapping, the order parameter as A + B√3 with its exact comparison, connectivity, the
listen and the graph-isomorphism label (`AcousticConstellatorClock`, `AcousticConstellatorLink`,
`AcousticConstellatorListen`, `AcousticConstellatorOutcome`, `AcousticConstellatorLabel`), `AcousticConstellatorLevel`
(immutable, fingerprinted, JSON schema 1, with names in words), the play state `AcousticConstellatorPlay` with
`AcousticConstellatorAction`, `AcousticConstellatorStage`, `AcousticConstellatorEvent`, `AcousticConstellatorFailure` and
append-only `AcousticConstellatorRecord`s, and `AcousticConstellatorRules` for the R02-F23 puzzle contract. Refusals are
`AcousticConstellatorError` with `r02-g13.*` codes. Rules:
[docs/architecture/acoustic-constellator.md](../../docs/architecture/acoustic-constellator.md).

Feature 422 (R02-G13-02) adds the content pipeline: the 100-entry `AcousticConstellatorManifest`, band profiles and the
constructive `AcousticConstellatorGenerator`, the minimal-plan `AcousticConstellatorSolver` (missing symbol pairs plus
the fewest helper links and phase nudges, smaller sets counted as the proof), `AcousticConstellatorDifficulty`,
`AcousticConstellatorWitness` and the 100 witness files in `docs/games/acoustic-constellator/levels/` with the pinned
catalog digest.

Feature 423 (R02-G13-03) adds the hero renderer and the experience: `AcousticConstellatorSceneSnapshot` (palette, tiers,
the shown tick and the kernel's listen report), `AcousticConstellatorSceneGeometry` (star ellipsoids and phase hands,
spline links, dashed guides, broken links, the coherence, hold and moves gauges; camera; CPU reference),
`AcousticConstellatorShaders` (constellation and glow programs with signed-distance shading, the star pulse and the
wave shells), the adapter `AcousticConstellatorExperienceCore`, the scenario manifest, and the iOS target
`AcousticConstellatorExperience` (presenter, constellation scene, control panel), registered as a candidate.

Feature 424 (R02-G13-04) adds the touch controls: `AcousticConstellatorOrbit` and an orbiting camera,
`AcousticConstellatorPicker` (coherence bars and hold pips, stars and link splines projected through the drawn camera,
each with a 22-point target), `AcousticConstellatorGestureController` (tap a star to nudge it, drag from star to star to
link or unlink, tap a link to inspect it, tap a gauge to listen, two-finger orbit, double tap to reset), the drag
filament, the presenter's pointer entry and "Reset view"; all 100 levels are won through the panel alone in a host
test.

Feature 425 (R02-G13-05) adds teaching and progression: the solver entry `plan(_:links:phases:)`,
`AcousticConstellatorHints` (three hint levels, following exact hints wins every certified level),
`AcousticConstellatorFailureExplanation`, `AcousticConstellatorProgress` (tutorial steps on levels 1 … 3, stars, the
daily level × 89, practice with budget 40), the adapter's `level.select`, `mode.daily`, `mode.practice`, `mode.campaign`
and `tutorial.dismiss` with snapshot schema 2 and a migration from 1, and the panel's tutorial, hint, failure, goal,
stars and modes.

Feature 426 (R02-G13-06) adds polish and accessibility: `AcousticConstellatorFeedbackPlan` (announcements and haptics
from the old and new core), `AcousticConstellatorLights` (glow and won brightening faded, slower under Reduce
Flashing), `AcousticConstellatorSoundRecipe` (the two-tone audition of an inspected link and the ambient loop), the
shaders' `u_wonLight`, the experience's `AcousticConstellatorSound`, adjustable star and partner, a summary element and a
Sound toggle.

Feature 427 (R02-G13-07) adds persistence and replay: results carry their winning trace and are reconciled on restore
(`AcousticConstellatorReconciliation`), snapshot schema 3 with migrations from 1 and 2, a replay mode
(`replay.start`, `replay.step`, `replay.stop`) and the saved sound choice (`settings.sound`).

Feature 428 (R02-G13-08) adds the regression net: the solver regression over all 100 levels with thirteen named
alterations, the code-only golden frames (`AcousticConstellatorGolden`, `golden-frames.json`), the simulator frame and
memory checks, the CI step and `scripts/acoustic_constellator_regression.py`.


Feature 429 (R02-G13-09) adds the in-app integration: the pinned identifier list of the panel, the schema-1 and
schema-2 examples (`AcousticConstellatorSchemaExamples`) stored by the app registration, app unit tests, and the
interface tests `ACNPlayUITests` and `ACNReplayUITests` (serial chunk `v3`).

Feature 430 (R02-G13-10) prepares Acoustic Constellator's device campaign without touching a device:
`docs/apps/acoustic-constellator/device-rows.json` (rows ACN-D1 … ACN-D8, all pending), the written plan
`docs/apps/acoustic-constellator/device-campaign.md`, and the release step `device-rows-r02-g13`.

## Moonlit Mechanism (R02-G14, `r02-g14.moonlit-mechanism`, free)

`MoonlitMechanismCore` (feature 431, R02-G14-01) is the playable rule kernel: the gear train in whole teeth with
alternating directions, the mesh alignment modulo the common divisor and its error, shadows cast from slot tables with
the lamp's integer shift, and the run over key frames (`MoonlitMechanismTrain`, `MoonlitMechanismGear`,
`MoonlitMechanismKeyFrame`, `MoonlitMechanismRunReport`, `MoonlitMechanismOutcome`, `MoonlitMechanismAction`),
`MoonlitMechanismLevel` (immutable, fingerprinted, JSON schema 1, with names in words), the play state
`MoonlitMechanismPlay` with `MoonlitMechanismStage`, `MoonlitMechanismEvent`, `MoonlitMechanismFailure` and append-only
`MoonlitMechanismRecord`s, and `MoonlitMechanismRules` for the R02-F23 puzzle contract. Refusals are
`MoonlitMechanismError` with `r02-g14.*` codes. Rules:
[docs/architecture/moonlit-mechanism.md](../../docs/architecture/moonlit-mechanism.md).

Feature 432 (R02-G14-02) adds the content pipeline: the 100-entry `MoonlitMechanismManifest`, band profiles and the
constructive `MoonlitMechanismGenerator`, the minimal-plan `MoonlitMechanismSolver` (plan vectors by L1 norm, pruned by
the lamp range and the mesh alignments, smaller vectors counted as the proof), `MoonlitMechanismDifficulty`,
`MoonlitMechanismWitness` and the 100 witness files in `docs/games/moonlit-mechanism/levels/`.

Feature 433 (R02-G14-03) adds the hero renderer and the experience: `MoonlitMechanismSceneSnapshot` (palette, tiers,
the shown key frame, the kernel's cast and run report), `MoonlitMechanismSceneGeometry` (night backdrop, paper wall, ink
shadows, target, missing, stray and forbidden marks, key-frame cards, alignment pips, moves bars, toothed gears with
blades, the lamp and its ladder; camera; CPU reference), `MoonlitMechanismShaders` (clockwork and glow programs with
signed-distance shading), the adapter `MoonlitMechanismExperienceCore`, `MoonlitMechanismScenarios` with the scenario
manifest, and the iOS target `MoonlitMechanismExperience` (presenter, clockwork scene, control panel), registered as a
candidate.

Feature 434 (R02-G14-04) adds the touch controls: `MoonlitMechanismOrbit` and the orbiting camera,
`MoonlitMechanismPicker` (lamp, ladder, key-frame cards, front-most gear) and `MoonlitMechanismGestureController`
(rotary gear drags that turn the train tooth for tooth, lamp drags, gear taps and double taps, card taps, lamp taps,
two-finger orbit), wired into the presenter with "Reset view".

Feature 435 (R02-G14-05) adds teaching and progression: the solver entry `plan(_:phases:height:)`,
`MoonlitMechanismHints` (three hint levels from the minimal plan of the current state) and
`MoonlitMechanismFailureExplanation`, `MoonlitMechanismProgress` with the tutorial steps, stars, the daily level (× 97)
and the practice mode; the adapter's `level.select`, `mode.daily`, `mode.practice`, `mode.campaign` and
`tutorial.dismiss` with snapshot schema 2 and a migration from 1; the presenter's tutorial, hint, explanation, goal and
mode controls.

Feature 436 (R02-G14-06) adds polish and accessibility: `MoonlitMechanismFeedbackPlan` (announcements and haptics from
the old and new core), `MoonlitMechanismLights` (glow and won fades eased by the frame clock), `MoonlitMechanismSoundRecipe`
(a gear's audition from its mesh and an ambient loop from the run report) and the experience's `MoonlitMechanismSound`,
the fallback's won level, and a panel with labels, values, an adjustable gear and key frame, a summary element and a
Sound toggle.

Feature 437 (R02-G14-07) adds persistence and replay: results with their winning traces, `MoonlitMechanismReconciliation`
(replaying each saved trace on restore, dropping and counting edited results), snapshot schema 3 with a 2 → 3 migration,
the replay mode (`replay.start`, `replay.step`, `replay.stop`) and the saved sound setting (`settings.sound`), with the
panel's replay controls and the dropped-results announcement.

Feature 438 (R02-G14-08) adds the regression net: the solver regression over all 100 levels with thirteen named
alterations, the code-only golden frames (`MoonlitMechanismGolden`, `golden-frames.json`), the simulator frame and
memory checks, the CI step and `scripts/moonlit_mechanism_regression.py`.

Feature 439 (R02-G14-09) adds the in-app integration: the pinned identifier list of the panel, the schema-1 and
schema-2 examples (`MoonlitMechanismSchemaExamples`) stored by the app registration, app unit tests, and the interface
tests `MMPlayUITests` and `MMReplayUITests` (serial chunk `w3`).

Feature 440 (R02-G14-10) prepares Moonlit Mechanism's device campaign without touching a device:
`docs/apps/moonlit-mechanism/device-rows.json` (rows MM-D1 … MM-D8, all pending), the written plan
`docs/apps/moonlit-mechanism/device-campaign.md`, and the release step `device-rows-r02-g14`.

## Voxel Origami (R02-G15, `r02-g15.voxel-origami`, free)

`VoxelOrigamiCore` (feature 441, R02-G15-01) is the playable rule kernel: the cube lattice (`VoxelOrigamiVector`, the 24
`VoxelOrigamiRotation`s), the hinge tree (`VoxelOrigamiCube`), poses computed from the root (`VoxelOrigamiLattice`:
twist hinges about the parent–child line, idle hinges, the end-pose collision and the exact sweep, the canonical form,
hash and covered count under `VoxelOrigamiOrientations`), `VoxelOrigamiLevel` (immutable, fingerprinted, JSON schema 1,
with names in words), the play state `VoxelOrigamiPlay` with `VoxelOrigamiStage`, `VoxelOrigamiEvent`,
`VoxelOrigamiFailure` and append-only `VoxelOrigamiRecord`s, and `VoxelOrigamiRules` for the R02-F23 puzzle contract.
Refusals are `VoxelOrigamiError` with `r02-g15.*` codes. Rules:
[docs/architecture/voxel-origami.md](../../docs/architecture/voxel-origami.md).

Feature 442 (R02-G15-02) adds the content pipeline: the 100-entry `VoxelOrigamiManifest`, band profiles and the
constructive `VoxelOrigamiGenerator`, the breadth-first `VoxelOrigamiSolver` with its minimality counts,
`VoxelOrigamiDifficulty`, `VoxelOrigamiWitness` files in `docs/games/voxel-origami/levels/` and the pinned catalog digest.

Feature 443 (R02-G15-03) adds the hero renderer and the experience: `VoxelOrigamiSceneSnapshot` (palette, tiers, the
pose's cells and orientations, the turnable and chosen hinges, the target at the best alignment, the kernel's shape
report), `VoxelOrigamiSceneGeometry` (night backdrop, turquoise target wireframes, chamfered frosted-ivory cubes with
inner glyphs and dots, hinge marks, failure outlines, covered pips and moves bars; camera; paint order; CPU reference),
`VoxelOrigamiShaders` (voxel and glow programs with signed-distance shading), the adapter
`VoxelOrigamiExperienceCore`, `VoxelOrigamiScenarios` with the scenario manifest, and the iOS target
`VoxelOrigamiExperience` (presenter, voxel scene, control panel), registered as a candidate.

Feature 444 (R02-G15-04) adds the gestures: `VoxelOrigamiOrbit` and `camera(_:aspect:orbit:)` with meshes built for the
drawn eye, `VoxelOrigamiPicker` (projected cube outlines, the front-most first, and the turn prediction of a hinge's
tracked cube), `VoxelOrigamiGestureController` (taps choose, double taps and drags turn, two fingers orbit), the
presenter's pointer entry, the pending text and "Reset view".

Feature 445 (R02-G15-05) adds teaching and progression: `VoxelOrigamiSolver.plan(_:turns:)`, `VoxelOrigamiHints` (three
hint levels from the current state) and `VoxelOrigamiFailureExplanation`, `VoxelOrigamiProgress` with stars, unlocks
and the daily level, `VoxelOrigamiMode` and `VoxelOrigamiTutorialStep`; the adapter's level, mode and tutorial controls
and snapshot schema 2 with a migration from 1; the panel's tutorial, hints, failure text, goal and modes.

Feature 446 (R02-G15-06) adds polish and accessibility: `VoxelOrigamiFeedbackPlan` (announcements and haptics),
`VoxelOrigamiLights` (eased glow and won look), `VoxelOrigamiSoundRecipe` (the hinge audition and the ambient recipe) and
the experience's `VoxelOrigamiSound`, with labels and values on every control, an adjustable hinge, a summary element
and a Sound toggle.

Feature 447 (R02-G15-07) adds persistence and replay: winning traces stored with each campaign or daily result
(`VoxelOrigamiReconciliation` checks them on restore and drops edited ones), snapshot schema 3 with migrations from 1
and 2, the saved sound choice (`settings.sound`) and `replay.start`, `replay.step` and `replay.stop` with the panel's
"Replay best solution", Step and Stop.

Feature 448 (R02-G15-08) adds the regression net: the solver regression over all 100 levels with eleven named
alterations, `VoxelOrigamiGolden` (16 code-computed frame descriptions pinned in `golden-frames.json`, test builds only),
simulator golden-frame and memory tests, `scripts/voxel_origami_regression.py` and a named CI step.

Feature 449 (R02-G15-09) adds the in-app integration: the pinned identifier list of the panel, the schema-1 and
schema-2 examples (`VoxelOrigamiSchemaExamples`) stored by the app registration, app unit tests, and the interface
tests `VOPlayUITests` and `VOReplayUITests` (serial chunk `x3`).

Feature 450 (R02-G15-10) prepares Voxel Origami's device campaign without touching a device:
`docs/apps/voxel-origami/device-rows.json` (rows VO-D1 … VO-D8, all pending), the written plan
`docs/apps/voxel-origami/device-campaign.md`, and the release step `device-rows-r02-g15`.

## Starlit Cartouche (R02-G16, `r02-g16.starlit-cartouche`, free)

`StarlitCartoucheCore` (feature 451, R02-G16-01) is the playable rule kernel: the star chart (`StarlitCartoucheVector`,
`StarlitCartoucheGlyphPoint`, `StarlitCartoucheStar` on periodic lattice orbits, `StarlitCartoucheCorridor` flyable within
the level's range, `StarlitCartoucheHazard`), the exact leg rules (`StarlitCartoucheChart`: refusals, the failures
window, hazard, window, deadline and stroke in that order, the route report with missing and stray strokes, glyph
mismatch and hazard clearance), `StarlitCartoucheLevel` (immutable, fingerprinted, JSON schema 1, with names in words),
the play state `StarlitCartouchePlay` with stages, events, records, undo, redo and replay, and `StarlitCartoucheRules`
(an R02-F23 `PuzzleRules`). Feature 452 (R02-G16-02) adds the content pipeline: `StarlitCartoucheManifest` (the 100
planned levels), `StarlitCartoucheGenerator` (seeded candidates by band, the first whose minimal plan is in range),
`StarlitCartoucheSolver` (a breadth-first search over star, beat and strokes with a counted minimality proof),
`StarlitCartoucheDifficulty` and `StarlitCartoucheWitness`, with the 100 witness files in
`docs/games/starlit-cartouche/levels/` and a pinned catalog digest. Feature 453 (R02-G16-03) adds the hero renderer
(`StarlitCartoucheSceneSnapshot`, `StarlitCartoucheSceneGeometry`, `StarlitCartoucheShaders`), the adapter
`StarlitCartoucheExperienceCore`, the scenarios and the iOS target `StarlitCartoucheExperience`, registered as a
candidate until X-R02-G16. Feature 454 (R02-G16-04) adds `StarlitCartouchePicker`,
`StarlitCartoucheGestureController`, the orbit and the launch preview (stars drawn at the launch beat, a previewed leg).
Feature 455 (R02-G16-05) adds `StarlitCartoucheHints` (three hint levels from a solver entry at the current state),
`StarlitCartoucheFailureExplanation`, `StarlitCartoucheProgress` (tutorial, stars, daily × 37, practice) and snapshot
schema 2.
Feature 456 (R02-G16-06) adds `StarlitCartoucheFeedbackPlan` (announcements and haptics), `StarlitCartoucheLights`
(eased glow and won look) and `StarlitCartoucheSoundRecipe` (the audition and the ambient loop), with VoiceOver
support in the panel.
Feature 457 (R02-G16-07) adds `StarlitCartoucheReconciliation` (winning traces, replayed and checked on restore),
the replay mode (`replay.start`, `replay.step`, `replay.stop`), the saved sound setting and snapshot schema 3.
Feature 458 (R02-G16-08) adds the regression net: the solver regression over all 100 levels, the code-only golden set
`StarlitCartoucheGolden` with `golden-frames.json`, the simulator frame and memory checks and
`scripts/starlit_cartouche_regression.py`.
Feature 459 (R02-G16-09) integrates it in the app as a candidate: the pinned identifier list, the stored schema-1
and schema-2 examples, app unit tests and the interface tests `SCPlayUITests` and `SCReplayUITests` (chunk `y3`).
Feature 460 (R02-G16-10) adds its device-row definition and written campaign plan
(`docs/apps/starlit-cartouche/`), checked by `scripts/check_device_rows.py`; no device is contacted.
See
[docs/architecture/starlit-cartouche.md](../../docs/architecture/starlit-cartouche.md).

## Celestial Eclipse Lab (R02-G17, `r02-g17.celestial-eclipse-lab`, free)

`CelestialEclipseLabCore` (feature 461, R02-G17-01) is the playable rule kernel: the exact sky
(`CelestialEclipseLabVector`, `CelestialEclipseLabBody` on periodic lattice orbits with a disc radius and a phase,
eclipses by the strict integer disc test, visibility classes total, annular and partial, intervals and the timeline in
`CelestialEclipseLabSky`), the judge (match, `window`, `unwanted`, `horizon`), `CelestialEclipseLabLevel` (immutable,
depth-ordered pairs, fingerprinted, JSON schema 1, with names in words), the play state `CelestialEclipseLabPlay` with
stages, phase changes and the run, records, undo and redo, and `CelestialEclipseLabRules` (an R02-F23 `PuzzleRules`
over phase vectors). Feature 462 (R02-G17-02) adds the content pipeline: `CelestialEclipseLabManifest` (the 100
planned levels), `CelestialEclipseLabGenerator` (seeded candidates by band on integer orbits, the neighbour rule),
`CelestialEclipseLabSolver` (a phase search by number of changes over a pair-interval table, with a counted minimality
proof), `CelestialEclipseLabDifficulty` and `CelestialEclipseLabWitness`, with the 100 witness files in
`docs/games/celestial-eclipse-lab/levels/`. Feature 463 (R02-G17-03) adds the hero renderer
(`CelestialEclipseLabSceneSnapshot`, `CelestialEclipseLabSceneGeometry` with the shadow lens,
`CelestialEclipseLabShaders`), the adapter `CelestialEclipseLabExperienceCore`, the scenarios and the iOS target `CelestialEclipseLabExperience`,
registered as a candidate until X-R02-G17. Feature 464 (R02-G17-04) adds `CelestialEclipseLabPicker`,
`CelestialEclipseLabGestureController`, `CelestialEclipseLabOrbit`, the orbital-handle phase drag with its ghost
preview, the time dial and the panel's "Set phase". Feature 465 (R02-G17-05) adds `CelestialEclipseLabHints`
(three hint levels from a solver entry at the current phases), `CelestialEclipseLabFailureExplanation`,
`CelestialEclipseLabProgress` (tutorial, stars, daily × 29, practice) and snapshot schema 2. Feature 466 (R02-G17-06)
adds `CelestialEclipseLabFeedbackPlan` (announcements and haptics), `CelestialEclipseLabLights` (eased glow and won
look) and `CelestialEclipseLabSoundRecipe` (the audition and the ambient loop), with VoiceOver support in the panel.
Feature 467 (R02-G17-07) adds `CelestialEclipseLabReconciliation` (winning traces replayed on restore), snapshot schema
3, the replay mode and the saved sound choice. Feature 468 (R02-G17-08) adds the regression net:
`CelestialEclipseLabGolden` (test builds only), `golden-frames.json`, the solver regression and
`scripts/celestial_eclipse_lab_regression.py`. Feature 469 (R02-G17-09) pins the panel's identifiers and adds the
stored schema examples, the app's interface tests (`CEL`, chunk `z3`) and app unit tests. Feature 470 (R02-G17-10)
adds its device-row definition and written campaign plan (`docs/apps/celestial-eclipse-lab/`), checked by
`scripts/check_device_rows.py`; no device is contacted. See
[docs/architecture/celestial-eclipse-lab.md](../../docs/architecture/celestial-eclipse-lab.md).

## Apsides Workshop (R02-G18, `r02-g18.apsides-workshop`, free)

`ApsidesWorkshopCore` (feature 471, R02-G18-01) is the playable rule kernel: Kepler's equation in deterministic integer
fixed point (`ApsidesWorkshopFixed`: integer sine, cosine and square root, bounded Newton with a bisection fallback),
the exact sky (`ApsidesWorkshopOrbit` with its size, eccentricity and periapsis direction steps, positions rounded to
sky units, octant sectors, triangle-quadrature shares, apsis readings and strict planet contact in
`ApsidesWorkshopSky`), the judge (`contact`, `order`, `share`, `apsis-sector`, `apsis-distance`), `ApsidesWorkshopLevel`
(immutable, fingerprinted, JSON schema 1, with names in words), the play state `ApsidesWorkshopPlay` with stages,
tunings and the play, records, undo and redo, and `ApsidesWorkshopRules` (an R02-F23 `PuzzleRules` over orbits). See
[docs/architecture/apsides-workshop.md](../../docs/architecture/apsides-workshop.md).
Feature 472 (R02-G18-02) adds the content pipeline: `ApsidesWorkshopManifest` (100 planned levels), the generator, the
depth-search solver with its minimality proof, difficulty metrics and the witness files in
`docs/games/apsides-workshop/levels/`.
Feature 473 (R02-G18-03) adds the hero renderer and the experience target `ApsidesWorkshopExperience`: the scene
snapshot, the compass geometry with its CPU reference, the GLSL compass and glow programs, three tiers, the adapter
`ApsidesWorkshopExperienceCore`, the presenter, scene and minimal controls, the scenario manifest and the candidate
registration in the one app. Feature 474 (R02-G18-04) adds `ApsidesWorkshopPicker`, `ApsidesWorkshopGestureController`,
`ApsidesWorkshopViewOrbit`, the periapsis-knob and size-handle drags with their ghost preview, the time crank and the
panel's pending orbit with "Set periapsis" and "Set size". Feature 475 (R02-G18-05) adds `ApsidesWorkshopHints`
(three hint levels from a solver entry at the current orbit), `ApsidesWorkshopFailureExplanation`,
`ApsidesWorkshopProgress` (tutorial, stars, daily × 23, practice) and snapshot schema 2. Feature 476 (R02-G18-06)
adds `ApsidesWorkshopFeedbackPlan` (announcements and haptics), `ApsidesWorkshopLights` (eased glow and won look) and
`ApsidesWorkshopSoundRecipe` (the pending orbit's audition and the ambient loop), with VoiceOver support in the panel.
Feature 477 (R02-G18-07) adds `ApsidesWorkshopReconciliation` (winning traces replayed on restore), snapshot schema 3,
the replay mode and the saved sound choice. Feature 478 (R02-G18-08) adds the regression net: `ApsidesWorkshopGolden` (test builds
only), `golden-frames.json`, the solver regression and `scripts/apsides_workshop_regression.py`. Feature 479 (R02-G18-09)
pins the panel's identifiers and adds the stored schema examples, the app's interface tests (`AW`, chunk `a4`) and app
unit tests. Feature 480 (R02-G18-10) adds its device-row definition and written campaign plan
(`docs/apps/apsides-workshop/`), checked by `scripts/check_device_rows.py`; no device is contacted.

## Microscopic Aurora (R02-G19, `r02-g19.microscopic-aurora`, free)

`MicroscopicAuroraCore` (feature 481, R02-G19-01) is the playable rule kernel: the exact swim in deterministic integer
arithmetic (`MicroscopicAuroraDish`: a round enclosure in a dish of 24 × 24 cells, one synchronous step of separation,
alignment and cohesion plus the curl of up to three magnetic wells per tick with every division truncating toward zero
and per-axis clamps, trail density per cell, the stencil's coverage, four-neighbour groups and the swarm's coherence),
the judge (`exit`, `coherence`, `coverage`, `connectedness`), `MicroscopicAuroraLevel` (immutable, fingerprinted, JSON
schema 1, with names in words), the play state `MicroscopicAuroraPlay` with stages, placements, removals and the play,
records, undo and redo, and `MicroscopicAuroraPuzzle` (an R02-F23 `PuzzleRules` over well placements). Feature 482
(R02-G19-02) adds well sites and budgets up to 24 to the level, then the content pipeline: `MicroscopicAuroraManifest`
(100 planned levels), `MicroscopicAuroraGenerator`, `MicroscopicAuroraSolver` (minimal well sets with a full proof over
the sites), `MicroscopicAuroraDifficulty` and `MicroscopicAuroraWitness` (the 100 files in
`docs/games/microscopic-aurora/levels/`). Feature 483 (R02-G19-03) adds the hero renderer and the experience:
`MicroscopicAuroraSceneSnapshot`, `MicroscopicAuroraSceneGeometry` (the dish, the swimmers' capsules and ribbons, the
CPU reference), `MicroscopicAuroraShaders`, the adapter `MicroscopicAuroraExperienceCore`, the scenario manifest and
the iOS target `MicroscopicAuroraExperience` (presenter, scene, controls), registered as a candidate. Feature 484
(R02-G19-04) adds gameplay spatial interaction: `MicroscopicAuroraViewOrbit`, `MicroscopicAuroraPicker` (wells, sites,
the swim scrubber and the dish field picked through the drawn camera) and `MicroscopicAuroraGestureController` (tap a
site to place a well, drag a well to another site or off the dish with a preview of the kernel's swim, scrub the shown
tick, tap the field to freeze, two-finger orbit, double-tap or "Reset view"), wired through the presenter's pointer
entry; the panel gains "Freeze" and "Reset view". Feature 485 (R02-G19-05) adds teaching and progression:
`MicroscopicAuroraHints` (three hint levels from the current wells, the certified plan's next placement first, at most
1,200 sets judged), `MicroscopicAuroraFailureExplanation`, `MicroscopicAuroraProgress` (tutorial steps, stars, the
daily level × 19, campaign, practice with budget 24, daily modes) and adapter snapshot schema 2 with a migration from
schema 1. Feature 486 (R02-G19-06) adds polish and accessibility: `MicroscopicAuroraFeedbackPlan` (announcements and
haptics through the shared route), `MicroscopicAuroraLights` (eased glow and won look, fades of at least 0.4 s under
Reduce Flashing), `MicroscopicAuroraSoundRecipe` (the selected well's audition and an ambient loop, both synthesized,
off by default) and an accessible panel (a summary element, adjustable selection, values in words). Feature 487
(R02-G19-07) adds persistence and replay: snapshot schema 3 with winning traces, `MicroscopicAuroraReconciliation`
(every saved result replayed on restore, edited ones dropped and counted), replay of the best solution
(`replay.start`, `replay.step`, `replay.stop`) and the saved sound choice (`settings.sound`). Feature 488
(R02-G19-08) adds the regression net: a solver regression over all 100 levels, golden frame descriptions
(`MicroscopicAuroraGolden`, `golden-frames.json`), simulator golden-frame and memory tests, a CI step and
`scripts/microscopic_aurora_regression.py`. Feature 489 (R02-G19-09) pins the panel's identifiers and adds the
stored schema examples, the app's interface tests (`MA`, chunk `b4`) and app unit tests. Feature 490 (R02-G19-10)
adds its device-row definition and written campaign plan (`docs/apps/microscopic-aurora/`), checked by
`scripts/check_device_rows.py`; no device is contacted. See
[docs/architecture/microscopic-aurora.md](../../docs/architecture/microscopic-aurora.md).

## Mushroom Weather (R02-G20, `r02-g20.mushroom-weather`, free)

`MushroomWeatherCore` (feature 491, R02-G20-01) is the playable rule kernel: the exact weather in deterministic integer
arithmetic (`MushroomWeatherForest`: a forest floor of up to 12 × 14 cells, one synchronous cycle of pairwise diffusion
with antisymmetric flows, evaporation by vents and moonlight and release by spore pods, an exact water ledger, pod
growth by time-integrated humidity and colony runs), the judge (`dried`, `mold`, `unstable`), `MushroomWeatherLevel`
(immutable, fingerprinted, JSON schema 1, with names in words), the play state `MushroomWeatherPlay` with stages, pod,
vent and moonlight actions and the run, records, undo and redo, and `MushroomWeatherPuzzle` (an R02-F23 `PuzzleRules`
over arrangements). Feature 492 (R02-G20-02) adds pod sites, the 100-level manifest, the seeded generator
(`MushroomWeatherGenerator`), the minimal solver (`MushroomWeatherSolver`, work bound 1,500) and the witness
certificates (`MushroomWeatherWitness`, `docs/games/mushroom-weather/levels/`, pinned catalog digest). Feature 493
(R02-G20-03) adds the hero renderer and the experience: `MushroomWeatherSceneSnapshot`, `MushroomWeatherSceneGeometry`
(the forest floor, mist, lathed caps and pods, vents, gauges, the CPU reference), `MushroomWeatherShaders`, the adapter
`MushroomWeatherExperienceCore`, the scenario manifest and the iOS target `MushroomWeatherExperience` (presenter, scene,
controls), registered as a candidate. Feature 494 (R02-G20-04) adds gameplay spatial interaction:
`MushroomWeatherViewOrbit`, `MushroomWeatherPicker` (vents, pods, sites, the moon, the cycle scrubber and the floor
picked through the drawn camera) and `MushroomWeatherGestureController` (tap a site to place a pod, drag a pod with a
previewed run, tap a vent, drag the moon to set the moonlight, scrub cycles, orbit and reset the view). Feature 495
(R02-G20-05) adds teaching and progression: `MushroomWeatherHints` (three hint levels from the certified witness or a
bounded search), `MushroomWeatherFailureExplanation`, the tutorial, progress with stars, the daily level (× 17) and
practice (budget 24), and snapshot schema 2 with a migration from schema 1. Feature 496 (R02-G20-06) adds polish
and accessibility: `MushroomWeatherFeedbackPlan` (announcements and haptics through the shared route),
`MushroomWeatherLights` (eased glow and won look, fades of at least 0.4 s under Reduce Flashing),
`MushroomWeatherSoundRecipe` (the selected site's audition and an ambient loop, both synthesized, off by default) and
an accessible panel (a summary element, adjustable selection, values in words). Feature 497 (R02-G20-07) adds
persistence and replay: snapshot schema 3 with winning traces, `MushroomWeatherReconciliation` (every saved result
replayed on restore, edited ones dropped and counted), replay of the best solution (`replay.start`, `replay.step`,
`replay.stop`) and the saved sound choice (`settings.sound`). Feature 498 (R02-G20-08) adds the regression net: a
solver regression over all 100 levels, golden frame descriptions (`MushroomWeatherGolden`, `golden-frames.json`),
simulator golden-frame and memory tests, a CI step and `scripts/mushroom_weather_regression.py`. Feature 499
(R02-G20-09) pins the panel's identifiers and adds the stored schema examples, the app's interface tests (`MW`, chunk
`c4`) and app unit tests. Feature 500 (R02-G20-10) adds its device-row definition and written campaign plan
(`docs/apps/mushroom-weather/`), checked by `scripts/check_device_rows.py`; no device is contacted. See
[docs/architecture/mushroom-weather.md](../../docs/architecture/mushroom-weather.md).

## Binary Gardens (R02-G21, `r02-g21.binary-gardens`, free)

`BinaryGardensCore` (feature 501, R02-G21-01) is the playable rule kernel: the exact sky in deterministic integer
arithmetic (`BinaryGardensSky`: two stars on quantized analytic orbits of 48 phase steps from an integer cosine table,
tilt, separation, milliflux by the clamped inverse square, flux bands, the cyclic comfortable window and the integral),
the judge (`frozen`, `scorched`, `unstable`, `wilted`, `bleached`), `BinaryGardensLevel` (immutable, fingerprinted,
JSON schema 1, with names in words), the play state `BinaryGardensPlay` with stages, ring, phase, luminosity and tilt
actions and the run, records, undo and redo, and `BinaryGardensPuzzle` (an R02-F23 `PuzzleRules` over arrangements).
Feature 502 (R02-G21-02) adds the phase step, the 100-level manifest, the seeded generator (`BinaryGardensGenerator`),
the minimal breadth-first solver (`BinaryGardensSolver`, work bound 5 000) and the witness certificates
(`BinaryGardensWitness`, `docs/games/binary-gardens/levels/`, pinned catalog digest), in `Core/Content`. Feature 503
(R02-G21-03) adds the hero renderer and the experience: `BinaryGardensSceneSnapshot`, `BinaryGardensSceneGeometry`
(orbits through the kernel's table, cube-sphere worlds, star discs, gauges, the CPU reference), `BinaryGardensShaders`,
the adapter `BinaryGardensExperienceCore`, the scenario manifest and the iOS target `BinaryGardensExperience`
(presenter, scene, controls), registered as a candidate. Feature 504 (R02-G21-04) adds gameplay spatial
interaction: `BinaryGardensViewOrbit`, `BinaryGardensPicker` (gauge rows, stars, luminosity pips, worlds, rings, the
tilt dial and the system disc picked through the drawn camera), `BinaryGardensGestureController` (drag a star across
its rings or along its orbit with a previewed report, tap or drag pips and the tilt dial, inspect worlds, scrub ticks,
orbit and reset the view) and the panel's direct ring, luminosity, phase and tilt choices. Feature 505 (R02-G21-05) adds
teaching and progression: `BinaryGardensHints` (three hint levels from the certified witness or a bounded search),
`BinaryGardensFailureExplanation`, the tutorial, progress with stars, the daily level (× 13) and practice (budget 24),
and snapshot schema 2 with a migration from schema 1.
See [docs/architecture/binary-gardens.md](../../docs/architecture/binary-gardens.md).
