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
