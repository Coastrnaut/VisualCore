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
