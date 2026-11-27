# Implementation Plan: R02-G22-01 — Mycelium Architect: playable rule kernel

**Branch**: `511-mycelium-architect-playable-rule-kernel` (spec directory only; work on `main`) | **Date**: 2026-11-27 |
**Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/511-mycelium-architect-playable-rule-kernel/spec.md`

## Summary

Add Mycelium Architect's pure rule kernel, `MyceliumArchitectCore`, to `Packages/ExperiencesRound02` on the pattern of
Binary Gardens' (feature 501) and Mushroom Weather's (feature 491): a W × H lattice (4 … 32 each) with one root,
1 … 6 terminals, rocks, toxins and 0 … 8 fixed nutrients; the player places up to 6 nutrients and 6 blockers and seeds
up to 4 directions at the root; the nutrient field f(c) = Σ s · max(0, R − Chebyshev distance) over unconsumed
nutrients (s 1 … 8, R 1 … 16); growth pulses 1 … P (P 1 … 128) move the growing tips in ascending tip number one cell
each, to the admissible neighbour of greatest score (f(t) − f(c)) − κ·turn − ο·obstacles (κ, ο 0 … 8; ties: smaller
turn, then lower direction number; no corner cutting; dormant when nothing is admissible or the best score is below
0); a tip stepping onto a nutrient consumes it and a new tip starts there a quarter turn clockwise; orthogonal segments
weigh 2 and diagonal 3; the run fails `starved` before a step that would exceed the nutrient budget (2 … 4094), `toxic`
on a step into toxin, and after growth `unreached` (the lowest-numbered terminal not in the network) or `overweight`
(total weight above the limit), otherwise won; the network is a tree of at most 2048 nodes; actions `nutrient(cell)`,
`blocker(cell)`, `clear(cell)`, `seed(direction)` and `unseed(direction)` (one action each, budget 1 … 24) and `run`
(spends nothing, ends the level); an immutable, fingerprinted level with a JSON schema 1 stored form; the play state
machine with records, full undo, redo and replay; the growth report after every action with words for every tip,
terminal, cell and measure; and the rules as an R02-F23 `PuzzleRules` over arrangements. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6 (strict concurrency). **Primary dependencies**: VisualCoreSimulation (`PuzzleRules`,
`SeededRandom`) and VisualCoreMath (`StableHash`), exactly the two products `BinaryGardensCore` and its tests depended
on at feature 501. No GPU, UIKit, Objective-C++ or GLSL code in this feature; no new package; one new target pair.
**Package**: `Packages/ExperiencesRound02/Package.swift` gains the product `MyceliumArchitectCore`, the target
`MyceliumArchitectCore` (path `MyceliumArchitect/Core`) and the test target `MyceliumArchitectCoreTests` (path
`MyceliumArchitect/CoreTests`), both depending on VisualCoreSimulation and VisualCoreMath. **Storage**: none in this
feature (the stored form is `Data`). **Numbers**: `Int` (64-bit) throughout; a field value is at most
14 · 8 · 16 = 1 792, a score lies in −1 792 − 4·8 − 8·8 … 1 792, a total weight at most 4 094, a node count at most
2 048; no platform floating point decides anything. **Testing**: XCTest through `swift test --package-path
Packages/ExperiencesRound02 --filter MyceliumArchitect`. **Target platform**: macOS host for tests; iOS 26.0+ for the
app later. **Project type**: SwiftPM library target inside the experience collection package of the single app
(ADR-0009 D-06). **Performance**: one run is at most 2 047 steps, each scoring 8 directions with an obstacle count of 8
cells and a field value over at most 14 nutrients (about 2 047 · 8 · 22 ≈ 360 000 integer steps worst case; typical
levels are far smaller); a puzzle move list holds at most 2 · 1 024 cell placements + 12 clears + 8 seed changes; a
500-run test stays well under 10 s. **Constraints**: additive (no existing module changes); reason codes `r02-g22.*`;
denylisted names (ProjectM, PresetLibrary, MilkDrop …) avoided; the filter word `MyceliumArchitect` matches no other
game's names. **Scale/Scope**: 5 source files, 6 test files, about 45 tests. **Seed convention**: a level's seed is a
`UInt64` stored in the level and in its records; nothing in the kernel draws random numbers; fixtures use
`SeededRandom(seed: 2_511)`, neighbouring-input checks seed 2_516. **CPU reference**: the growth report is the CPU
reference the renderer of R02-G22-03 will consume; no shader interface in this feature. **Dependency graph**:
`MyceliumArchitectCore` → {VisualCoreSimulation, VisualCoreMath}; `MyceliumArchitectCoreTests` →
{MyceliumArchitectCore, VisualCoreSimulation, VisualCoreMath}; no other game, no rendering, no ProjectM. **CI**: the
`round02-host-tests` job's half b filter gains `|MyceliumArchitect` after `BinaryGardens` (research R12). **Local
round-two filters**: `MyceliumArchitect` joins chunk 1 (`VoxelOrigami`, the lightest now that chunk 2 carries Binary
Gardens), so its filter becomes `VoxelOrigami|MyceliumArchitect`; the baselines run with the unchanged five filters
on the committed tree before the targets exist.

No NEEDS CLARIFICATION remains.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Result |
|---|---|
| I Proven Renderer Only | PASS — no GPU code; nothing renders in this feature. |
| II App-Neutral Public API | PASS — game rules stay in the experience package; VisualCore API unchanged; puzzle contract, seeded random and SHA-256 consumed from VisualCore. All components belong to `MyceliumArchitectCore`. |
| II-a Preserve the Reference and Prove It | PASS — no shared seam changes; the seven-step reference regression runs in two chunks. |
| III Explicit GPU Lifecycle and Thread Ownership | PASS — not applicable. |
| IV Host-Testable Domain Logic, Test-First | PASS — pure Core with host tests; deterministic pulses, explicit seeds, no floating point, bounded loops (P ≤ 128 pulses, ≤ 2 047 steps), an independent reference implementation in the tests. |
| V Implementation Before Devices | PASS — no device work. |
| VI Evidence Over Assertion | PASS — every task verified by a `run-check` record; agent reports retested by the lead. |
| VII Native, Accessible UI | PASS — no UI here; every cell, tip, terminal and measure named in words (FR-R02G2201-014). |
| VIII Public Apple APIs, Privacy and Truthful Capabilities | PASS — Foundation only; no network or data collection. |
| IX Bounded Untrusted Input | PASS — every level value is a bounded integer range; versioned stored form re-checked on decode. |
| X Licensing and Provenance | PASS — the project's own archived design; original code; no third-party data. |
| XI One App and Stable Experience Identity | PASS — experience R02-G22 (`r02-g22.mycelium-architect`) inside the single app; no app target. |
| XII One Purchase and No Advertising | PASS — free tier; no store, ads or tracking code. |
| XIII Code-Driven Visuals | PASS — no art; the report is the data the renderer will draw. |

Post-design re-check: PASS (no violations; Complexity Tracking empty).

## Project Structure

### Documentation (this feature)

```text
specs/511-mycelium-architect-playable-rule-kernel/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, contracts/api.md
├── checklists/
└── tasks.md            (/speckit-tasks)
```

### Source Code (repository root)

```text
Packages/ExperiencesRound02/Package.swift                                                    edit  + product, Core and test targets (lead)
Packages/ExperiencesRound02/MyceliumArchitect/Core/MyceliumArchitectError.swift              new   reason codes r02-g22.* (lead)
Packages/ExperiencesRound02/MyceliumArchitect/Core/MyceliumArchitectGrowth.swift             new   lattice, field, scoring, growth, weights, report, judge (lead)
Packages/ExperiencesRound02/MyceliumArchitect/Core/MyceliumArchitectLevel.swift              new   level, ranges, refusals, words, stored form (lead)
Packages/ExperiencesRound02/MyceliumArchitect/Core/MyceliumArchitectPlay.swift               new   stages, actions, records, undo, redo, replay (B)
Packages/ExperiencesRound02/MyceliumArchitect/Core/MyceliumArchitectPuzzle.swift             new   R02-F23 PuzzleRules (C)
Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectFixtures.swift      new   seeded levels with known winning arrangements (lead)
Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectLevelTests.swift    new   ranges, refusals, stored form, hand cases, words (lead)
Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectGrowthTests.swift   new   independent reference on 500 seeded runs, boundaries (A)
Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectPlayTests.swift     new   (B)
Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectPuzzleTests.swift   new   (C)
Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectInvariantTests.swift new  nine named source invariants (D)
.github/workflows/ci.yml                                                                     edit  half b filter + MyceliumArchitect (lead)
docs/architecture/mycelium-architect.md (new), Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Structure Decision**: the experience module `Packages/ExperiencesRound02/MyceliumArchitect` of ADR-0009 (the
source's `Apps/MyceliumArchitect` and `Packages/GameModules/MyceliumArchitectCore` superseded); this feature adds only
its Core and CoreTests. The lattice, field, growth and judge live in `MyceliumArchitectGrowth`, and the puzzle contract
is `MyceliumArchitectPuzzle`. No XcodeGen, app target, scheme or catalog change.

**Migration**: none (schema 1 is new). **Rollback**: revert the feature's commits; the targets are additive and the
one-word CI filter edit reverts with them.

## Parallel work

Lead: package, error, growth, level and fixtures first (the shared files); then agents A (growth tests with an
independent reference written from the spec's clarifications only, compared on 500 seeded runs), B (play), C (puzzle)
and D (invariants) in parallel, each writing only its own new files in an isolated package copy; agents compile but run
no tests while the lead's runs are going; the lead retests every agent result and records checks after every agent has
reported. Shared files (package manifest, ci.yml, error, growth, level, fixtures, docs) stay with the lead.

## Complexity Tracking

None.
