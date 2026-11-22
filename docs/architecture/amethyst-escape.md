# Amethyst Escape (R02-G07) — rules

Experience `r02-g07.amethyst-escape` (free) of the one VisualCore app; package `Packages/ExperiencesRound02`, target
`AmethystEscapeCore` (feature 361, R02-G07-01). A pearl rests in the innermost of a few nested crystal shells. The player
turns shells one sector at a time and taps to advance the pearl, which rolls outward through an aperture lined up under
it or else one pocket clockwise along its ring; the level is won when the pearl leaves the outermost shell through its
exit gap within the move budget. Everything here is pure, exact integer logic; drawing, controls and sound come in
later features of R02-G07.

## Shells and pockets

- **Sectors.** Every shell has the same N = 6 … 12 sectors; shells are numbered 0 (innermost) … K − 1 (outermost),
  K = 2 … 5, and named "shell 1 (inner)" … "shell K (outer)", sectors "sector s of N", so everything is told apart
  without colour (`AmethystEscapeLevel.description(ofShell:)`).
- **A shell** lists, in its own sectors, its outer apertures (non-empty; the outermost shell has exactly one, the exit
  gap), its radial walls (wall j stands between its sectors j and j + 1 mod N; at most N − 1) and its blocked wedges
  (never every sector).
- **Start and budget.** The pearl starts in shell 0 at a sector that is not blocked, with every shell at offset 0; the
  move budget is 1 … 60.

## The crystal

`AmethystEscapeCrystal` holds every shell's offset o_r (0 … N − 1) and the pearl's pocket (shell r, absolute sector a);
the pocket lies in shell r's own sector (a − o_r) mod N. `rotate(r, ±1)` changes o_r by ±1 mod N and turns the pearl
with it when the pearl is in shell r; rotating another shell never moves the pearl, and N single steps are the
identity. An advance makes exactly one transition from own sector j: through an outer aperture at j the pearl leaves
the outermost shell (exit) or moves to the same absolute sector of the next shell; otherwise, without wall j, it moves
one sector clockwise; otherwise it is stuck and nothing happens. A move that lands on a blocked wedge fails. Which
pockets connect depends only on the current offsets, so nothing is cached across rotations.

## Verdict

After an advance, in this order: **exit** (won), **wedge** (failed, naming the shell and the sector of the pocket);
then, after any accepted move that did not end the level, **budget** (moves spent equal to the budget: failed). An exit
on the last move of the budget wins, and nothing is judged before the first move.

## Play

`AmethystEscapePlay` moves through loading, tutorial, playing, paused, won or failed and result. Every accepted rotation
and advance spends one move; a stuck advance is refused (`r02-g07.stuck`) and spends nothing. An action is checked in
this order — stage, previous fingerprint, range, stuck — and refused without change (`r02-g07.stage`, `.stale`,
`.action("range")`, `.stuck`). Every accepted action, undo and redo appends a record with the previous and next play
fingerprints (SHA-256 of the schema, level fingerprint, offsets, pearl, moves, stage and failure). Every action can be
undone and redone; undo works in playing, paused and failed (a failed play returns to playing) and gives the move back,
and a won play is final. A record trace replays to the same records and outcome (`AmethystEscapePlay.replay`).

## Stored form and contract

Levels are JSON schema 1 with sorted keys and their fingerprint; decoding re-checks every rule (including the sorted
order of every shell's lists) and the fingerprint and refuses damaged, edited and newer forms (`r02-g07.malformed`,
`.newer-schema`). `AmethystEscapeRules` expresses the game as an R02-F23 `PuzzleRules`: while playing, the moves are
rotate(r, +1) and rotate(r, −1) for every shell in order, then an advance unless it is stuck.

## Content pipeline (feature 362, R02-G07-02)

- **Manifest.** `AmethystEscapeManifest` holds the 100 planned levels of the archived design (`python3
  scripts/planning_index.py levels --experience R02-G07`): 20 per band, each with a planned seed and a move budget 8 … 19.
  The chapter's "80 solver-certified stages" is a milestone figure only.
- **Generator.** Candidate k of an entry draws from `SeededRandom(seed: SeedDerivation.derive(seed, index: k))`: the
  band's profile (sectors × shells 6 × 2, 6 × 3, 8 × 3, 8 × 4, 10 × 4), each shell's apertures, walls (35 %) and blocked
  wedges (25 %), then the start. A candidate is kept when advances alone do not escape and the solver proves a smallest
  move count in the band's range (3 … 4, 5 … 6, 7 … 8, 9 … 10, 11 … 12) within the budget, and the witness wins through
  the play; at most 512 candidates (`r02-g07.generation`).
- **Solver.** `AmethystEscapeSolver` searches crystal states breadth-first (every shell offset and the pearl's pocket,
  packed into one integer; shell lists as bit masks) in the rules' move order, never continuing from a blocked wedge. The
  first escape is the shortest route; the states first reached at each smaller depth are the proof. Work counts the
  states expanded (at most N^K × K × N).
