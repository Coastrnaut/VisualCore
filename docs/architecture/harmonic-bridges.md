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
