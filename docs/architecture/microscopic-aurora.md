# Microscopic Aurora (R02-G19)

Experience `r02-g19.microscopic-aurora` (free), a puzzle of luminous swimmers in a round dish under a microscope: the
player places up to three magnetic wells, each with a strength and a turning sense, then releases the swarm for one
swim, so that the swimmers' glowing trails cover a target stencil as one connected pattern, without a swimmer leaving
the enclosure or the swarm losing its coherence. Code lives in `Packages/ExperiencesRound02/MicroscopicAurora`; this
page grows with each feature of R02-G19. The swarm is integrated in deterministic integer arithmetic and every rule is
decided exactly on integer positions; the catalog's 0.008333 s timestep is a presentation clock of later features.

## Rule kernel (feature 481, R02-G19-01)

- **Dish and swarm.** The dish is 24 × 24 cells of 256 dish units; the enclosure is the circle of radius R (6 … 11
  cells) about (3072, 3072), the rim inside. A level has 4 … 16 swimmers, each an integer position and velocity, and a
  swim of T ticks (120 … 480).
- **One tick.** Every acceleration comes from the swarm as it is (a synchronous step). Neighbours lie within ρ (2 … 6
  cells): separation sums pᵢ − pⱼ within σ (1 … ρ), coincident swimmers pushed ±1 along x by index; alignment is the
  neighbours' mean velocity minus vᵢ and cohesion their mean position minus pᵢ (zero with no neighbour). The swarm
  acceleration (wₛ·separation)/64 + (wₐ·alignment)/16 + (w_c·cohesion)/256 (weights 0 … 8) is joined by each well's
  curl sense·s·4096·(−dy, dx)/(dx² + dy² + 65536) about its cell centre; every division truncates toward zero. The
  acceleration is clamped to ±a_max (2 … 16) and the velocity to ±v_max (8 … 48) per axis, then p ← p + v.