- **Witness files.** `docs/games/amethyst-escape/levels/NNN.witness.json` (schema 1): the level, the actions, a state
  digest after every move, the play fingerprints, the smallest count with its depths, the unedited and near-miss
  counterexamples, the difficulty and the skipped candidates. Decoding re-solves and replays them and refuses any edited
  part by name (`r02-g07.witness`); the catalog test compares all 100 with the regenerated witnesses byte for byte and
  rewrites them only with `AMETHYST_ESCAPE_WRITE_WITNESSES=1`. The catalog digest is pinned and the standard progression
  rule holds.


## Experience and renderer (feature 363, R02-G07-03)

- **Adapter.** `AmethystEscapeExperienceCore` opens certified level (seed mod 100) + 1 (each level generated once per
  process, on first use) and accepts `shell.rotate [shell, step]` (step −1 or +1), `pearl.advance`, `play.undo`,
  `play.redo` and `level.next`; values out of range or fractional and kernel refusals change nothing. Its digest is the
  level number and the play fingerprint; snapshot schema 1 `{level, records}` restores by replay.
- **Snapshot.** The presenter draws an immutable `AmethystEscapeSceneSnapshot` (sectors, every shell's apertures, walls,
  blocked wedges and offset, the pearl's pocket, the exit gap's world sector, stage, failure, moves, budget, level number
  and presentation time); it never holds the kernel, so no drawing result can change the game.
