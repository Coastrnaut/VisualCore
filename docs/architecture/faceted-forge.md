# Faceted Forge (R02-G08) — rules

Experience `r02-g08.faceted-forge` (free) of the one VisualCore app; package `Packages/ExperiencesRound02`, target
`FacetedForgeCore` (feature 371, R02-G08-01). A glowing convex crystal is to be split into target pieces. The player
picks a piece, chooses a cutting plane from a fixed set of directions and an integer depth, and commits the cut: the
piece splits into two convex pieces. The level is won when the pieces' shares of the crystal and their face counts match
the target exactly within the cut budget. Everything here is pure, exact rational logic; drawing, controls and sound
come in later features of R02-G08.

## Directions, planes and the crystal

- **Directions.** 13 directions with components in {−1, 0, 1}, named in words: the axes x, y, z, the six face
  diagonals (x+y, x−y, x+z, x−z, y+z, y−z) and the four body diagonals (x+y+z, x+y−z, x−y+z, −x+y+z)
  (`FacetedForgeDirection.all`).
- **Half-spaces.** sign·(n·p) ≤ sign·depth with an integer depth −24 … 24: sign +1 is the side below the plane
  n·p = depth, sign −1 the side above (`FacetedForgeHalfSpace`).
- **The crystal** is the intersection of 4 … 14 half-spaces, a closed solid inside the box −6 … 6 on every axis; the
  level adds the cut budget (1 … 12), the sliver limit (a share 0 < s < 1/2) and the target (at least two entries of a
  share and a face count 4 … 26, shares summing to one).

## Exact pieces

`FacetedForgePiece` is given by its bounding half-spaces and keeps only those that are faces. Its corners are the
points where three planes meet and every plane holds; a corner solves three planes whose normals have components in
{−1, 0, 1}, so its denominator divides 12, and every predicate runs on the corners scaled to integers. A face is a plane
with at least three corners, ordered anticlockwise around the outward normal; the volume is the sum of signed
tetrahedra from the first corner over a fan of each face (`FacetedForgeFraction`, checked 64-bit fractions; an
overflow refuses the action). After every cut the volumes sum to the crystal's and every edge lies on exactly two faces
(the truth metric). Pieces are kept in canonical order: volume descending, then face count descending, then the sorted
corners (`FacetedForgePiece.canonical`).

## Cuts and verdict

`cut(piece, direction, depth)` splits piece k into its below and above halves; it is refused (`r02-g08.miss`) unless a
corner of the piece lies strictly on each side of the plane, so no degenerate face can arise. After a cut, in this
order: **sliver** (a new piece whose share is strictly below the sliver limit fails the level, naming the piece and the
cut; equal is allowed), **win** (the multiset of (share, face count) equals the target), **budget** (cuts spent equal to
the budget: failed). A win on the last cut counts, and nothing is judged before the first cut.

## Play

`FacetedForgePlay` moves through loading, tutorial, playing, paused, won or failed and result. Every accepted cut spends
one cut; a refused action spends nothing. An action is checked in this order — stage, previous fingerprint, range, miss
— and refused without change (`r02-g08.stage`, `.stale`, `.action("range")`, `.miss`). Every accepted action, undo and
redo appends a record with the previous and next play fingerprints (SHA-256 of the schema, level fingerprint, pieces,
cuts, stage and failure). Every cut can be undone and redone; undo works in playing, paused and failed (a failed play
returns to playing) and gives the cut back, and a won play is final. A record trace replays to the same records and
outcome (`FacetedForgePlay.replay`).

## Stored form and contract

Levels are JSON schema 1 with sorted keys and their fingerprint; decoding re-checks every rule and the fingerprint and
refuses damaged, edited and newer forms (`r02-g08.malformed`, `.newer-schema`). `FacetedForgeRules` expresses the game
as an R02-F23 `PuzzleRules`: while playing, the moves are every non-degenerate cut — pieces in canonical order,
directions 0 … 12, depths ascending.

## Content pipeline (feature 372, R02-G08-02)

- **Manifest.** `FacetedForgeManifest` holds the 100 planned levels of the archived design (number, planned seed, band
  1 … 5, move budget 8 … 19). The kernel's ranges were widened additively for it: budget 1 … 20, target faces 4 … 34.
- **Generator.** Candidate k of a level draws from `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: k))`:
  the band's crystal (a cube, a box, a cube with one corner cut, an octahedron, a cube with two opposite corners cut),
  the number of cuts (band b: b + 1 … b + 2), then each cut's piece, direction (bands 1 … 2: axes and face diagonals;
  bands 3 … 5: all 13) and a depth from the middle half of those that cross it. The target is the resulting multiset
  of (share, face count); the sliver limit is 1/64. A candidate is kept when every share is at least 1/32, bands 3 … 5
  drew a body diagonal and the solver certifies it; at most 256 candidates, then `r02-g08.generation`.
