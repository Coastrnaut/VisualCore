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

## Lissajous Labyrinth (R02-G02, `r02-g02.lissajous-labyrinth`, free)

`LissajousLabyrinthCore` (feature 311, R02-G02-01) is the playable rule kernel: the integer `LissajousLabyrinthSine`,
`LissajousLabyrinthLevel` with `LissajousLabyrinthBall`, `LissajousLabyrinthDials` and `LissajousLabyrinthDial`
(immutable, fingerprinted, JSON schema 1), the exact lap `LissajousLabyrinthLap` with `LissajousLabyrinthPoint` and
`LissajousLabyrinthVerdict`, the play state `LissajousLabyrinthPlay` with `LissajousLabyrinthStage`,
`LissajousLabyrinthEvent`, `LissajousLabyrinthAction` and append-only `LissajousLabyrinthRecord`s, and
`LissajousLabyrinthRules` for the R02-F23 puzzle contract. Refusals are `LissajousLabyrinthError` with `r02-g02.*` codes.
Rules: [docs/architecture/lissajous-labyrinth.md](../../docs/architecture/lissajous-labyrinth.md).