- **Scene.** The crystal lies in the xz-plane: with n shells, shell k is the annulus from 0.2 + k·w to 0.2 + (k + 1)·w,
  w = 0.8 / n, and own sector s sits at world sector (s + offset) mod S, angles running from +x towards +z (clockwise
  from above, the kernel's +1). Each wedge is a bevelled prism, taller towards the centre (h_k = 0.08 + 0.06·(n − 1 − k))
  so the crystal rises like a gem cathedral; openings are gaps in a wedge's outer rim, a radial wall is a platinum fin
  between own sectors i and i + 1, a blocked wedge is dark with a raised cross (amber when the pearl fell into it), the
  pearl is the only sphere (radius 0.3·w, drawn on the exit arrow once it escaped), the exit carries a platinum arrow
  and a platinum bar along the near edge shows moves / budget. The camera looks from +z, pitched 50° down, fitted to a
  bounding sphere of radius 1.1 with a 5 % margin for aspects 0.4 … 2.5.
- **Shaders.** GLSL ES 3.00 on the shared `ShaderMeshRenderer`: the crystal program carries the material code and shade
  in uv and draws translucent amethyst facets (alpha 0.55) with shifting specular highlights from presentation time; the
  glow program carries the colour in the normal slot. Reduce Motion holds the highlights still; Reduce Flashing caps the
  glow.
- **Tiers.** level-0: 3 bevel segments, 3 highlight layers, 2 glow shells; level-1: 2, 2, 1; level-2: 1, 1, 0. Wedges,
  walls, pearl, exit and the camera never change between tiers; each tier change is logged with its reason. A program
  that fails to compile draws the level-2 geometry unlit and keeps its reason. Depth testing is off on this path, so
  wedges are emitted back to front and back faces are culled.
- **Candidate.** Registered in `Catalog/registrations.json` (100 levels, digest e65c4529…94e6) and linked into the one
  app; it stays unavailable until X-R02-G07. Its scenario manifest has the standard scenarios, `full-playthrough`,
  `hero`, three fixtures and the 80 acceptance rows R2-G07-QA-001 … 080 (row r opens level (7 × (r − 1)) mod 100 + 1).

## Touch controls (feature 364, R02-G07-04)

- **Turn a shell.** A one-finger drag that starts on a shell (picked at touch-down: the pearl first, then the shells'
  top planes from the innermost outward, else the nearest top-ring midline within 22 points) sums the unwrapped angle
  change of the touch on that shell's plane; on release after at least 16 points it sends one `shell.rotate [k, ±1]`
  per whole sector swept (rounded, the shortest way round, at most ⌊S/2⌋). While dragging, the scene draws the snapshot
  with that shell turned (`AmethystEscapeSceneSnapshot.previewing(shell:sectors:)`) and the description says "Shell k
  would turn n sectors clockwise". Only while playing; a finished play sends nothing and says so.
- **Advance and pick.** A tap (under 10 points, at most 0.5 s) on the pearl sends `pearl.advance`; a tap on a shell
  picks it in the panel; travel between 10 and 16 points sends nothing.
- **Isolate a layer.** A double tap (0.35 s, 22 points) on a shell darkens every other shell to shade 0.25; again on the
  same shell, "Show all layers" or `level.next` clears it. Presentation only.
- **Camera.** Two fingers orbit (yaw ±40°, pitch 30° … 75°, authored 50°; the same tilt direction as Chrono
  Constellator); a double tap on empty space or "Reset view" returns to the authored view. Orbit and isolation never
  reach the digest, the snapshot or the kernel; the snapshot schema stays 1.
- **Tests.** The analytic picker is checked against an independent pick on 2,500 seeded points; the gesture controller
  on 500 seeded scripts against an independent angle and rounding; all 100 certified levels are won through panel
  actions alone; simulator tests send touches through the experience's pointer entry.

## Teaching and progression (feature 365, R02-G07-05)

- **Hints.** `AmethystEscapeSolver.solve(_:from:maxDepth:)` runs the same packed breadth-first search from any crystal;
  `AmethystEscapeHints` takes the first action of the shortest escape that fits in the moves left. Level 1 says what to
  do ("Turn a shell", "Roll the pearl"), level 2 which shell, level 3 the exact turn ("one sector clockwise") or "Roll
  the pearl one pocket". A failed play's hint is "Undo the last move or retry the level."; a state with no escape left
  says so. Hints never change the state, are unlimited and reset after any change of the play. Because the hint is a
  shortest escape, following hints wins whenever any escape fits; tests check this on all 100 levels and on 200 seeded
  states against an independent search.
- **Failures.** `AmethystEscapeFailureExplanation` names the blocked wedge (shell in words, "sector s of N", the move)
  or the moves spent and the pearl's pocket, followed by "Undo the last move or retry the level."
- **Tutorial.** Levels 1 … 3 show three instructions in turn (move, roll the pearl, leave through the exit gap); step 1
  advances on any move, step 2 on an advance, step 3 when the level ends; Dismiss ends it; undo never moves it back.
- **Progress.** Level 1 open; a campaign win opens the next and records the fewest moves with stars (3 at the certified
  smallest move count, 2 within two more, else 1). `level.select` opens any open level (`r02-g07.locked` otherwise),
  `level.next` the next open one (no wrap). The daily level is (days from 2026-01-01 × 61) mod 100 + 1 from a date the
  presenter sends (`mode.daily [y, m, d]`, `r02-g07.date` for an impossible date); daily opens nothing. Practice replays
  the level with the budget raised to 60 and records nothing.
- **Snapshot schema 2.** `{level, mode, progress, records, tutorial}`; progress and mode are digested
  ("r02-g07.amethyst-escape.v2"), the tutorial step is not; schema-1 payloads migrate (levels up to the saved one open,
  campaign mode, the tutorial at its first step).
- **Panel.** The tutorial with Dismiss, Hint (each press reveals the next level), the failure text with Undo and Retry,
  the goal and stars, Campaign / Daily / Practice and a picker of open levels, all as wrapping text below the crystal.

## Polish and accessibility (feature 366, R02-G07-06)

- **Feedback.** `AmethystEscapeFeedbackPlan` derives every announcement and haptic from the old and new core: turns
  ("Shell 2 turned one sector clockwise. 7 moves left."), advances, undo and redo (`state`, selection haptic), wins and
  failures (`outcome`, success or warning, only the outcome when a move ends the play), level and mode changes (`level`)
  and refusals in words (`rejection`, error). A drag that turns a shell several sectors is announced once after its last
  turn. The presenter routes plans through the shared `ExperienceFeedback` and keeps a feedback log.
- **Reduce Flashing.** `AmethystEscapeLights` eases the pearl glow (1 playing, 0.6 failed), the exit glow (0.5, 1 once
  escaped) and the failed wedge's amber (0 or 1) over 0.15 s, 0.45 s under Reduce Flashing, where a fade that has
  started finishes before it can turn back. The lights settle only on the first frame; every later change fades,
  including a level change, so flipping levels cannot flash. Tests sample a scripted win and five flicker patterns
  every 1/60 s: at most 3 half-range crossings per second and fades of at least 0.4 s. The facet highlights stay at
  about 0.29 cycles per second and are still under Reduce Motion. None of this reaches the state or its digest.
- **Sound.** `AmethystEscapeSoundRecipe` builds a 12-second loop from the pearl's progress: a 98 Hz root and one partial
  per shell passed (5/4, 3/2, 2, 5/2); a won loop adds the octave and swells twice per loop (once otherwise), because the
  octave equals the third shell's partial and a won chord would otherwise sound like a deeper level's playing chord; a
  failed loop halves its gains. The loop plays only while the Sound toggle is on, the panel is on screen and the scene is
  active.
- **Panel.** Every control has a label and value; the shell picker is adjustable ("Shell to turn", "Shell 4 (outer),
  turned 1 of 8"); a summary element reads the moves left, the pearl, the exit gap and every shell; rows become columns
  at accessibility text sizes and the panel keeps a 520-point width on iPad.