- **Solver.** A target of P pieces needs at least P − 1 cuts (each cut adds one piece); `FacetedForgeSolver` finds a
  sequence of exactly P − 1 cuts from the crystal alone, depth-first in the rules' order, keeping only cuts whose
  pieces can still be partitioned into the target by exact shares (and face counts for single entries). Work is
  counted in cut evaluations and bounded at 20,000. The whole catalog certifies in about 15 s on a debug host build.
- **Witnesses.** `docs/games/faceted-forge/levels/NNN.witness.json` holds each level, its cuts, the state digest after
  every cut, the play fingerprints, the smallest cut count with its lower bound, the near miss (one cut short, not won),
  the difficulty and the candidates skipped; decoding re-verifies and refuses damaged, newer or edited files
  (`r02-g08.witness`). The catalog digest is pinned in `FacetedForgeCatalogTests`.

## Experience and renderer (feature 373, R02-G08-03)

- **Adapter.** `FacetedForgeExperienceCore` opens certified level (seed mod 100) + 1 and accepts `piece.cut [piece,
  direction, depth]` (declared 0 … 20, 0 … 12, −24 … 24; a play has at most budget + 1 pieces), `play.undo`,
  `play.redo` and `level.next`; values out of range or fractional and kernel refusals change nothing. Each level is
  certified once per process, directly from its certified candidate (the witness's `skipped`, pinned by a catalog test),
  so opening a level runs the solver once. Its digest is the level number and the play fingerprint; snapshot schema 1
  `{level, records}` restores by replay.
- **Snapshot.** The presenter draws an immutable `FacetedForgeSceneSnapshot`: every piece's corners in world space (the
  crystal's corner centroid subtracted, divided by its largest centroid-to-corner distance, so every crystal fits the
  unit sphere), its faces in the kernel's corner order with a cut flag (a face whose plane is not one of the crystal's
  half-spaces), the preview choice and the chosen piece's cross-section, stage, failure, cuts, budget, level number and
  presentation time. The preview choice (piece, direction, depth) is presentation state of the controls: it starts at
  piece 0, the plane facing the camera (direction z, since R02-G08-04) and the middle crossing depth and is clamped
  to the play after every change.
- **Scene.** Each piece is a bevelled convex solid built from its exact faces and moved away from the crystal's centre
  towards its own centroid by 0.12 (0.2 when won), eased over 0.4 s (at once under Reduce Motion), so the crystal opens
  like a blossom; cut faces glow amber to ruby under a lattice, original faces are ice glass; the preview is a ruby
  polygon with a dashed rim; a sliver piece carries a cross; a row of budget bars (spent ones ruby) sits in front of the
  crystal at y = −0.45, raised from the ground plane (y = −1.3) so the row fits the view. The camera looks from +z,
  pitched 30° down, fitted to a bounding sphere of radius 1.45 with a 5 % margin for aspects 0.4 … 2.5.
- **Shaders.** GLSL ES 3.00 on the shared `ShaderMeshRenderer`: the crystal program carries the material code and shade
  in uv (on the preview, the rim coordinate) and draws translucent ice glass with fresnel and up to three faux-dispersion
  bands moving with presentation time, incandescent cut faces with a procedural lattice and the dashed preview rim; the
  glow program carries the colour in the normal slot. Reduce Motion holds the shimmer still; Reduce Flashing caps the
  glow.
- **Tiers.** level-0: 3 bevel segments, 3 dispersion layers, 2 glow shells; level-1: 2, 2, 1; level-2: 1, 1, 0. Pieces,
  faces, the preview, marks and the camera never change between tiers; each tier change is logged with its reason. A
  program that fails to compile draws the level-2 geometry unlit and keeps its reason. Depth testing is off on this
  path, so pieces and their faces are emitted back to front and back faces are culled.
- **Candidate.** Registered in `Catalog/registrations.json` (100 levels, digest ceb59042…a924c) and linked into the one
  app; it stays unavailable until X-R02-G08. Its scenario manifest has the standard scenarios, `full-playthrough`,
  `hero`, three fixtures and the 80 acceptance rows R2-G08-QA-001 … 080 (row r opens level (7 × (r − 1)) mod 100 + 1);
  its scripted cuts other than certified ones are neutral cuts (the largest piece at its middle crossing depth, kept only
  when the play stays in play), derived by playing them.

## Gestures and camera (feature 374, R02-G08-04)

- **Picking.** A touch is picked once at touch-down with the ray through the drawn camera: the preview's rim (within 22
  points of its projected outline), then the preview plane, then the nearest opened face of a piece, then a projected
  piece centre within 22 points. Less than 10 points of travel is a tap, at least 16 a drag; 10 … 16 does nothing.
