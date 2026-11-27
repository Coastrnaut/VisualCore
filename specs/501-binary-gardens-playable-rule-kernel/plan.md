# Implementation Plan: R02-G21-01 — Binary Gardens: playable rule kernel

**Branch**: `501-binary-gardens-playable-rule-kernel` (spec directory only; work on `main`) | **Date**: 2026-11-27 |
**Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/501-binary-gardens-playable-rule-kernel/spec.md`

## Summary

Add Binary Gardens' pure rule kernel, `BinaryGardensCore`, to `Packages/ExperiencesRound02` on the pattern of Mushroom
Weather's (feature 491) and Microscopic Aurora's (feature 481): exactly two stars and 1 … 5 garden worlds on analytic
circular orbits quantized to 48 phase steps (7.5° each), one tick per sample, so every body is back at its start after
the 48-tick cycle; positions from a fixed integer cosine table at scale 1024 (the quarter wave C[0 … 12] = 1024, 1015,
989, 946, 887, 812, 724, 623, 512, 392, 265, 134, 0, the rest by symmetry, S[k] = C[(k + 36) mod 48]) as integers at
scale 2^20, squared distances at scale 2^40; each star's flux on each world ⌊1000·L·2^40 / max(D, r_min²·2^40)⌋
milliflux (one truncating division per star; r_min 1 … 8; at most 64 000 per star), summed over the two stars; every
tick classed lethal low, dim, comfortable, bright or lethal high against the world's four bounds; the judge walking
ticks 1 … 48 + E (`frozen` or `scorched` at the first tick a world's lethal run exceeds the tolerance E, a run across
the cycle boundary counted whole), then per world in ascending order `unstable` (longest cyclic comfortable window
shorter than W) before `wilted` or `bleached` (integral below or above the bloom band), otherwise won; actions
`ring(star, index)`, `phase(star, step)`, `luminosity(star, index)` and `tilt(step)` (one action each, budget 1 … 24,
each must change the value, act on an adjustable control and keep the minimum separation σ at every tick 0 … 47) and
`run` (spends nothing, ends the level); an immutable, fingerprinted level with a JSON schema 1 stored form; the play
state machine with records, full undo, redo (undo from failed returns to playing with the arrangement before the run; a
won level is final) and replay; the light report after every action with words for every body, tick, band and measure;
and the rules as an R02-F23 `PuzzleRules` over arrangements. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6 (strict concurrency). **Primary dependencies**: VisualCoreSimulation (`PuzzleRules`,
`SeededRandom`) and VisualCoreMath (`StableHash`), exactly the two products `MushroomWeatherCore` and its tests
depended on at feature 491 (the later products of its features 493 and 496 are not needed by a pure kernel). No GPU,
UIKit, Objective-C++ or GLSL code in this feature; no new package; one new target pair. **Package**:
`Packages/ExperiencesRound02/Package.swift` gains the product `BinaryGardensCore`, the target `BinaryGardensCore`
(path `BinaryGardens/Core`) and the test target `BinaryGardensCoreTests` (path `BinaryGardens/CoreTests`), both
depending on VisualCoreSimulation and VisualCoreMath. **Storage**: none in this feature (the stored form is `Data`;
persistence comes with the adapter of R02-G21-03). **Numbers**: `Int64` (Swift `Int` on the 64-bit host and iOS)
throughout: a coordinate is at most 60 · 1024 · 1024 < 2^26 in magnitude, a coordinate difference below 100 · 2^20 <
2^27, a squared distance below 3 · (100 · 2^20)² < 2^56; the flux numerator 1000 · 64 · 2^40 < 2^56; a world's flux at
most 2 · 64 000 = 128 000 milliflux per tick; its integral at most 48 · 128 000 = 6 144 000 (bloom bounds up to
9 600 000 are accepted and simply unreachable above that). Nothing approaches 2^62; no platform floating point and no
run-time trigonometry decides anything; `Double` appears only in the words (the mean flux, printed from the exact
integral over 48). **Testing**: XCTest through `swift test --package-path Packages/ExperiencesRound02 --filter
BinaryGardens`. **Target platform**: macOS host for tests; iOS 26.0+ for the app later. **Project type**: SwiftPM
library target inside the experience collection package of the single app (ADR-0009 D-06). **Performance**: one
report is 48 ticks × (2 star positions + up to 5 world positions, 10 star-world fluxes, one separation) plus the judge's
at most 60-tick walk: about 1 000 integer steps; a puzzle move list holds at most 2 · 7 + 2 · 47 + 2 · 3 + 6 = 120
candidates, each with a 48-tick separation check (about 5 800 steps); a 500-run test stays well under 10 s.
**Constraints**: additive (no existing module changes); reason codes `r02-g21.*`; denylisted names (ProjectM,
PresetLibrary, MilkDrop …) avoided; the filter word `BinaryGardens` matches no other game's names (`NocturneGarden`
needs its own prefix). **Scale/Scope**: 5 source files, 6 test files, about 45 tests. **Seed convention**: a level's
seed is a `UInt64` stored in the level and in its records; nothing in the kernel draws random numbers; fixtures use
`SeededRandom(seed: 2_501)`, neighbouring-input checks seed 2_506. **CPU reference**: the light report (positions,
fluxes with each star's share, bands, runs, windows, integrals) is the CPU reference the renderer of R02-G21-03 will
consume; this feature defines no shader interface and no shader limits. **Dependency graph**: `BinaryGardensCore` →
{VisualCoreSimulation, VisualCoreMath}; `BinaryGardensCoreTests` → {BinaryGardensCore, VisualCoreSimulation,
VisualCoreMath}; no other game, no rendering, no ProjectM. **CI**: the `round02-host-tests` job is split into two
matrix halves by game since R02-G20-03; half a holds G01 … G10 and half b G11 … G20 (`EchoCartographer|…|
MicroscopicAurora|MushroomWeather`). `BinaryGardens` joins half b's filter in `.github/workflows/ci.yml` (one word
appended to the `group: b` filter; no new step, no new job): without it the new tests would run in neither half.
Half b stays the slower half by about one tenth; a kernel adds seconds, not minutes, and the split is revisited only
when a ci run of half b nears its 60-minute limit (research R12). **Local round-two filters**: the five round-two host
chunks of the baselines and the regression are `round02-host-1` (`VoxelOrigami`, 57 s), `-2`
(`MoonlitMechanism|AcousticConstellator|HarmonicBridges`, 48 s), `-3c` (seven games, 138 s), `-3e` (four games,
211 s) and `-3f` (`EchoCartographer|ColorfallCanyons|StarlitCartouche|ApsidesWorkshop|MushroomWeather`, 147 s, at
R02-G20-10). `BinaryGardens` joins chunk 2, the lightest (research R12), so its filter becomes
`MoonlitMechanism|AcousticConstellator|HarmonicBridges|BinaryGardens`; every chunk stays far below the 540 s limit.
The baselines run with the unchanged five filters on the committed tree before the targets exist.

No NEEDS CLARIFICATION remains.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Result |
|---|---|
| I Proven Renderer Only | PASS — no GPU code; nothing renders in this feature; the later renderer uses the ANGLE → Metal path. |
| II App-Neutral Public API | PASS — game rules stay in the experience package (genuinely one-off rules); VisualCore API unchanged; the reusable parts (puzzle contract, seeded random, SHA-256) are consumed from VisualCore, not copied. Ownership: all components belong to `BinaryGardensCore`; none is generic enough for a VisualCore module (the cosine table is 48 steps at scale 1024 for this game's quantization only). |
| II-a Preserve the Reference and Prove It | PASS — no shared seam changes; the seven-step reference regression still runs in two chunks (reference-1, reference-2) as every game feature does. |
| III Explicit GPU Lifecycle and Thread Ownership | PASS — not applicable (no GPU handles, no contexts). |
| IV Host-Testable Domain Logic, Test-First | PASS — pure Core with host tests; deterministic ticks, explicit seeds, no floating point, bounded loops (48 ticks, a 60-tick walk), reference fixtures from an independent second implementation. |
| V Implementation Before Devices | PASS — no device work; no device-only items. |
| VI Evidence Over Assertion | PASS — every task is verified by a `run-check` record; agent reports are retested by the lead. |
| VII Native, Accessible UI | PASS — no UI here; every star, ring, world, band and measure is named in words (FR-R02G2101-013), the basis of the later VoiceOver labels and non-colour cues. |
| VIII Public Apple APIs, Privacy and Truthful Capabilities | PASS — Foundation only; no network, no private API, no data collection. |
| IX Bounded Untrusted Input | PASS — every level value is a bounded integer range; the stored form is versioned (schema 1), re-checked on decode, refused when damaged, edited or newer. |
| X Licensing and Provenance | PASS — the project's own archived design; original code; the cosine table is computed from its definition (nearest integer to 1024·cos(7.5°·k)), no catalogue or third-party data. |
| XI One App and Stable Experience Identity | PASS — experience R02-G21 (`r02-g21.binary-gardens`) inside the single app; no app target; depends on no other experience; level fingerprints. |
| XII One Purchase and No Advertising | PASS — free tier; no store, ads or tracking code. |
| XIII Code-Driven Visuals | PASS — no art; the report is the code-driven data the renderer will draw. |

Post-design re-check: PASS (no violations; Complexity Tracking empty).

## Project Structure

### Documentation (this feature)

```text
specs/501-binary-gardens-playable-rule-kernel/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, contracts/api.md
├── checklists/
└── tasks.md            (/speckit-tasks)
```

### Source Code (repository root)

```text
Packages/ExperiencesRound02/Package.swift                                              edit  + product, Core and test targets (lead)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensError.swift                new   reason codes r02-g21.* (lead)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensSky.swift                  new   cosine table, positions, distances, milliflux, bands, report, judge (lead)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensLevel.swift                new   level, ranges, refusals, words, stored form (lead)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensPlay.swift                 new   stages, actions, records, undo, redo, replay (B)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensPuzzle.swift               new   R02-F23 PuzzleRules (C)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensFixtures.swift        new   seeded levels with known winning arrangements (lead)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensLevelTests.swift      new   ranges, refusals, stored form, table, hand cases, words (lead)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensSkyTests.swift        new   independent reference on 500 seeded runs, boundaries (A)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensPlayTests.swift       new   (B)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensPuzzleTests.swift     new   (C)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensInvariantTests.swift  new   nine named source invariants (D)
.github/workflows/ci.yml                                                               edit  half b filter + BinaryGardens (lead)
docs/architecture/binary-gardens.md (new), Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (lead)
```

**Structure Decision**: the experience module `Packages/ExperiencesRound02/BinaryGardens` of ADR-0009 (the source's
`Apps/BinaryGardens` and `Packages/GameModules/BinaryGardensCore` superseded); this feature adds only its Core and
CoreTests. The sky's exact geometry and judge live in `BinaryGardensSky` (not `BinaryGardensOrbit`: the type covers the
whole two-star system with its light, not one orbit), and the puzzle contract is `BinaryGardensPuzzle`, so the game's
name does not clash with a module type. No XcodeGen, app target, scheme or catalog change (registration and adapter come
in R02-G21-03 and X-R02-G21).

**Migration**: none (schema 1 is new; a later schema adds a forward migration and keeps reading schema 1).
**Rollback**: revert the feature's commits; the targets are additive, the other games' targets and the CI half a are
untouched, and the one-word CI filter edit reverts with them.

## Parallel work

Lead: package, error, sky, level and fixtures first (the shared files); then agents A (sky tests with an independent
reference: a second, straightforward implementation of the cosine table from its symmetry rules, the positions, the
milliflux law, the bands, the lethal walk, the cyclic window, the integrals and the judge, written from the spec's
clarifications only, compared on 500 seeded runs), B (play), C (puzzle) and D (invariants) in parallel, each writing
only its own new files in an isolated package copy; agents compile but run no tests while the lead's baselines or runs
are going; the lead retests every agent result, runs every check in the foreground and records checks after every agent
has reported. Shared files (package manifest, ci.yml, error, sky, level, fixtures, docs) stay with the lead.

## Complexity Tracking

None.