- **Trails and the judge.** A cell's trail density counts the (swimmer, tick) pairs of ticks 1 … T in it; a cell is lit
  at the level's threshold (1 … 64). The stencil (4 … 120 cells inside the enclosure) is covered in tenths of a percent,
  rounded down, against a requirement of 500 … 1000, and its lit cells must form exactly one four-neighbour group.
  Coherence is the largest group of swimmers linked within κ (2 … 8 cells). Playing walks the ticks: the lowest-index
  swimmer outside fails `exit`, otherwise a coherence below the requirement fails `coherence`; after the swim a coverage
  below the requirement fails `coverage` and more than one group `connectedness` (naming the first cell not joined to
  the first one's group); otherwise the level is won.
- **Actions.** `place(slot, well)` puts a well (a usable cell no other well holds, strength 1 … 4, a sense) into one of
  three slots or changes it, and `remove(slot)` empties one; each spends one action (refused `r02-g19.action` when out
  of range, unchanged, on an occupied or outside cell or removing an empty slot; `r02-g19.budget` with no action
  left); `play` spends nothing and ends the level won or failed with the named failure. The swim report (densities,
  lit cells, coverage, groups, the smallest coherence and its tick, the first failure and the predicted outcome) and
  its words are reported after every action. Undo and redo are exact; undo from failed returns to playing before the
  play; a won level is final.
- **Life and stored form.** Stages loading, tutorial, playing, paused, won, failed, result; records with previous and
  next fingerprints replay a play exactly; the level's stored form is JSON schema 1 with a SHA-256 fingerprint,
  re-checked on decode (damaged, edited, newer and older forms refused; a swimmer outside, an incoherent start, a
  repeated or outside stencil cell, wells outside or sharing a cell and starting wells that already win are refused).
  The rules are an R02-F23 `PuzzleRules` (`MicroscopicAuroraPuzzle`) over well placements.

## Content pipeline (feature 482, R02-G19-02)

- **Kernel extension.** The budget range widens to 1 … 24 (the manifest's budgets reach 19), and a level may list 2 … 8
  well sites: with sites every well, starting or placed, must stand on one (the play refuses "not a site"; the puzzle
  contract lists placements on sites only, at most 3 × 8 × 8 = 192). A level without sites omits the field, so feature
  481's levels keep their stored form and fingerprints.
- **Manifest.** `MicroscopicAuroraManifest` holds the 100 planned levels of the archived design (number, planned seed,
  band 1 … 5, moves budget 8 … 19, control emphasis), 20 per band.
- **Generator.** Candidate c of an entry draws from `SeededRandom(seed: SeedDerivation.derive(seed, index: c))`: the
  swim length, the swarm rules, a bunched swarm with a small drift, the sites (usable within radius 8), the winning
  wells on a partial shuffle of the sites and the threshold; the winning wells are swum and the stencil is the largest
  lit group, trimmed breadth-first to the band's maximum; then the coverage and coherence requirements. Band profiles
  grow from 4 … 5 swimmers, 3 sites and one well (band 1) to 8 swimmers, 6 sites and two wells over larger stencils and
  stricter coverage (band 5). Levels start with no well; adjacent levels never share their stencil; at most 64
  candidates per entry (the catalog needs at most index 11).
- **Solver.** A report depends only on the set of wells, so from no well the settings reachable in d placements are the
  sets of at most d wells on distinct sites (8 options per site). The solver judges depth 0, 1, 2 …, each depth ordered
  by the shape loss (stencil cells unlit plus cells lit outside the stencil) of each set's prefix; the first win is
  minimal and every smaller depth, judged in full, is the proof. Work is counted (at most 830 sets per level, bound
  1,200). The nearest miss is the smallest loss among the smaller depths.
- **Certificates.** `docs/games/microscopic-aurora/levels/NNN.witness.json` (schema 1) holds each level with its sites,
  its placements and the play, a state digest after every action, the play fingerprints, the terminal report (lit
  stencil cells, coverage, groups, the smallest coherence) and the counterexample; the tests rebuild all 100 byte for
  byte in 20 groups of 5 and pin the catalog digest. Witness lengths are 1, 1, 2, 2 and 2 by band, under R02-F24's
  progression rule.

## Hero renderer and experience (feature 483, R02-G19-03)

- **Snapshot.** `MicroscopicAuroraSceneSnapshot` is all the renderer reads: every swimmer's integer position and
  velocity at each tick of the predicted swim of the current wells, the ticks swum and the shown tick, the density with
  the lit stencil and stray cells, the stencil, the sites, the wells, the coverage and coherence with their requirements
  and the coherence radius, and the stage, failure, actions and level.
- **The dish.** One fixed scale for every level (s = 0.9 / 2816, an 11-cell rim at radius 0.9), so placing wells never
  rescales the picture. In painter's order with depth testing off: the still abyss backdrop, the dish field, small
  L-system fronds outside the rim (decoration only, at the richer tiers), the rim, the stencil outlines, the lit and
  stray cells, the site rings, the well spirals (strength + 1 half-turns, an arrow for the turning sense), the ribbons
  through each swimmer's kernel positions of the last ticks, the tapered capsule swimmers oriented along their velocity,
  the coverage and coherence gauges with requirement ticks and the actions bars; the glow is additive and last. Every
  drawn swimmer and ribbon point is a kernel position; nothing moves by time.
- **Tiers.** `level-0`: capsules of 12 segments, 64 ribbon ticks, fronds, 2 glow shells; `level-1`: 8 segments, 32
  ticks, fronds, 1 shell; `level-2`: flat capsules, 16 ticks, no fronds, no glow. Everything else is identical.
- **Shaders.** GLSL ES 3.00 dish and glow programs with 20 material codes in the uv stream (the shared mesh renderer
  binds only position, normal and uv); a won level brightens the ribbons and lights every stencil outline; Reduce
  Flashing caps the glow.
- **Adapter.** `MicroscopicAuroraExperienceCore` opens certified level (seed mod 100) + 1 from a table of each
  witness's candidate index, accepts `well.place`, `well.remove`, `swim.play`, `play.undo`, `play.redo`, `level.next`
  and `clock.show`; its digest is the level number and the play's fingerprint (never the shown tick); snapshot schema 1.
- **Experience.** The presenter draws with the fixed camera, logs tier changes, falls back to the unlit level-2
  geometry when a program fails, and declares two backdrop probes; the minimal control panel chooses a slot, a site, a
  strength and a sense, places and removes wells, steps the shown tick and plays, undoes, redoes and moves to the next
  level. The candidate is registered in the one app (not available until X-R02-G19) with its scenario manifest (the
  standard scenarios, a three-level playthrough, fixtures and the 80 acceptance rows R2-G19-QA-001 … 080).

## Gameplay spatial interaction (feature 484, R02-G19-04)

- **Picking.** `MicroscopicAuroraPicker` projects the parts through the drawn camera (the view orbit included) and tries
  them in order: a well within its projected spiral radius grown by 12 points (later slots first), then a site within
  its projected ring radius grown by 12 points, then the swim scrubber (a track at y −1.31 under the gauges) within a
  14-point band, then the dish field inside the projected enclosure; anything else is empty space.
- **Gestures.** `MicroscopicAuroraGestureController` turns touches into actions. A tap on an empty site while playing
  places a well with the panel's strength and sense in the first free slot (`well.place`), or says that every slot is
  used. Dragging a well (16 points or more, while playing) previews the swim with the well on the site nearest the
  finger within 24 points, or removed when the finger leaves the dish: the previewed ribbons, lit cells and gauges come
  from the kernel's own swim, and the dragged well is drawn as a ghost (material 20). Lifting sends one `well.place`
  (same strength and sense) or one `well.remove` when the target is a change, otherwise nothing. Dragging the scrubber
  shows the tick nearest the finger (`clock.show`, presentation only, in any stage). A tap on the dish field toggles
  the freeze: the committed swim stays drawn and only the gauges preview. Two fingers orbit the view within yaw ±60°
  and pitch −20° … +35°; a double tap outside the dish or "Reset view" returns to the authored view. A finished play
  explains itself in words; second fingers and cancels send no kernel action; the preview, the freeze and the orbit
  never enter the digest.
- **Panel parity.** The panel keeps every action (slot, site, strength, sense, Place, Remove, ticks, Play, Undo, Redo,
  Next level) and gains "Freeze" and "Reset view"; its kernel buttons send through the presenter, which logs refusal
  codes with or without the engine's prefix. A host test wins all 100 certified levels through the panel within their
  budgets.

## Teaching and progression (feature 485, R02-G19-05)

- **Hints.** `MicroscopicAuroraHints` searches from the current wells for the fewest actions (at most two placements or
  removals, within the actions left) that make a winning set of wells: one action before two, the certified plan's next
  placement first while the current wells are a subset of the certified ones, then removals and placements in a fixed
  order, at most 1,200 sets judged (a report depends only on the set of wells). The hint escalates from the site ("Use
  the site at row r, column c next", or "Take well n away") to the sense ("Place a clockwise well at the site at row r,
  column c") to the exact well ("Place well n at row r, column c with strength s, turning clockwise"); winning wells say
  "play the swim"; no plan says so and suggests undo or retry. Following exact hints from every opening and then
  playing replays the certified plan and wins all 100 levels within their budgets. The presenter runs the search off
  the main actor, once per play.
- **Failure text.** `MicroscopicAuroraFailureExplanation` puts the play's failure in words: the swimmer that left the
  dish and the tick, the tick the swarm split with its largest group and the coherence needed, the stencil cells lit
  and needed, or the lit cell cut off from the pattern, swimmers numbered from 1 and cells by row and column.
- **Tutorial.** Levels 1 … 3 show three instructions (put a well on a marked site; light the stencil as one joined
  pattern and play; what fails a swim), each advancing when done (a placement, then a second action, then the level's
  end); dismissible; undo never moves it back.
- **Progress.** Stars by actions spent against the certified plan's placements (3 at most, 2 within two more, else 1),
  level 1 open and a campaign win opening the next (no wrap after 100), five bands of 20; the daily level is (days since
  2026-01-01 × 19) mod 100 + 1 and is playable while still locked without opening it; practice raises the budget to 24
  without stars or unlocks. The panel shows the band, the goal, the best stars, the modes and a picker of open levels.
  The snapshot is schema 2 (digest domain `r02-g19.microscopic-aurora.v2`) with a migration from schema 1.

## Polish and accessibility (feature 486, R02-G19-06)

- **Feedback.** `MicroscopicAuroraFeedbackPlan.after(old:new:)` turns each change of the adapter core into one
  announcement and one haptic through the shared route: a placement ("Well n placed at row r, column c, strength s,
  clockwise.") or a removal ("Well n removed.") followed by the stencil cells lit, whether playing now would win and
  the actions left (`state`, selection), undo and redo, a won play (`outcome`, success, with stars outside practice), a
  failed play (the failure explanation, `outcome`, warning), a level or mode change (`level`) and refusals in words
  (`rejection`, error). The play, which always ends the level, plans only its outcome; showing a tick or dismissing the
  tutorial plans nothing. The presenter keeps a feedback log.
- **Comfort.** `MicroscopicAuroraLights` eases the glow (0.7 playing, 1 won, 0.35 failed) and the won look by the frame
  clock (0.15 s, 0.45 s under Reduce Flashing, no reversal mid-fade); the scene draws the eased levels (`u_won`, the
  glow gain, and in the unlit fallback the not-won and won colours blended by the won level), so no element crosses
  half its range more than three times a second. Nothing else in the dish moves by time, so it is still between
  actions under Reduce Motion and Reduce Flashing.
- **Sound.** Off by default (a Sound toggle). Each change of the panel's selection (slot, site, strength or sense,
  through the buttons or the adjustable values; never a drag preview) plays the selected well's audition: the strength
  tone 220 Hz × 2^(n/12), n = 3 × (strength − 1), with a fifth (clockwise) or a fourth (counterclockwise) when the well
  can be placed, or with a partial 3 Hz above when it cannot, 0.6 s. The ambient loop comes from the actions left (the
  root), the quarters of the needed stencil cells lit (the partials) and the stage; it is rebuilt only when that recipe
  changes and plays only while wanted, on screen and active.
- **Panel.** A summary element ("a actions left. <progress>. Selected: well n at row r, column c, strength s, <sense>.
  Level: <level>."), the slot, site and strength adjustable with VoiceOver and the sense a toggle with its value, a
  value in words on every control, refusals in the feedback plan's words, rows that become columns at accessibility
  text sizes and a 520-point readable width on iPad.

## Persistence and replay (feature 487, R02-G19-07)

- **Saves.** The one app's shared saved-state store writes the snapshot atomically; schema 3 is `{"level", "mode",
  "progress", "records", "sound", "tutorial"}` and migrates from schema 1 and 2 (2 → 3: every result an empty trace,
  unverified, sound off). The shown tick, the panel's selection, the freeze, a drag preview, the hint level and the
  camera are presentation and are not saved.
- **Reconcilable scores.** A campaign or daily win stores the winning trace — the effective placements and removals in
  order (an undone action left out unless redone), then the play — with the result. On restore
  `MicroscopicAuroraReconciliation` replays every trace on a fresh play of its certified level and keeps the result only
  when it wins, spends at most the recorded actions and its stars match the stars rule; the frontier is restored as
  saved. Dropped results are counted (`reconciliationDropped`, never digested) and announced once.
- **Replay.** `replay.start [level]` opens mode `replay(level)` for a level with a verified trace, `replay.step` applies
  the next action (a placement or removal, finally the play), `replay.stop` returns to the campaign; other play actions
  are refused (`r02-g19.replay`), nothing is recorded and no stars are claimed. A save taken mid-replay restores only
  when its records are the start of that trace.
- **Settings.** The sound choice is saved through `settings.sound [0 … 1]`, snapshotted but never digested, and applied
  when the experience opens.

## Regression net (feature 488, R02-G19-08)

- **Solver regression.** For all 100 levels the generated level equals its witness, the witness replays to a win on
  exactly its final play with its per-action fingerprints and digests, and the certifying search returns exactly the
  witness's wells with the counted well sets one placement short and the nearest miss, within its work bound (counted,
  never timed); twelve kinds of alteration are each detected and named. Ten tests of ten levels; each level is solved
  once (the group tests build the certified candidate directly instead of solving twice through the adapter's cache).
- **Golden frames.** `MicroscopicAuroraGolden` (debug and automation builds only; forbidden in Release) describes 16
  frames — levels 1, 21, 41, 61 and 81 at three tiers after their certified placements, shown at half the ticks swum,
  plus the hero frame — by the projected dish centre, swimmers, wells, sites and first actions bar in eighths of a
  pixel, element counts and the 18 palette colours, pinned with SHA-256 digests in `golden-frames.json` and rewritten
  only with `MICROSCOPIC_AURORA_WRITE_GOLDEN=1`. The simulator renders the same frames and checks them with the
  feature-483 tolerances.
- **Memory.** Twelve open–draw–warn–close cycles on the simulator stay within 16 MB of the first (bound applied when the
  class runs alone) and release every GPU object of the scene.
- **Running it.** CI's round-two job has a "Microscopic Aurora regression (host)" step;
  `python3 scripts/microscopic_aurora_regression.py` runs the host and simulator parts with one summary.

## In-app integration (feature 489, R02-G19-09)

- **Identifiers.** Every panel element has an identifier `experience.r02-g19.microscopic-aurora.<name>`; the 48 names
  are pinned in `MicroscopicAuroraControls.identifierNames` and each is used once (the failure explanation has its own
  `explanation`).
- **Interface tests.** `MAPlayUITests` opens the candidate in the one app, wins level 1 through the panel alone (choose
  the well's site, strength and sense, Place, then Play) with "Best: 3 of 3 stars", sees level 2 open and keeps the
  progress over a relaunch; `MAReplayUITests` replays the solved level to its end and stops back to the campaign. They
  run in the serial release-check chunk `b4`.
- **Stored examples.** `schemaOneExample()` and `schemaTwoExample()` are registered with the app, which restores both
  into schema 3; app unit tests also open the candidate through the registry and engine, win level 1 and confirm it is
  not available without the testing argument.
- **Builds.** The app compiles in debug and release for the simulator with the game linked; the release symbol check
  confirms the test-only golden source and scenarios are absent.

## Device preparation (feature 490, R02-G19-10)

Nothing here touches a device. `docs/apps/microscopic-aurora/device-rows.json` defines the device scenario set (the 11
standard and game scenarios and `fixture-level-1-solved`) and rows MA-D1 … MA-D8 for D1, D2 and D3 (the ledger's
DEV1/2/3-R02-G19 rows): launch and first frame, frame pacing and frame time per tier, memory and thermal state with the
round-two stress session, touch feel and latency (a tap on a site that places a well, a well drag with the swim
preview, a scrubber drag that shows a tick, a tap on the field that freezes, a double tap on empty space that resets
the view, orbit), sound and haptics, a non-gating VoiceOver walk-through, progress across a real termination and the
panel journeys. Every row is "pending device campaign" and covers the open {device} tasks of features 483, 484 and
486 … 489 and UA-F13's measurements; `scripts/check_device_rows.py --experience r02-g19.microscopic-aurora` (release
step `device-rows-r02-g19`) keeps it true. The written plan is `docs/apps/microscopic-aurora/device-campaign.md`; D3
stays on iPadOS 26.5.
