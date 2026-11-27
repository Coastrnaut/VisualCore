# Implementation Plan: R02-G21-02 — Binary Gardens: level generator and solver witness

**Branch**: `502-binary-gardens-level-generator-and-solver-witness` (spec directory only; work on `main`) |
**Date**: 2026-11-27 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/502-binary-gardens-level-generator-and-solver-witness/spec.md`

## Summary

Extend `BinaryGardensCore` (feature 501, `Packages/ExperiencesRound02/BinaryGardens/Core`) with the content pipeline,
on the pattern of Mushroom Weather's (feature 492) and Microscopic Aurora's (feature 482), after one additive kernel
change: a level may declare a phase step g ∈ {1, 2, 3, 4, 6, 8, 12, 16, 24} (the divisors of 48 up to 24). With g > 1
every starting star phase is a multiple of g, a phase action off the grid is refused `.action("off the phase grid")` by
`BinaryGardensSky.changed` (so by the play and by the puzzle contract alike) and is not a move of the puzzle contract;
g = 1 is the default and is omitted from the stored form, so every feature-501 level encodes, fingerprints and plays
byte for byte as before. Then: the 100-entry `BinaryGardensManifest` from the archived design (section 6.21.18: number,
planned seed, band, budget 8 … 19, control emphasis); band profiles (adjustable controls, rings, luminosity levels,
phase step, T_max, worlds, σ, ω maximum, trim k, comfort, lethal and bloom margins, window slack, tolerance, plan length
p); a constructive generator per manifest entry (a winning arrangement drawn first, each world's flux bounds, window and
bloom band set from that winning run in exact integer arithmetic, then p changed controls give the start); a
breadth-first solver over arrangements by the number of legal actions from the start, each depth expanded from the
previous depth's arrangements in ascending order of their light loss, moves in the puzzle contract's fixed order,
skipping arrangements already reached, judging every new arrangement with the kernel's exact 48-tick report, counting
arrangements judged against a bound of 5,000 and storing the counts at every smaller depth as the minimality proof;
difficulty metrics with the nearest miss; witness files with per-action state digests, the terminal light report (per
world integral, exact mean, lethal run, window, bloom; star separation) and the counterexample with the nearest miss's
arrangement and first failure; the catalog digest, the neighbour rule and the progression rule; the named content and
novelty invariant tests. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

The band profiles of clarification Q1 are arithmetic bounds; the first implementation step (T-R02G2102-003 below)
runs the real generator and solver on the real kernel over the real 100 entries and records in research.md R4 the
largest candidate index per band, the work per level and for the catalog, the witness lengths by band and the slowest
level and group. Any profile value changed there is written back into spec clarification Q1, research.md R4 and
data-model.md in the same commit, never left divergent.

## Technical Context

**Language/Version**: Swift 6 (strict concurrency). **Primary dependencies**: VisualCoreSimulation (`SeededRandom`,
`SeedDerivation`, `PuzzleRules`, `PuzzleCatalog`, `ProgressionRule`, `PuzzleDifficulty`) and VisualCoreMath
(`StableHash`), already linked by `BinaryGardensCore` and `BinaryGardensCoreTests` (feature 501); Foundation for the
witness JSON. No new package, target, product or dependency; no GPU, UIKit, Objective-C++ or GLSL code (no shader
interface, no shader limits: nothing renders in this feature). **Storage**: the 100 witness files
`docs/games/binary-gardens/levels/001.witness.json … 100.witness.json` (JSON schema 1, sorted keys, pretty-printed,
one trailing newline), written only by the catalog test with `BINARY_GARDENS_WRITE_WITNESSES=1`. **Numbers**: catalog
levels have 3 … 5 rings (radii 2 … 16), 2 … 4 luminosity levels (4 … 32), phase step 8 (bands 1 … 2) or 6 (bands
3 … 5), T_max 0 … 3, 1 … 3 worlds, σ 0 … 6, ω 1 … 3, plans of 1, 2, 3, 3, 4 actions by band; at most 11, 69, 583, 1,416
and 4,048 arrangements up to a band's plan depth (research R10); arrangements judged bounded at 5,000 per candidate;
every rule is the kernel's integer rule (feature 501): flux at most 2 · 64 000 milliflux per tick, so c_hi is at most
⌈128 000 · 1 090 / 1 000⌉ = 139 520 and λ_hi at most max(139 521, ⌈128 000 · 1 300 / 1 000⌉) = 166 400, and the "λ_hi above 200 000" skip is a guard that cannot fire (tested
as a bound, research R12); no platform floating point and no run-time trigonometry in the generator or solver.
**Seeds**: candidate c of entry n draws from `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: UInt64(c)))`
in the drawing order of clarification Q1; test fixtures seed 2_502, neighbouring-input checks seed 2_507.
**Testing**: `swift test --package-path Packages/ExperiencesRound02 --filter BinaryGardens`; catalog certification in
20 groups of 5 levels, each under 10 s on a debug host build (measured locally in the first implementation step, never
asserted on CI); generated levels cached per process in a thread-safe `static let` of the test target (level n's
neighbour rule needs level n − 1). **Target platform**: macOS host for tests; iOS 26.0+ for the app later. **Project
type**: SwiftPM library target inside the experience collection package of the single app (ADR-0009 D-06).
**Performance**: one report is about 1,000 integer steps (feature 501 plan); a band-5 candidate judges at most 4,048
arrangements, each also needing the puzzle contract's move list (at most 2 · (5 + 8 + 4) + 4 = 38 candidates, each a
48-tick separation check); the solver memoises nothing across candidates and reads no clock. **Constraints**:
additive (feature 501's tests stay unchanged; no budget widening: every manifest budget 8 … 19 lies inside 1 … 24);
reason codes `r02-g21.*` (new: `r02-g21.generation`, `r02-g21.witness`); denylisted names (ProjectM, PresetLibrary,
MilkDrop …) avoided; the filter word `BinaryGardens` matches no other game. **Scale/Scope**: 4 edited and 5 new source
files, 5 new test files, about 45 new tests, 100 witness files. **CPU reference**: the witness's terminal report is
the kernel's report of the winning arrangement; no new reference. **Dependency graph**: unchanged —
`BinaryGardensCore` → {VisualCoreSimulation, VisualCoreMath}; tests → {BinaryGardensCore, VisualCoreSimulation,
VisualCoreMath}; no other game, no rendering, no ProjectM. **CI**: no workflow change — `BinaryGardens` is already in
the `round02-host-tests` half b filter of `.github/workflows/ci.yml` (feature 501); the catalog tests add an estimated
three times their local time on a runner (research R11), checked with `gh run list` after the push. **Local round-two
filters**: `round02-host-1` (`VoxelOrigami`), `-2` (`MoonlitMechanism|AcousticConstellator|HarmonicBridges|
BinaryGardens` — Binary Gardens is in chunk 2 since feature 501), `-3c` (`AuroraLoom|LissajousLabyrinth|HueCompass|
WaveKnotKeeper|ChronoConstellator|AmethystEscape|CelestialEclipseLab`), `-3e` (`FacetedForge|NocturneGarden|
BackwardsAurora|MicroscopicAurora`), `-3f` (`EchoCartographer|ColorfallCanyons|StarlitCartouche|ApsidesWorkshop|
MushroomWeather`); chunk 2 grows by the catalog's measured time and stays below 540 s (if the measurement says
otherwise, Binary Gardens moves to its own chunk and docs/automatedtesting.md says so).

No NEEDS CLARIFICATION remains.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Result |
|---|---|
| I Proven Renderer Only | PASS — no GPU code; nothing renders in this feature. |
| II App-Neutral Public API | PASS — game content stays in the experience package; VisualCore API unchanged (no API baseline change); the shared parts (`SeededRandom`, `SeedDerivation`, `PuzzleCatalog.digest`, `ProgressionRule`, `PuzzleDifficulty`, `StableHash`) are consumed, not copied. |
| II-a Preserve the Reference and Prove It | PASS — no shared seam changes; the seven-step reference regression runs in two chunks (reference-1, reference-2). |
| III Explicit GPU Lifecycle and Thread Ownership | PASS — not applicable (no GPU handles, no contexts). |
| IV Host-Testable Domain Logic, Test-First | PASS — pure Core with host tests; explicit seeds; counted (never timed) work bound; byte-for-byte witnesses; minimality re-checked by an independent enumeration. |
| V Implementation Before Devices | PASS — no device work; no device-only items. |
| VI Evidence Over Assertion | PASS — every level carries a replayable witness re-verified on decode; the profiles are measured before they are relied on and written back; every task is verified by a `run-check` record; agent results are retested by the lead. |
| VII Native, Accessible UI | PASS — no UI here; the witness's counterexample names its failure with world and tick or measure, the basis of later words. |
| VIII Public Apple APIs, Privacy and Truthful Capabilities | PASS — Foundation only; no network, no data collection. |
| IX Bounded Untrusted Input | PASS — witness files versioned (schema 1), re-checked on decode by replay and re-derivation, refused when damaged, edited, newer or no longer replaying; the phase step is range-checked; the solver's work is bounded. |
| X Licensing and Provenance | PASS — manifest copied from the project's own archived design (round2.md section 6.21.18); levels generated; no star catalogue or third-party data. |
| XI One App and Stable Experience Identity | PASS — experience R02-G21 (`r02-g21.binary-gardens`); no app target; level ids `binary-gardens-NNN`; fingerprints and the catalog digest pinned. |
| XII One Purchase and No Advertising | PASS — free tier; no store, ads or tracking code. |
| XIII Code-Driven Visuals | PASS — no art; levels are generated data. |

Post-design re-check: PASS (no violations; Complexity Tracking empty).

## Project Structure

### Documentation (this feature)

```text
specs/502-binary-gardens-level-generator-and-solver-witness/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, contracts/api.md
├── checklists/
└── tasks.md            (/speckit-tasks)
```

### Source Code (repository root)

```text
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensError.swift        edit  + generation(Int), witness(String) (lead)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensLevel.swift        edit  optional phase step, refusals, stored form (lead)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensSky.swift          edit  "off the phase grid" in changed, grid in isWellFormed (lead)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensPuzzle.swift       edit  phase candidates on the grid (lead)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensManifest.swift     new   100 entries, provenance (lead)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensDifficulty.swift   new   control, plan, difficulty (lead)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensSolver.swift       new   breadth-first sweep, loss order, work (lead)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensGenerator.swift    new   band profiles, candidates, bounds, catalog, digest (lead)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensWitness.swift      new   digests, terminal report, counterexample (agent B)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensPhaseStepTests.swift  new  kernel extension (lead)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensSolverTests.swift     new  incl. independent sequence enumeration (agent A)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensGeneratorTests.swift  new (agent C)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensWitnessTests.swift    new (agent B)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensCatalogTests.swift    new  digest, progression, neighbours, witnesses, content and novelty boundaries (lead)
docs/games/binary-gardens/levels/001.witness.json … 100.witness.json   new  generated by the catalog test (lead)
docs/architecture/binary-gardens.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md, README.md   edit (lead)
```

**Structure Decision**: the experience module `Packages/ExperiencesRound02/BinaryGardens` of ADR-0009 (the source's
`Apps/BinaryGardens` and `Packages/GameModules/BinaryGardensCore` superseded); this feature adds files to its Core and
CoreTests only. `BinaryGardensPlan` and `BinaryGardensControl` live in `BinaryGardensDifficulty.swift` (as
`MushroomWeatherPlan` lives in `MushroomWeatherDifficulty.swift`) so the solver, generator and witness share them
without a cycle. The content and novelty boundary tests sit in `BinaryGardensCatalogTests` (as AuroraLoom's content
boundary does), next to the catalog cache they need; feature 501's `BinaryGardensInvariantTests` stays unchanged. No
XcodeGen, app target, scheme, catalog registration or CI change.

**Migration**: none. The level's stored form gains an optional `phaseStep`, omitted when 1, so every existing stored
level and fingerprint is unchanged; witness schema 1 is new. **Rollback**: revert the feature's commits; every change
is additive and the witness directory is new.

## Implementation order (one task per step, `run-check` names as in quickstart.md)

1. **Baselines** (T-R02G2102-001) after R02-G21-01 is recorded: `baseline-host`, `baseline-timing`,
   `baseline-round02-1`, `-2` (with `BinaryGardens`), `-3c`, `-3e`, `-3f`; the rendering baseline is R02-G21-01's.
2. **Kernel extension** (T-R02G2102-002, lead): before editing, record one literal fingerprint of a hand level from
   the unchanged kernel; then the phase step (level, sky, puzzle), the two error cases, `BinaryGardensPhaseStepTests`
   (the pinned fingerprint and byte-identical stored form without a step, round trip with a step, the two level
   refusals in their order, the play's and the puzzle's off-grid refusal, move lists on the grid); `host`.
3. **Manifest, difficulty, solver and generator, measured** (T-R02G2102-003 solver and T-R02G2102-004 generator,
   lead): write the manifest, `BinaryGardensControl`, `BinaryGardensPlan`, `BinaryGardensDifficulty`, the solver and
   the generator from clarifications Q1 and Q2; then, in an isolated copy (no source edits in the working tree while a
   test chain runs), build the whole catalog once in a debug host build with a temporary measurement test that prints
   per level the accepted candidate index, the work, the witness length, the arrangements by depth and the elapsed
   time (removed before commit; elapsed time is printed, never asserted) and record the results in research.md R4.
   If an entry reaches `generation(n)`, a band's witness lengths are not its p, or a group of five exceeds 6 s, adjust
   only the profile values research R4's adjustment ladder names (never p, the phase steps or the budgets), re-measure,
   and write the changed values back into spec clarification Q1, research.md and data-model.md in the same commit.
   Agents A and C then write the solver and generator tests against contracts/api.md; `host-2` (solver), `host-3`
   (generator).
4. **Witness** (T-R02G2102-005, agent B): `BinaryGardensWitness.swift` and its tests; `host-4`.
5. **Catalog** (T-R02G2102-006, lead): `BinaryGardensCatalogTests` and the 100 witness files (written once with
   `BINARY_GARDENS_WRITE_WITNESSES=1 swift test --no-parallel …`, then compared byte for byte on every run); the
   pinned digest; `host-5`.
6. **Docs and regression** (T-R02G2102-007 … 011): architecture (content pipeline), package README, testing doc;
   `round02-host-1`, `-2`, `-3c`, `-3e`, `-3f`; `rendering-27`, `rendering-26`, `experiences`, `host-full`;
   `reference-1`, `reference-2`; `script-tests` run alone.
7. **Converge** (T-R02G2102-012): `/speckit-converge` and `/speckit-implement` until nothing is appended; seal and
   record; README row and gate list updated.

## Parallel work

The lead writes the kernel extension, the error cases, the manifest, the difficulty, the solver and the generator
(step 3, measured before anything depends on the profiles); agents A (solver tests, including an independent
enumeration of every action sequence shorter than the plan through `BinaryGardensPuzzle` moves, with no visited set
and no loss order), B (witness and its tests) and C (generator tests) then work in parallel against contracts/api.md in
isolated copies, never running a heavy build while a chain runs; the lead writes the catalog tests and the witness
files, retests every agent result in the foreground and records checks only after every agent has reported.

## Complexity Tracking

None.
