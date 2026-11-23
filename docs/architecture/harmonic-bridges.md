# Harmonic Bridges (R02-G12) — rules

Experience `r02-g12.harmonic-bridges` (free) of the one VisualCore app; package `Packages/ExperiencesRound02`, target
`HarmonicBridgesCore` (feature 411, R02-G12-01). Islands are joined by suspended strings while the level sounds a few
tones. Turning a string's tuning peg changes its pitch; when one of its harmonics matches a sounding tone the string
swells into a standing wave, and where the wave's averaged swing is strong enough along the whole string it becomes a
walkable bridge. The player tunes strings and tests a crossing: if bridges join the start island to the goal island in
every step of the crossing window, the level is won. Everything here is pure, exact integer logic; drawing, controls
and sound come in later features of R02-G12.

## Islands, strings and tones

- **Islands.** 2 … 8, each with a drawing position on a 16 × 10 grid that never decides a rule; a start and a goal
  island (distinct).
- **Strings.** 1 … 12, each joining two distinct islands (no two strings join the same pair), with a length L in 1 … 6, a
  peg value p in 1 … 12 and a locked flag (a locked string's peg cannot be turned).
- **Crossing window.** 1 … 4 steps; each step sounds 1 … 3 tones of distinct frequencies F in 1 … 72, each with a
  strength w in 1 … 3. The solidity threshold θ is 1 … 12 and the action budget 1 … 60.

## Resonance, swing and bridges

- **Resonance.** A string's harmonics are n · p / L for n in 1 … 5; a tone F resonates mode n exactly when
  n · p = F · L (`HarmonicBridgesString.mode(of:peg:)`). A tone matches at most one mode.
- **Swing.** The law y(x, t) = Σ A_n sin(nπx/L) cos(ω_n t + φ_n) is sampled at the five interior points k = 1 … 5 of six
  equal segments, where 4 sin²(nπk/6) is always 0, 1, 3 or 4 (`HarmonicBridgesSwing`: mode 1 and 5 [1, 3, 4, 3, 1],
  modes 2 and 4 [3, 3, 0, 3, 3], mode 3 [4, 0, 4, 0, 4]). Tones of one step have distinct frequencies, so the
  time-averaged mean square is the sum of each resonating tone's: E(k) = Σ w · q(n, k), an exact whole number of
  quarters (at most 36).
- **Bridges.** A string is a bridge in a step exactly when E(k) ≥ θ at all five samples. The bridges of a step form a
  graph on the islands; the start's reachable set is found breadth-first, islands in index order (`HarmonicBridgesReport`).

## Actions and verdict

`tune(s, p)` sets string s's peg to p and spends 1 action; `test` spends 1 action and decides the crossing; `pluck(s)` is
a query that names the string, its resonances and swings per step in words and changes nothing. Refused without change:
an unknown string, a peg outside 1 … 12 or a locked string (`r02-g12.action`); a tuning to the current peg (`.noop`);
the wrong stage (`.stage`) and a stale fingerprint (`.stale`). A test wins when the goal is reached in every step, even
on the last action of the budget; otherwise it fails with the first step whose path is missing and the broken string,
the lowest-index non-bridge string joining an island the start reaches to one it does not (none when no string crosses).
After a tuning, a spent budget without a win fails the level (`budget`). Undo and redo spend nothing and restore the
exact earlier state; undo from failed returns to playing (recorded); a won level is final.

## Measures

After every action the play reports every string's swing per sample and step, the bridges per step and the start's
reachable set per step (the mode amplitude envelope and the bridge graph's connectivity); they never decide the outcome
on their own. Every resonance, swing, bridge and reachable set agrees with an independent recomputation in the tests.

## Stored form

Levels are JSON schema 1 with sorted keys (islands as [x, y], strings as [a, b, length, peg, locked], start, goal, steps
as lists of [F, w], threshold, budget, difficulty, tutorial, seed, id) and their fingerprint; decoding re-checks every
rule and the fingerprint and refuses damaged, edited and newer forms (`r02-g12.malformed`, `.newer-schema`).

## Content pipeline (feature 412, R02-G12-02)

- **Manifest.** The 100 planned levels of the archived design (`HarmonicBridgesManifest`): number, planned seed, band
  1 … 5 (20 each) and moves budget 8 … 19.
- **Generator.** Candidate c of entry n draws from `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: c))` and
  is built constructively: a scrambled count k in the band's range, a path of k or k + 1 strings from island 0 to the
  last island, the steps and their tones (frequencies from 6, 12, 18, 24, 30, 36, 48, 60, 72, strengths 1 … 3), a
  threshold, a (length, peg) for every path string that is a bridge in every step, k path strings scrambled to a peg that
  is not, decoys on unused pairs (locked with chance 3 in 10), all shuffled. Band profiles: scrambled 1 … 2 up to 5 … 6,
  steps 1 up to 3 … 4, thresholds 1 … 3 up to 3 … 6; tutorial on levels 1 … 3. A candidate is kept when its minimal plan
  has a tuning count in the band's range and at most budget − 1, and the witness wins through the play; at most 256
  candidates (`r02-g12.generation`). The ranges were measured with a prototype before they were written down; over the
  catalog the band means are 1.65, 2.45, 3.4, 4.5 and 5.35 tunings.
- **Minimal plan and proof.** For every string and peg the bridge pattern (the steps in which it is a bridge); a retuned
  string's options are the maximal patterns among its other pegs not contained in its current pattern, each by its
  lowest peg (bridges only ever help reachability, so nothing smaller is missed). `HarmonicBridgesSolver.plan` tries 1 …
  6 retuned strings, subsets in lexicographic order and the product of their options, and returns the first winning
  choice; the choices tried at smaller sizes are the minimality proof. Work (choices) is bounded at 400 000; the largest
  catalog plan used 242.
- **Witness files.** `docs/games/harmonic-bridges/levels/NNN.witness.json` (schema 1, sorted keys): the level, the actions
  (tunings in string order, then a test), a bridge digest after each tuning, the play fingerprints, the counterexample
  (the size one below and the choices tried, none winning; for a one-tuning plan the starting pegs' break), the
  difficulty and the candidates skipped. Regenerated only with `HARMONIC_BRIDGES_WRITE_WITNESSES=1`; decoding re-runs the
  replay, the recount and the plan (`r02-g12.witness`).
- **Catalog.** `PuzzleCatalog<HarmonicBridgesRules>.digest(id: "harmonic-bridges", …)` over the 100 fingerprints is
  pinned; the standard progression rule holds on the witness tuning count; an independent brute force (every peg in
  bands 1 … 3, every pattern in bands 4 and 5) re-checks minimality on two levels per band.

## Hero renderer and experience (feature 413, R02-G12-03)

- **Scene.** The islands stand on the plane y = 0: island (gx, gy) of the 16 × 10 drawing grid is at
  X = (gx − 7.5)·0.12, Z = (gy − 4.5)·0.12, a hexagonal copper prism (radius 0.07, height 0.1) with warm edge strips;
  the start has a ring and the goal a four-pointed violet star. Every string is a strip between its islands' top centres
  at y = 0.1 carrying five sample marks at u = k / 6: a filled square exactly where the kernel's swing reaches the
  threshold, a hollow ring where it does not. A string that is a bridge in the shown step has a cyan membrane beneath
  it; every island the start reaches has a glow ring. In front lie a pip per window step and the moves gauge (one bar per
  action of the budget, lit for the actions left) (`HarmonicBridgesSceneGeometry`).
- **Steps and wave.** The shown step cycles every 1.2 s (`HarmonicBridgesSceneSnapshot.shownStep`); a broken test holds
  the broken step, outlines the broken string in #FF6B4A and crosses its pip. The strings' swing is a presentation wave
  applied in the vertex shader, Σ 0.01·wᵢ·sin(nᵢπu)·cos(2πnᵢt / 1.6) over the step's resonant modes and tone
  strengths, packed per vertex as m₀ + 24·m₁ + 576·m₂ with mᵢ = 4nᵢ + wᵢ; it never decides a bridge or a mark, which
  come from the kernel's exact report (`HarmonicBridgesShaders`).
- **Order and shading.** Depth testing is off: the bridge mesh is in painter's order (ground, flat rings, membranes,
  wave shells, strings with their outline and marks, islands back to front and from the outside in, pips and gauge);
  the glow mesh is drawn last, additively. A won level brightens every bridge and reached island through a per-vertex
  flag without moving anything.
- **Tiers.** level-0: string motion, two wave shells per resonating string, two glow shells; level-1: motion and one
  glow shell; level-2: none. Islands, strings, membranes, marks, pips, the gauge, colours and positions are identical
  at every tier; the presenter logs tier changes.
- **Camera.** A fixed authored view from eye (0, 1.9, 1.6) towards (0, 0, 0.1), fitted to the box x −1 … 1,
  z −0.7 … 1.0, y 0 … 0.2 with a 5 % margin for aspects 0.4 … 2.5.
- **Adapter.** `HarmonicBridgesExperienceCore` opens certified level (seed mod 100) + 1 from its table of certified
  candidates and accepts `string.tune` [string, peg], `crossing.test`, `play.undo`, `play.redo` and `level.next`; its
  digest ("r02-g12.harmonic-bridges.v1") is the level number and the play fingerprint; snapshot schema 1.
- **Fallback and settings.** A shader failure draws the level-2 geometry unlit and keeps the reason; Reduce Motion
  draws the resting step at rest; Reduce Flashing caps the glow.
- **Candidate.** Registered in `Catalog/registrations.json` (100 levels, digest b832e7ee…3c737) and linked into the app
  as a candidate (`ExperienceRegistry.candidates`) until X-R02-G12; the scenario manifest holds the standard scenarios,
  `full-playthrough`, `hero`, 80 acceptance scenarios and the fixtures.

## Gestures (feature 414, R02-G12-04)

- **Picking.** At touch-down every target is projected through the drawn camera (orbit included) into view points: a
  step pip whose centre lies within 22 points wins (the nearest, ties to the lower step), then the goal island's top
  centre within 22 points, then the string whose projected segment between its islands' top centres is nearest within
  22 points (ties to the lower string index; overlapping strings on one row of islands are exactly equidistant, so a
  tolerance of 1e-6 points keeps the tie rule); anything else is empty space (`HarmonicBridgesPicker`).
- **Pluck to audition.** A tap (under 10 points, lifted before 0.5 s by event timestamps) on a string chooses it in the
  panel at its current peg and describes its resonance in the drawn step (the modes it sings and how many of its five
  samples reach the threshold); no action is spent, in any stage.
- **Drag the tuning peg.** A drag (16 points or more) from an unlocked string while playing previews the peg
  current + round(upward movement / 24 points), half away from zero, clamped to 1 … 12, and tunes the string to it on
  release when it differs (`string.tune`); a drag that ends without a tune puts the panel's peg back. A drag from a
  locked string or on a stage other than playing only chooses the string.
- **Tap freeze to test.** A tap on the goal island or a step pip while playing sends `crossing.test`.
- **Orbit.** Two fingers orbit (yaw ±35° about the box centre, pitch −15° … +20°) with the field of view refitted at
  every aspect 0.4 … 2.5; a double tap on empty space or "Reset view" returns to the authored view. Orbit, choice and
  preview are never saved and never reach the kernel (`HarmonicBridgesGestureController`); on a won or failed play
  gestures send no kernel action and the panel says the play is over; refusals are shown in words and logged with their
  reason code.
- **Panel.** Every certified level can be won with the string and peg steppers, Tune and Test alone.

## Teaching and progression (feature 415, R02-G12-05)

- **Hints.** From the current state: the solver's minimal plan at the current pegs (`HarmonicBridgesSolver.plan(_:pegs:)`,
  locks kept); the test when the pegs already join the start to the goal in every step, else the plan's first tuning
  (lowest string index), provided the plan's tunings plus the test fit the actions left (and the work bound). Level 1
  names the kind ("Tune a string so that more steps are bridged" / "Every step is bridged: test the crossing"), level 2
  the string, level 3 the peg. A won play has no hint; a failed one suggests undo or retry; a state with no plan in the
  moves left says so. From every opening, following exact hints wins in the certified witness's action count.
- **Failure explanation.** A broken test: "Action m (the test) broke the crossing in step s at string i: the start
  reached the goal in k of n steps." (or no string reaches across); the budget: "Action m (a tuning of string i to peg p)
  spent the last move without a win: …"; actions are numbered from 1, steps and strings from 0, and k is counted at the
  pegs after the failing action (`HarmonicBridgesFailureExplanation`).
- **Tutorial.** Levels 1 … 3: tune → bridge → test → done, advanced by an accepted tuning (straight on to the test step
  when that tuning already bridges every step), the pegs bridging every step, or the level's end; never moved back;
  `tutorial.dismiss` ends it (`HarmonicBridgesTutorialStep`).
- **Progress and modes.** Stars by actions spent (every accepted tuning and test record, undone ones included): 3 at the
  witness's action count, 2 within + 2, else 1; the best result per level; level 1 open and a campaign win opening the
  next; `level.select` and `level.next` only to open levels (`r02-g12.locked`); the daily level (days from 2026-01-01 ×
  83) mod 100 + 1 from `mode.daily [y, m, d]` (`r02-g12.date` for an impossible date), recording but opening nothing;
  practice replays the level with budget 60 and records nothing (`HarmonicBridgesProgress`, `HarmonicBridgesMode`).
- **Stored form.** Snapshot schema 2 `{level, mode, progress, records, tutorial}` with a migration from schema 1 (levels up
  to the saved one open, campaign mode, the tutorial at its first step); progress and mode are digested, the tutorial
  step is not.

## Polish and accessibility (feature 416, R02-G12-06)

- **Announcements and haptics.** `HarmonicBridgesFeedbackPlan.after(old:new:)` plans one announcement and one haptic per
  change: an accepted tuning ("String i tuned to peg p.") or undo/redo, each with "The start reaches the goal in k of n
  steps, a actions left." (`state`, selection); a win ("The crossing holds in every step. Level won spending a actions,
  k of 3 stars.", `outcome`, success); a failure (the explanation of feature 415, `outcome`, warning); level and mode
  changes (`level`); refusals in words (`rejection`, error). A test always ends the level, so it plans only its outcome.
  The presenter routes plans through the shared `ExperienceFeedback` and keeps a feedback log.
- **Lights and comfort settings.** `HarmonicBridgesLights` eases the glow (0.7 playing, 1 won, 0.35 failed) and the won
  brightening of the bridges (through the shader's `u_wonLight`) over 0.15 s, 0.45 s under Reduce Flashing, a started
  fade finishing before it turns back. Under Reduce Motion or Reduce Flashing the resting step is held, the strings
  rest and no wave shell is drawn; neither changes the state or the digest.
- **Sound.** Plucking a string plays its audition (fundamental 110 Hz × 2^((peg − 1) / 12), one partial per resonant mode
  at the fundamental × n with gain 0.04 × w, 0.6 s; a muted pluck without modes), and an optional ambient loop follows
  the actions left, the steps reached and the stage (`HarmonicBridgesSoundRecipe`); sound plays only while chosen, on
  screen and active, and is off by default.
- **Panel.** Every control has a label and a value in words; the chosen string and peg are adjustable; a summary element
  reads the actions left, the steps reached, the shown step's bridges, the choice and the level; text follows Dynamic
  Type and Increase Contrast, rows wrap, and the panel keeps a readable width on iPad.

## Persistence and replay (feature 417, R02-G12-07)

- **Stored form.** Snapshot schema 3 `{level, mode, progress, records, sound, tutorial}` through the app's shared saved-
  state store (atomic writes, unreadable files moved aside, newer schemas refused), with migrations 1 → 2 → 3 (2 → 3:
  results with an empty trace, unverified; sound off). The digest ("r02-g12.harmonic-bridges.v3") covers the level, the
  play, progress and mode; the sound choice and the count of dropped results are never digested.
- **Reconcilable scores.** Each campaign or daily win stores its least actions spent, its stars and the winning trace —
  the effective tunings and the test, with undone actions left out (`HarmonicBridgesReconciliation.netTrace`) — marked
  verified. On restore every traced result is replayed on a fresh play of its certified level and kept only if it wins,
  spends at most its recorded actions and its stars match the rule; edited results are dropped and counted, untraced
  ones kept unverified, and the frontier restored as saved. The panel announces the dropped count once.
- **Replay.** `replay.start [level]` replays a verified solution action by action (`replay.step`, `replay.stop`); other
  play actions are refused in words during replay, which never changes progress or claims stars.
- **Settings.** `settings.sound [0 … 1]` stores the sound choice in the snapshot; the presenter applies it on open.

## Regression net (feature 418, R02-G12-08)

- **Solver regression.** For all 100 levels, in ten groups of ten: the generated level equals its witness (part by part
  and by fingerprint), the witness's actions replay on a fresh play to a win on the last action in exactly their count
  (the plan's tunings, then the test) within the budget with the stored per-step bridge digests and per-action
  fingerprints, the recounted smaller choices equal the witness's counterexample, and the solver re-finds exactly the
  witness's tunings with its smaller-choices count and size, with work at most 400,000 (counted, never timed); eleven
  kinds of alteration (an island's position, a string's length, starting peg or lock, a step's tone, the threshold, the
  budget, a plan tuning, a witness action, a per-action fingerprint, the smaller-choices count) each fail naming the
  level and the part, and a level copy the initialiser refuses is named too.
- **Golden frames.** `HarmonicBridgesGolden` (test builds only; forbidden in the Release binary) describes 16 frames
  (levels 1, 21, 41, 61, 81 at tiers 0 … 2 after their certified tunings and before the test, plus the hero frame) at
  1,152 × 768: the island tops, string midpoints, the shown step's membrane check points, the step pips and the first
  gauge bar in 1/8 pixel (an off-screen point is null), the counts of islands, strings, bridges, filled and hollow
  marks, pips and gauge bars, the tier's detail and the 13 palette colours, hashed with SHA-256 and pinned in
  `golden-frames.json`; a recomputed frame passes on an equal digest or within one quantum with equal counts and
  colours, a pinned digest must match its pinned description, and the file is rewritten only with
  `HARMONIC_BRIDGES_WRITE_GOLDEN=1`. On the simulator the same frames are rendered and checked against their
  descriptions with the feature-413 frame checks.
- **Memory.** Twelve open-draw-warn-close cycles keep the footprint within 16 MB of the first cycle when the class runs
  alone (measured growth 0.55 MB) and leave the bridge scene with no GPU objects after every close and memory warning;
  the next frame rebuilds them.
- **Running it.** `python3 scripts/harmonic_bridges_regression.py` runs the host part and the simulator classes with
  one summary line per part; CI runs the host part as "Harmonic Bridges regression (host)".

## In-app integration (feature 419, R02-G12-09)

- **Identifiers.** Every panel control and text element carries `experience.r02-g12.harmonic-bridges.<name>`
  (`HarmonicBridgesControls.identifierNames`, 30 names: string, peg, tune, test, undo, redo, next-level, reset-view,
  dismiss-tutorial, hint, failure-undo, retry, campaign, daily, practice, level-picker, play-level, replay, replay-step,
  replay-stop, sound, summary, status, actions, message, failure, instruction, hint-text, goal, replay-position); an
  experience test checks each is listed once and used exactly once in the panel.
- **Interface tests.** `HBPlayUITests` wins level 1 through the panel (its certified actions: string 0 from peg 11 to
  peg 12 with the peg stepper, Tune, then Test: "The crossing holds in every step.", "Stars: 3 of 3.", level 2 open)
  and keeps the progress over a relaunch; `HBReplayUITests` replays the win (two actions) to its end and stops. They run
  as serial chunk `u3`, each under 90 s apart from the simulator's automation-session setup per launch. Level 1's
  certified actions, the opening choice (string 0, peg 11) and the budget (9) are pinned in `HB` and checked against the
  Core by an app unit test.
- **Stored examples.** The registration stores schema-1 and schema-2 examples (`HarmonicBridgesSchemaExamples`, seed
  7), which the app restores into schema 3; Harmonic Bridges stays a candidate (not available without
  `-vcCandidates`) until X-R02-G12.
- **Release.** The Release simulator build compiles without the test-only golden descriptions and scenarios.

## Device preparation (feature 420, R02-G12-10)

Nothing here touches a device. `docs/apps/harmonic-bridges/device-rows.json` defines the device scenario set (the 11
standard and game scenarios and `fixture-level-1-solved`) and rows HB-D1 … HB-D8 for D1, D2 and D3 (the ledger's
DEV1/2/3-R02-G12 rows): launch and first frame, frame pacing and frame time per tier, memory and thermal state with the
round-two stress session, touch feel and latency (string plucks, peg drags that tune, taps that test, orbit), sound and
haptics, a non-gating VoiceOver walk-through, progress across a real termination and the panel journeys. Every row is
"pending device campaign" and covers the open {device} tasks of features 413, 414 and 416 … 419 and UA-F13's
measurements; `scripts/check_device_rows.py --experience r02-g12.harmonic-bridges` (release step
`device-rows-r02-g12`) keeps it true. The written plan is `docs/apps/harmonic-bridges/device-campaign.md`; D3 stays on
iPadOS 26.5.

