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

## Interaction (feature 334, R02-G04-04)

- **Swipe to turn.** A one-finger swipe turns a ghost needle by the finger's angle about the projected compass centre
  (atan2 of the touch relative to the centre, screen up positive, increments accumulated the shorter way round; points
  within 20 points of the centre add nothing). On release exactly one `compass.turn` of the nearest whole number of
  bearings, wrapped into −47 … 48, is sent — nothing when it is 0.
- **Press to probe.** A touch that ends within 10 points of where it began is a tap; inside the hub (the projected disc
  of 0.3 world units, at least 30 points) it sends one `compass.probe`. A double tap outside the wheel resets the view.
- **Orbit.** Two fingers orbit: yaw ±40° about the z axis and tilt 15° … 60° from it (authored 35°), refitted so the
  1.45 sphere stays inside every view; presentation only, never in the digest, snapshot or kernel. A second finger
  cancels a swipe.
- **Panel.** Turn ±1 and ±4, Probe, a band picker with Select, Undo, Redo, Next level and Reset view; all 100 certified
  levels are won through these actions alone (a witness turn of k becomes ⌊|k|/4⌋ presses of ±4 and |k| mod 4 of ±1).

## Teaching and progression (feature 335, R02-G04-05)

- **Tutorial.** Levels 1 … 3 (in every mode) show one instruction at a time: aim (until a turn), probe (until a probe —
  "the hue gap counts bands to the target, the fog depth sums the fog between"), select (until the level ends);
  `tutorial.dismiss` ends it; undo never moves it back.
- **Hints.** A hint reasons only from the clues seen: the consistent set is every candidate whose clues at the probed
  bearings equal those seen. When one selection accepts the whole set the hint names it; otherwise, with at least two
  units left, a probe at the first bearing that settles the set (else the one that splits it best); with one unit left,
  the selection accepting the most candidates ("best guess"). Three levels: what, where (an eighth of the compass, north
  = bearing 24), exact. Following exact hints wins every certified level within its allowance.
- **Failures.** A miss names the target's bearing and band and how far the selection was from each; an exhausted
  allowance says the last unit went to a probe. Probes and selections cannot be undone, so the level is retried.
- **Progress.** Level 1 is open; a campaign win opens the next; each level keeps its fewest units spent and its stars
  (3 at most the certified smallest probe count + 1 units, 2 at most + 2, else 1). The daily level is (days since
  2026-01-01 × 47) mod 100 + 1 and opens nothing; practice raises the allowance to 24 and records nothing. Progress, the
  mode and the tutorial step are in snapshot schema 2 (migrated from 1); `level.select`, `mode.daily`, `mode.practice`,
  `mode.campaign` and `tutorial.dismiss` are the new controls, with `r02-g04.locked` and `r02-g04.date` refusals.

## Polish and accessibility (feature 336, R02-G04-06)

- **VoiceOver.** `HueCompassFeedbackPlan` turns every change into one announcement through the shared feedback route:
  a turn ("Bearing 12 of 96, band 4. Units left 9 of 11."), a probe ("Probe at bearing 12: hue gap 3 bands, fog depth 14.
  Units left 8 of 11."), undo and redo (prefixed "Undone: " / "Redone: "), a band pick ("Band 6 picked."), a win with stars
  (none in practice), a failure with its explanation, a level or mode change with the tutorial instruction, and every
  refusal in words (the panel shows the same words). Announcements count the units left of the allowance; the win names the units spent. Every clue is spoken
  as numbers, so no colour needs to be seen. Every control has a label and a value; a summary element ("Compass") reads
  the bearing, band, units and last clue ("No clues yet." before a probe); the band stepper is adjustable; rows become
  columns at accessibility text sizes; texts wrap; the panel keeps a 520-point readable width.
- **Haptics.** Selection for an accepted turn, probe, undo or redo; success for a win; warning for a failure; error for
  a refusal; band picks, level changes and swipe previews play none. An action that ends the play (a selection, or a
  probe that spends the last unit) plans only the outcome.
- **Comfort.** `HueCompassLights` eases each probe mark (keyed by its bearing), the selection mark, the target ring and
  the win glow over 0.15 s, or 0.45 s under Reduce Flashing where a started fade finishes before it turns back. A mark
  that disappears (a retry, a level change) shrinks where it was; a selection or ring wanted at another bearing fades out
  and then in. The marks' size follows the eased level (`markPart(_:lights:)`; without lights it is feature 333's mesh
  exactly) and the win glow raises the needle's glow-shell gain up to twice the standard gain, still clamped by the
  Reduce Flashing cap of 0.5. A still drawn at a time that does not advance settles, so it shows the state asked for.
  The fog drift stays at 0.1 Hz and is still under Reduce Motion. Measured: at most 3 half-range crossings per second
  and fades of at least 0.4 s.
- **Sound.** An optional ambient loop (Sound toggle, off by default) from `HueCompassSoundRecipe`: a root at 110 Hz, a
  partial at 110 Hz × (1 + g / 12) for the last clue's hue gap g (rounded to whole cycles of the 8-second loop, a unison
  with no clue or g = 0), a fifth, the loop gain lowered by fog depth (1 − 0.4 · min(d, 90) / 90), an octave when won,
  halved when failed; `HueCompassSound` plays it only while wanted, on screen and active, and rebuilds it only at level
  openings, new clues, play ends and when turned on.

