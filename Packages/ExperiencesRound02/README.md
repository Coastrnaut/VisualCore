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

```bash
swift test --package-path Packages/ExperiencesRound02
```
