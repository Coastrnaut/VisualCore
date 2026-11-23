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
