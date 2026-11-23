# Research: R02-G11-06

- **R1 Pure plans.** Decision: announcement and haptic plans are pure functions of the old and new core (and a refusal
  code), as in features 386 and 396. Rationale: exact host tests; nothing timing-dependent.
- **R2 Fade only the lights; rings and flares at rest under Reduce Flashing.** Decision: ease the chamber's glow and the
  won brightening; under Reduce Flashing draw the pulse and echo rings and the wall flares at rest, as Reduce Motion
  does. Rationale: the rings and flares restart whenever the last echo changes, so a pulse undone and redone every frame
  would flash a struck wall or the emitter's ring repeatedly; their information (the rays, the walls found, the echo
  delays) stays in the drawn rays and the panel's words. Rays, tiles, walls, markers, pillars and gauge bars follow the
  player's actions, as feature 396's kink crosses do. Alternatives: easing each flare's onset by a uniform (rejected: a
  restart every frame still re-arms the rise, and a per-wall eased level needs geometry rebuilds).
- **R3 Sound from the chamber.** Decision: the root follows the energy left as a share of the level's energy (110 Hz ×
  1, 9/8, 5/4, 4/3 for more than 3/4, 1/2, 1/4, or less), one partial per located beacon up to four, an octave when won,
  halved when failed; a loop length at which every partial has a whole number of cycles. Rationale: the sound reflects
  the state without being a puzzle aid beyond what the panel shows; pure and testable.
- **R4 Panel layout.** Decision: as features 386 and 396 — scrolling, Dynamic Type, wrapping rows, adjustable column and
  row, a summary element, at most 520 points wide on iPad.
- **R5 Motion rates.** The rings move outward once per pulse (one cell per 0.1 s) and the flares fade once per strike;
  neither repeats on its own, and both are at rest under Reduce Motion and, by R2, under Reduce Flashing.
