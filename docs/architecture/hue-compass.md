# Hue Compass (R02-G04) — rules

Experience `r02-g04.hue-compass` (free) of the one VisualCore app; package `Packages/ExperiencesRound02`, target
`HueCompassCore` (feature 331, R02-G04-01). The player turns a spectral compass, samples clues in a coloured fog and
infers the hidden target, then selects a bearing and a hue band; a selection inside both tolerances wins. Everything here
is pure, exact integer logic; drawing, controls and sound come in later features of R02-G04.

## Wheel

- **Bearings and bands.** The wheel has 96 bearings, counter-clockwise from +x, and 24 hue bands of 4 bearings each. The
  band of bearing b is (⌊b/4⌋ + offset) mod 24, where the level's offset is 0 … 23 — the exact form of the source's
  hue = (atan2(y, x) + offset) / 2π.
- **Sectors.** Bearing k's sector lies between two constant integer boundary vectors (`HueCompassWheel.boundaries`:
  (cos, sin)(2πk/96) × 65 536, rounded once and stored). A non-zero direction p is in sector k exactly when
  cross(boundary k, p) ≥ 0 and cross(boundary k + 1, p) < 0, so every direction lies in exactly one sector and every
  device decides the same; no floating point is used.
- **Distances.** Bearing and band distances are circular, the shorter way round (0 … 48 and 0 … 12).

## Clues

A probe at bearing β returns two independent parts:

- **Hue gap**: the band distance between β's band and the target's band (0 … 12). It never reads the fog.
- **Fog depth**: the sum of the fog densities (0 … 9 per bearing) of the bearings strictly inside the shorter arc from β
  to the target; when both arcs are 48 long, the counter-clockwise arc from β. It never reads hue or offset, so a player
  who cannot tell hues apart still has a full clue (drawn later as luminance and symbols).

## Verdict and allowance

Turns move the bearing by −48 … 48 non-zero steps and cost nothing. Probes and the selection share the allowance
(2 … 24 units). A selection wins exactly when its bearing is within the bearing tolerance (0 … 4) of the target and its
band within the band tolerance (0 … 2) of the target's band; otherwise it fails (`selection`). A probe that spends the
last unit fails the level (`probes`), so a player always keeps one unit for the selection. A level whose start bearing
already lies within the bearing tolerance of the target is refused.

## Play

`HueCompassPlay` moves through loading, tutorial, playing, paused, won or failed and result. An action is checked in
this order — stage, previous fingerprint, range, allowance — and refused without change (`r02-g04.stage`, `.stale`,
`.action("range")`, `.allowance`). Every accepted turn, probe, selection, undo and redo appends a record with the
previous and next play fingerprints (SHA-256 of the schema, level fingerprint, bearing, units spent, clues, stage,
failure and the selected bearing and band). Undo and redo hold turns only; a probe or a selection clears both, because a clue once seen cannot be unseen.
A record trace replays to the same records and outcome (`HueCompassPlay.replay`).

## Stored form and contract

Levels are JSON schema 1 with sorted keys and their fingerprint; decoding re-checks every rule and the fingerprint and
refuses damaged, edited and newer forms (`r02-g04.malformed`, `.newer-schema`). `HueCompassRules` expresses the game as
an R02-F23 `PuzzleRules`: a position is (bearing, units spent, outcome), moves are turn(+1), turn(−1), probe and a
selection at the current bearing of each of the 24 bands. The contract lists only single-step turns, so a certified solution (R02-G04-02) spells a
large turn as single steps; the play accepts both.

## Content: generator, solver and witnesses (feature 332, R02-G04-02)

