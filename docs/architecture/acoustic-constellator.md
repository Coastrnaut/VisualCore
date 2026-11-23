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