- **Choose, tilt, slide.** A tap on a piece chooses it (at the middle crossing depth). A drag on the rim tilts the plane:
  the normal follows the drag in the camera's right and up directions and snaps to the nearest of the 13 directions
  (largest |dot|, ties to the lower index), the depth keeping the plane through the same preview centre (n·c snapped to
  1e-6 and rounded half away from zero, then the nearest crossing depth). A drag on the plane's interior is the depth
  slider: 24 points per crossing depth along the projected normal. All of this is presentation state; the scene draws
  the candidate while the finger moves, and a second finger or a cancel drops it.
- **Commit.** A tap on the plane while playing sends one `piece.cut` with the current choice, never twice within
  0.35 s; on a finished play it sends nothing and the panel says the play is over.
- **Camera.** Two fingers orbit: yaw ±40° (90° per view width), pitch 10° … 60° (60° per view height), authored (0,
  30°); a double tap on empty space or "Reset view" returns to the authored view. Every camera fits a framing sphere of
  radius 1.65 (the opened crystal and the cut-mark row) with a 5 % margin, and the pieces and faces are emitted back to
  front for the orbit's eye, since depth testing is off.
- **Panel.** Every gesture has a panel path (piece and direction pickers, depth − and +, Cut, Reset view); a host test
  wins all 100 certified levels through panel presses alone.

## Teaching and progression (feature 375, R02-G08-05)

- **Tutorial.** Levels 1 … 3 show one instruction at a time in the panel: aim and cut, then match the target's shares
  and face counts without a sliver, then finish within the cuts; each advances on an accepted new cut (a redo or an
  undo never moves it) and ends with the level; Dismiss ends it. The step is snapshotted but not digested.
- **Hints.** "Hint" reveals three levels for the current play: which piece, then the direction, then the exact depth.
  The plan is the first cut of a winning continuation of exactly the missing pieces, found by the solver's bounded
  depth-first search started at the current pieces (`FacetedForgeSolver.solve(_:from:cutsLeft:workBound:)`), so
  following hints wins every certified level; a state with no continuation found in the cuts left says so. A hint can
  take the solver up to its work bound, so it is computed only when asked and cached for the shown play.
- **Failures.** A sliver names its cut, piece and share against the 1/64 limit; a budget failure names the cuts spent
  and the pieces against the target; both offer Undo and Retry.
- **Progress.** Level 1 open, a campaign win opens the next; stars by cuts made (undone ones included, since every win
  spends exactly the lower bound): 3 at the certified smallest, 2 within + 2, else 1. The daily level is (days since
  2026-01-01 × 67) mod 100 + 1 from the local date the presenter sends; practice replays a copy of the level with the
  budget raised to 20 and records nothing. Snapshot schema 2 `{level, mode, progress, records, tutorial}` with a
  migration from schema 1.

## Polish and accessibility (feature 376, R02-G08-06)

- **VoiceOver.** Every accepted cut, undo and redo is announced with the pieces now and the cuts left ("Piece 1 cut in
  direction z at depth 0: 2 pieces now. 9 cuts left."); a win or failure as an outcome (stars, or the failure
  explanation); level and mode changes with the band and the tutorial; refusals in words. Preview choices are not
  announced: the piece, direction and depth pickers are adjustable elements that speak their values, and a "Crystal"
  summary element reads the cuts left, every piece, the target and the next cut. Texts are a pure function of the
  core before and after (`FacetedForgeFeedbackPlan`), so tests compare them exactly.
- **Haptics.** Selection for a cut, undo or redo; success for a win; warning for a failure; error for a refusal; a cut
  that ends the play plans only its outcome; all through the shared route and the person's switch.
- **Comfort.** The cut-face glow (0.7 playing, 1 won, 0.35 failed) and the sliver cross (0 or 1) ease in presentation
  time, 0.15 s or 0.45 s under Reduce Flashing without turning back mid-fade (`FacetedForgeLights`); the dispersion
  shimmer stays below 0.4 cycles per second and is still under Reduce Motion with the opening at rest. The glow is
  measured over its whole 0 … 1 gain range.
- **Sound.** An optional ambient loop, off by default: a 110 Hz root and one just-intonation partial per piece beyond
  the first (up to four), an octave and a second swell when won, halved when failed, 12 s with whole cycles; it plays
  only while wanted, on screen and active (`FacetedForgeSoundRecipe`, `FacetedForgeSound`).
- **Panel.** System text styles that grow to the largest accessibility size, rows that become columns there, wrapping
  text, a 520-point readable width on iPad.

## Persistence and replay (feature 377, R02-G08-07)

