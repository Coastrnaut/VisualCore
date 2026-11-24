# Acoustic Constellator (R02-G13) — rules

Experience `r02-g13.acoustic-constellator` (free) of the one VisualCore app; package `Packages/ExperiencesRound02`,
target `AcousticConstellatorCore` (feature 421, R02-G13-01). Drifting musical stars each pulse at their own natural rate.
Linking two stars couples them, pulling their phases together; a link stretched too far by the drift snaps. The player
links the pairs of a target celestial symbol (and any helping links the limits allow), nudges stars' starting phases,
and listens: if every link of the symbol exists and the stars cohere above the level's threshold for the hold interval
within the listening window, the level is won. Everything here is pure, exact integer logic; drawing, controls and
sound come in later features of R02-G13.

## Stars, links and the symbol

- **Stars.** 3 … 8, each with a natural rate ω in 0 … 11 phase steps per tick, a starting phase φ₀ in 0 … 11 and a
  drawing position on a 12 × 12 × 12 grid that never decides a rule.
- **Links.** 0 … 6 fixed links (the player cannot remove them) plus the player's own; each joins two distinct stars and
  no pair twice. A star carries at most D links (2 … 4) and the level at most E links at once (the symbol's size … 16).
- **Symbol.** 2 … 10 star pairs whose graph is connected; its stars are the symbol's stars.
- **Numbers.** Coupling K in 1 … 8, snap limit σ in 2 … 5, coherence threshold θ in 1 … n², hold H in 2 … 12 ticks,
  window W in H … 48 ticks, action budget 1 … 40.

## Phases, coupling and coherence

- **Clock.** Phases live on a 12-step clock (arithmetic modulo 12); the signed gap from star i to star j is
  φⱼ − φᵢ reduced to −5 … 6.
- **Tick.** The law phase_i += ω_i·dt + K Σ sin(phase_j − phase_i)·dt in whole numbers: the coupling table
  s(d) = sign(d) · t(|d|) with t(0 … 6) = 0, 1, 2, 2, 2, 1, 0 (2·sin(πd/6) rounded); star i's pull P is the sum of s over
  its current links; its coupling step is ⌊K · P / 4⌋ clamped to −1 … 1; all stars then move at once to
  (φᵢ + ωᵢ + step) mod 12. The clamp keeps the discrete map from overshooting.
- **Snap.** After each tick of a listen, every link whose gap |d| exceeds σ snaps for the rest of that listen.
- **Coherence.** The Kuramoto order parameter n²R² = |Σ e^{iπφ/6}|² is exactly A + B√3 with A = n + Σ_{i<j} a(gap) and
  B = Σ_{i<j} b(gap), (a, b) for gaps 0 … 6 being (2, 0), (0, 1), (1, 0), (0, 0), (−1, 0), (0, −1), (−2, 0); it is
  compared with θ exactly by squaring with sign care, never in floating point.

## Actions and verdict

`link(a, b)`, `unlink(a, b)` (a player's link only) and `nudge(i, ±1)` (one step of a starting phase) each spend 1
action; `listen` spends 1 and decides the level. Refused without change: an unknown star, a self link, an existing link,
a degree or link limit, removing a missing or fixed link, a nudge other than one step (`r02-g13.action`); the wrong
stage (`.stage`) and a stale fingerprint (`.stale`). A listen fails `missing` (the smallest unlinked symbol pair by star indices);
otherwise it runs ticks 1 … W — move, snap, then `disconnected` (the tick and the smallest link snapped in it; links are kept sorted by star indices) when
the remaining links no longer join the symbol's stars, then a tick is coherent when every symbol pair is intact and
A + B√3 ≥ θ — and wins on the H-th consecutive coherent tick, or fails `incoherent` with the longest coherent run when
the window ends. After any other action, a spent budget without a win fails the level (`budget`). Undo and redo spend
nothing and restore the exact earlier state; undo from failed returns to playing (recorded); a won level is final.

## Measures

After every action the play reports a listen of the current state (the phases at every tick, the links snapped per
tick, A and B per tick, the coherent runs and the outcome it would give) and the graph-isomorphism label of the player's
link graph (the smallest adjacency string over all orderings of the stars) with whether it equals the symbol's; they
never decide the outcome on their own. Every phase, snap, coherence value, connectivity verdict and label agrees with
an independent recomputation in the tests.

## Stored form

Levels are JSON schema 1 with sorted keys (stars as [x, y, z, ω, φ₀], fixed links and symbol as pairs, K, D, E, σ, θ,
H, W, budget, difficulty, tutorial, seed, id) and their fingerprint; decoding re-checks every rule and the fingerprint
and refuses damaged, edited and newer forms (`r02-g13.malformed`, `.newer-schema`).

## Content pipeline (feature 422, R02-G13-02)

- **Manifest.** The 100 planned levels of the archived design (`AcousticConstellatorManifest`): number, planned seed,
  band 1 … 5 (20 each) and moves budget 8 … 19.
- **Generator.** Candidate c of entry n draws from `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: c))` and
  is built constructively: the star count (3 … 4 up to 7 … 8 by band), the symbol as a spanning tree of the stars plus
  one cycle pair from band 3, a base rate and each star's rate base or base + 1 (1 in 3), starting phases, the missing
  symbol pairs (1 … 2 up to 3 … 4; the rest are fixed links), the coupling 2 … 8, the snap limit 3 … 5, the hold 4 … 8
  and the window (24, 24, 32, 40, 48); then the degree limit min(4, max(2, largest symbol degree + 1)), the link limit
  min(16, symbol size + 2) and the threshold ⌊3n²/5⌋. Tutorial on levels 1 … 3. A candidate is kept when its minimal
  plan has an action count in the band's range (1 … 2 up to 5 … 6) and at most budget − 1, and the witness wins through
  the play; at most 256 candidates (`r02-g13.generation`). The ranges were measured with a prototype before they were
  written down; over the catalog the band means are 1.60, 2.15, 3.30, 4.45 and 5.30 actions.
- **Minimal plan and proof.** Every winning plan links every missing symbol pair, so those are always in it; the other
  options are helper links (pair order) and nudges (star order, −1 then +1). `AcousticConstellatorSolver.plan` tries 0,
  1, 2, … extra actions as multisets in option order, never repeating a helper link, never holding opposite nudges on
  one star (they cancel) and never unlinking (the player starts with nothing to remove), runs the kernel's listen on
  each, and returns the first winning set; the sets tried at smaller sizes are the minimality proof. Work (listens) is
  bounded at 400,000; the largest catalog plan used 1,367.
- **Witness files.** `docs/games/acoustic-constellator/levels/NNN.witness.json` (schema 1, sorted keys): the level, the
  actions (links in pair order, nudges in star order, then a listen), a state digest after each action, the play
  fingerprints, the counterexample (the size one below and the sets of that size tried, none winning, or "missing" when
  the plan has no extra action), the difficulty and the candidates skipped. Regenerated only with
  `ACOUSTIC_CONSTELLATOR_WRITE_WITNESSES=1`; decoding re-runs the replay (`r02-g13.witness`).
- **Catalog.** `PuzzleCatalog<AcousticConstellatorRules>.digest(id: "acoustic-constellator", …)` over the 100
  fingerprints is pinned; the standard progression rule holds on the witness action count; an independent brute force
  (every play action in bands 1 … 3, the pruned options in bands 4 and 5) re-checks minimality on two levels per band.

## Hero renderer and experience (feature 423, R02-G13-03)

- **Scene.** The sky is a plane at y = −0.01. Star (gx, gy, gz) of the 12³ grid is at X = (gx − 5.5)·0.14,
  Z = (gy − 5.5)·0.11, Y = 0.15 + (gz − 5.5)·0.02, an ellipsoid 0.045 × 0.035 × 0.045 (12 × 8 segments) with a phase
  hand 0.006 wide and 0.07 long at angle phase·30°, 0.04 above it. Each link is a spline strip 0.01 wide rising 0.03 at
  its middle (16 segments): silver while the gap at the shown tick is above 1, teal at most 1; a link the kernel's report
  has snapped by the shown tick is drawn as two halves with the middle 30 % missing. Every unlinked symbol pair is a
  dashed plum guide (8 dashes). In front lie the coherence gauge (12 bars at z = 0.85, ⌊12·(A + B√3)/n²⌋ lit, a mark
  over bar ⌈12θ/n²⌉), the hold pips (z = 1.0, lit for the current coherent run) and the moves gauge (z = 1.15, one bar
  per action of the budget, lit for the actions left) (`AcousticConstellatorSceneGeometry`).
- **Ticks and pulse.** The shown tick plays the kernel's listen report of the current state, one tick per 0.25 s, holds
  the last tick 1 s and loops (`AcousticConstellatorSceneSnapshot.shownTick`, 0 at time 0). Stars pulse in the vertex
  shader, scale 1 + 0.15·cos(2π·phase/12) from the per-star phases of the shown tick (two vec4 uniforms, `u_phasesLow`
  and `u_phasesHigh`, since the shared `ShaderProgram` has no vec4-array setter); the pulse is presentation only and
  never replaces the kernel's phases (`AcousticConstellatorShaders`).
- **Order and shading.** Depth testing is off: the constellation mesh is in painter's order (sky, gauges, guides, links,
  hands, stars back to front); the glow mesh (wave shells, then glow shells) is drawn last, additively. Material codes in
  uv.x select colour and signed-distance edge shading from the per-vertex local coordinate in uv.y. A won level draws the
  symbol links in the won colour and lifts their glow without moving anything; a failure outlines the missing pair's
  guide or the snapped link in #FF6B4A.
- **Tiers.** level-0: pulse, two wave shells per star on a coherent shown tick, two glow shells; level-1: pulse and one
  glow shell; level-2: none. The constellation mesh is identical at every tier; only the glow mesh and the pulse uniform
  change, and the presenter logs tier changes.
- **Camera.** A fixed authored view from eye (0, 2.0, 1.7) towards (0, 0, 0.2), fitted to the box x −0.9 … 0.9,
  z −0.7 … 1.25, y 0 … 0.3 with a margin for aspects 0.4 … 2.5.
- **Adapter.** `AcousticConstellatorExperienceCore` opens certified level (seed mod 100) + 1 directly from its table of
  each witness's skipped candidate (the whole generator only if that fails) and accepts `link.add` [a, b], `link.remove`
  [a, b], `star.nudge` [s, ±1], `constellation.listen`, `play.undo`, `play.redo` and `level.next`; its digest
  ("r02-g13.acoustic-constellator.v1") is the level number and the play fingerprint; snapshot schema 1.
- **Fallback and settings.** A shader failure draws the level-2 geometry unlit and keeps the reason; Reduce Motion draws
  tick 0 without pulse or wave shells; Reduce Flashing caps the glow.
- **Candidate.** Registered in `Catalog/registrations.json` (100 levels, digest 4c50d04a…07a12) and linked into the app
  as a candidate (`ExperienceRegistry.candidates`) until X-R02-G13; the scenario manifest holds the standard scenarios,
  `full-playthrough`, `hero`, 80 acceptance scenarios and the fixtures.

## Gestures (feature 424, R02-G13-04)

- **Picking.** At touch-down every target is projected through the drawn camera (orbit included) into view points:
  first a coherence bar or hold pip whose centre lies within 22 points (nearest; ties to the coherence bars, then the
  lower index), then a star centre within 22 points (nearest, ties to the lower index), then a link whose projected
  spline (16 segments) lies within 22 points (nearest, ties to the lower index); the moves gauge and the guides are
  empty space (`AcousticConstellatorPicker`).
- **Taps and drags.** A tap moves less than 10 points and lifts within 0.5 s; a drag moves at least 16 points. A tap on a
  star while playing nudges it one step forward (`star.nudge [s, 1]`) and chooses it; a tap on a link chooses its two
  stars and describes it (no action); a tap on a gauge listens; two taps on empty space within 0.35 s and 22 points
  reset the view. A drag from a star draws a teal filament to the finger (`filamentMesh`, ending on the dragged star's
  height plane or at the target star) and, released on another star, links an unlinked pair or unlinks a pair the player
  linked; fixed pairs send nothing (`AcousticConstellatorGestureController`).
- **Orbit.** Two fingers orbit within yaw ±35° and pitch −15° … +20°; the field of view refits so the authored box stays
  inside the view with a 5 % margin at aspects 0.4 … 2.5, and the stars are painted back to front from the drawn eye.
  Orbit is presentation only, outside the snapshot and the digest; "Reset view" or a double tap returns to the authored
  view.
- **Finished plays and refusals.** On a won or failed play gestures send no kernel action (a star tap only chooses the
  star) and the description says the play is over; refused actions are shown in words and their codes kept in the
  presenter's refusal log, read with or without the engine's `action.rule.` prefix.
- **Panel.** Every action stays on the panel, now with "Reset view"; all 100 certified levels are won through the panel
  alone in a host test.
