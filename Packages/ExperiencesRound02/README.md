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