- **Saves.** The one app's shared saved-state store writes the experience snapshot atomically; this feature defines it:
  schema 3 `{level, mode, progress, records, sound, tutorial}`, migrated from schema 1 (`{level, records}`) through 2.
  The 2 → 3 step gives every result an empty trace, marks it unverified and turns the sound off. The digest
  ("r02-g08.faceted-forge.v3") covers the level, the play, the progress and the mode, never the sound choice or the
  count of dropped results.
- **Reconcilable scores.** Each campaign or daily win stores its fewest cuts made (undone cuts included), its stars and
  the winning trace: the effective cuts of the play (a cut that was undone and not redone is left out). On restore,
  `FacetedForgeReconciliation` replays every traced result on a fresh play of its certified level and keeps it only if
  the play wins, the trace is no longer than the stored cuts made and the stars equal the stars rule for them; a trace
  of more than 32 cuts or with an illegal cut never verifies. A lowered cuts made can never claim fewer cuts than the
  trace proves, and a raised one only worsens the score. Edited results are dropped and counted, and the presenter
  announces the count once; untraced results from older saves are kept as unverified; the frontier is restored as saved.
- **Replay.** `replay.start [level]` plays a verified result's trace from a fresh level, `replay.step` applies its next
  cut and `replay.stop` returns to the campaign. During replay every other play action is refused ("Stop the replay
  first."), progress never changes and a replayed win claims no stars; the panel shows "Replay: cut k of n" with Step
  and Stop.
- **Settings and determinism.** `settings.sound [0 … 1]` saves the sound choice, applied when the experience opens. The
  state reads no clock or random source: the seed, the certified catalog, the date given to `mode.daily` and the
  recorded actions decide everything, so a save restores and replays identically on every device.

## Regression net (feature 378, R02-G08-08)

- **Solver.** For all 100 levels, in tests of 10: the generated level equals its witness's level, the witness's cuts
  replay to a win in its smallest cut count within the budget with its per-cut digests and fingerprints, and the solver
  returns exactly the witness's cuts with the smallest cut count equal to the lower bound; its work stays within the
  solver's work bound. Ten kinds of alteration (a crystal half-space, the budget, the sliver limit, a target piece's
  share or face count, a solution cut, a witness cut, a per-cut digest or fingerprint, the smallest cut count) each fail
  naming the level and the part. Work is counted, never timed.
- **Golden frames.** `FacetedForgeGolden` (test builds only; forbidden in the Release binary) describes 16 frames —
  levels 1, 21, 41, 61, 81 at three tiers after their certified solution's first min(smallest − 1, 2) cuts, fully
  opened, plus the hero frame — at 1,152 × 768: every projected piece centre and the preview centre (to 1/8 px, null off
  screen), the cuts spent and the budget, the tier's detail and the palette. The descriptions and SHA-256 digests are
  pinned in `golden-frames.json`; a recomputed description passes on an equal digest or within one quantum with
  everything else equal, and the file is rewritten only with `FACETED_FORGE_WRITE_GOLDEN=1`. The simulator renders the
  same frames and checks them with the feature-373 frame tolerances.
- **Memory.** Twelve open-draw-warn-close cycles on the simulator keep the footprint within 16 MB of the first cycle
  (bound applied when the class runs alone) and leave the crystal scene holding no GPU objects (`liveObjectCount` 0)
  after each close and memory warning.
- **Where it runs.** CI's host job has a named "Faceted Forge regression (host)" step; locally,
  `python3 scripts/faceted_forge_regression.py` runs the host and simulator parts with one summary line each.

## In-app integration (feature 379, R02-G08-09)

- **Identifiers.** Every panel control carries `experience.r02-g08.faceted-forge.<name>`
  (`FacetedForgeControls.identifierNames`, 24 names: cut, undo, redo, next-level, depth-down, depth-up, reset-view,
  hint, dismiss-tutorial, failure-undo, retry, campaign, daily, practice, play-level, replay, replay-step, replay-stop,
  piece-picker, direction-picker, depth-picker, level-picker, sound, summary).
- **Interface tests.** `FFPlayUITests` wins level 1 through the panel (its certified solution: three cuts, each set by
  stepping the piece, direction and depth pickers from their current values and tapping Cut: "The pieces match the
  target", "Stars: 3 of 3", level 2 open) and keeps the progress over a relaunch; `FFReplayUITests` replays the win
  (three cuts) to its end and stops. They run as serial chunk `q3`, each under 90 s. Level 1's certified cuts, smallest
  cut count and the pickers' starting choice are pinned in `FF` and checked against the Core by an app unit test.
- **Stored examples.** The registration stores schema-1 and schema-2 examples (`FacetedForgeSchemaExamples`), which the
  app restores into schema 3 (a schema-2 result without a trace is kept, unverified); Faceted Forge stays a candidate
  (not available without `-vcCandidates`) until X-R02-G08.
- **Release.** The Release simulator build compiles without the test-only golden descriptions and scenarios.