- **Manifest.** `HueCompassManifest` holds the 100 planned levels (20 per band, budgets 8 … 19) copied from the archived
  design. Candidate k of level n draws from `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: k))`: the
  offset, the 96 fog densities (each clear with the band's clear share), the target and a start farther from the target
  than the bearing tolerance. Band profiles: tolerances (4, 2), (3, 1), (2, 1), (1, 0), (1, 0); clear fog 0, 10, 20, 30,
  40 %; smallest probe counts 1, 1, 1, 1 … 2, 2. The allowance is the budget; ids `hue-compass-NNN`; levels 1 … 3 have the
  tutorial; at most 64 candidates, then `r02-g04.generation`.
- **Solver.** The candidates are the bearings farther from the start than the bearing tolerance. A probe set groups them
  by their clues; it settles the level when every group has one selection (a bearing within the bearing tolerance of
  every member and a band within the band tolerance of every member's band). `HueCompassSolver` tries the empty set,
  then every single bearing, then every pair, in lexicographic order, and returns the first that settles (at most 4,657
  sets, about 7 ms on a debug host). No level settles with no probe: at least 87 bearings are always candidates.
- **Difficulty.** The smallest probe count, the largest group after the best single probe, the tolerances, the clear
  share and the work. Band means of the smallest count are 1, 1, 1, 1.15 and 2; the catalog keeps R02-F24's progression
  rule; its digest (`PuzzleCatalog<HueCompassRules>`, id `hue-compass`) is pinned in a test.
- **Witnesses.** `docs/games/hue-compass/levels/NNN.witness.json` (schema 1): the level, the actions (a shortest turn to
  each probe bearing, the probe, then the selection for the target's group), the clues, the candidates left after each
  probe, the play fingerprints, a near-miss selection one bearing beyond the tolerance (fails) and an ambiguity (the
  empty set or the first single bearing with two targets that share clues and no selection). Decoding re-derives
  everything without the solver and refuses newer, damaged and edited files (`r02-g04.witness`). Regenerate on purpose
  with `HUE_COMPASS_WRITE_WITNESSES=1 swift test --package-path Packages/ExperiencesRound02 --filter
  HueCompassCatalogTests`.

## Experience and renderer (feature 333, R02-G04-03)

- **Adapter.** `HueCompassExperienceCore` opens certified level (seed mod 100) + 1 and accepts `compass.turn [steps]`
  (−48 … 48, not 0), `compass.probe`, `compass.select [bearing, band]`, `play.undo`, `play.redo` and `level.next`; kernel
  refusals pass through with their `r02-g04.*` codes and a fractional value is refused as `r02-g04.not-whole`. Its digest
  is the level number and the play fingerprint; its snapshot (schema 1) is `{level, records}`, restored by replay.
- **Snapshot.** The renderer reads only `HueCompassSceneSnapshot` (bearing, offset, fog, tolerances, clues, selection,
  stage, time, level number); the target is in it only once the play has ended, so no frame of a playing level can give
  the answer away.
- **Scene.** The compass lies in the xy-plane, bearing b at angle 2πb/96. A faceted glass needle (pearl, fresnel rim)
  reaches radius 0.8; 96 ticks sit at 0.95 … 1.0; the hue wheel is 24 unlit segments at 0.82 … 0.92 coloured by hue
  band/24 (saturation 0.85, value 1.0) with a grayscale glyph (shape band mod 4, ⌊band/4⌋ + 1 marks) in each segment's
  outer edge; the fog is 96 translucent prisms at 1.1 … 1.25 whose height and brightness follow density only; probes
  leave pearl marks, the selection an ember mark, and the ended play a sapphire ring at the target. The camera looks
  down −z tilted 35°, fitting a 1.45 bounding sphere for aspects 0.4 … 2.5. `ShaderMeshRenderer` has no colour stream,
  so the unlit program reads each vertex's colour from the normal slot and the fog's brightness and drift phase from
  the texture coordinates.
- **Tiers.** level-0: 12 needle facets, 3 fog layers, 2 glow shells; level-1: 8, 2, 1; level-2: 4, 1, 0. Bearings,
  colours, glyphs and marks sit at the same places at every tier; tier changes go to the presenter's `tierLog`.
- **Fallback and accessibility.** A program that fails to build leaves the level-2 geometry drawn unlit with
  `MeshRenderer` and keeps the reason. Reduce Motion holds the fog drift still; Reduce Flashing caps the glow gain.
- **Registration.** `r02-g04.hue-compass` is a registered candidate (not available until X-R02-G04) with 94 scenarios
  (`Packages/ExperiencesRound02/HueCompass/scenario-manifest.json`, regenerated with `UPDATE_SCENARIO_MANIFEST=1`).