## Persistence and replay (feature 337, R02-G04-07)

- **Saving.** The app's shared saved-state store writes one atomic `state.json` per experience, quarantines an
  unreadable file and refuses a newer schema; Hue Compass's snapshot is schema 3 `{level, mode, progress, records,
  tutorial}`, migrating 1 → 2 → 3 (2 → 3 gives every result an empty trace, unverified). Digest
  "r02-g04.hue-compass.v3".
- **Reconcilable scores.** A campaign or daily win stores its fewest units, stars and winning trace — the play's net
  actions (turns, probes and the selection; an undone turn left out, so the trace never needs an undo) — marked
  verified, replacing a result only with fewer units. On restore `HueCompassReconciliation` replays every traced result
  on a fresh play of its certified level and keeps it only if it wins having spent exactly its units with its stars; a
  trace over 1,176 actions or with an illegal action never verifies. Dropped results are counted and announced once
  ("1 saved result could not be checked and was removed."); untraced (schema-2) results are kept unverified; the
  frontier is restored as saved.
- **Replay.** `replay.start [level]` opens mode `replay(level)` for a verified traced result
  (`r02-g04.no-replay` otherwise); `replay.step` applies the next action (`r02-g04.replay-end` after the last);
  `replay.stop` returns to campaign. During replay every other action except `tutorial.dismiss` is refused
  (`r02-g04.replay`, "Stop the replay first."); a replayed win records nothing and claims no stars. The panel offers
  "Replay best solution", then Step and Stop with the position.

## Regression net (feature 338, R02-G04-08)

- **Solver regression.** For all 100 levels the generated level equals its witness, the witness's actions replay to a
  win with their recorded clues and fingerprints, and the solver re-finds the certified smallest probe set, which
  settles the level, with work at most 4,657 probe sets and equal to the certified work (largest 3,533); fourteen kinds
  of alteration (the hue offset, a fog density, the target, the start, the bearing tolerance, the band tolerance, the
  allowance, a solution probe, a witness action, a clue, the near miss, the ambiguity, a recorded fingerprint, the level
  fingerprint) each fail naming the level and the part.
- **Golden frames, made by code.** `HueCompassGolden` (test builds only; forbidden in Release) describes 16 frames
  (levels 1, 21, 41, 61, 81 at three tiers after their witness probes, plus the hero frame) at 1,152 × 768: the
  projected needle tip, the 24 band colour samples with their colours, the probe marks, the selection mark and ring when
  present, palette colours and tier detail, pinned with SHA-256 digests in `golden-frames.json`; an unequal digest falls
  back to one 1/8-pixel quantum. The simulator renders the same frames and checks them with the feature-333 tolerances.
  Regenerate on purpose with `HUE_COMPASS_WRITE_GOLDEN=1`.
- **Memory.** Twelve open-draw-warn-close cycles stay within 16 MB of the first when run alone (measured 28.75 …
  29.14 MB); the compass scene holds no renderers after each warning and close (`liveObjectCount`).
- **Running it.** CI runs the host part as "Hue Compass regression (host)"; locally
  `python3 scripts/hue_compass_regression.py` runs host and simulator parts with one summary.

## In-app integration (feature 339, R02-G04-09)

- **Identifiers.** Every panel control carries `experience.r02-g04.hue-compass.<name>` (`HueCompassControls.identifierNames`,
  23 names: the four turn buttons, probe, band-picker, select, undo, redo, next-level, reset-view, hint,
  dismiss-tutorial, retry, campaign, daily, practice, replay, replay-step, replay-stop, level-picker, sound, summary).
- **Interface tests.** `HCPlayUITests` wins level 1 through the panel (the witness's turn of −27 as six presses of −4 and
  three of −1, Probe, a turn of −20 to bearing 84, the band stepper up to band 11, Select: 3 of 3 stars, level 2 open)
  and keeps the progress over a relaunch; `HCReplayUITests` replays the win to its end and stops. They run as serial
  chunk `m3`, each under 90 s (about 24 s of each is the app's teardown).
- **Stored examples.** The registration stores schema-1 and schema-2 examples (`HueCompassSchemaExamples`), which the
  app restores into schema 3; Hue Compass stays a candidate (not available without `-vcCandidates`) until X-R02-G04.
- **Release.** The Release simulator build compiles without the test-only golden frames and scenarios.

## Device preparation (feature 340, R02-G04-10)

- **Contract, no device touched.** `docs/apps/hue-compass/device-rows.json` (schema 1 of feature 310) names the device
  scenario set (the 11 standard and game scenarios and `fixture-level-1-solved`), the devices D1 iPhone 15, D2 iPad Pro
  13-inch (M5) and D3 iPad (A16) on iPadOS 26.5 tied to DEV1/2/3-R02-G04, and rows HC-D1 … HC-D8: launch and first
  frame, frame pacing per tier, memory and thermal state with the stress session, gesture feel and touch-to-frame,
  sound and haptics, VoiceOver at the largest text size (non-gating), progress across a real termination, and the panel
  journeys. Every row is "pending device campaign"; the written plan is
  [`docs/apps/hue-compass/device-campaign.md`](../apps/hue-compass/device-campaign.md).
- **Check.** `python3 scripts/check_device_rows.py --experience r02-g04.hue-compass` (release step
  `device-rows-r02-g04`) proves every scenario exists, every row is complete and every {device} task of features 331–339
  and every UA-F13 measurement is covered.
