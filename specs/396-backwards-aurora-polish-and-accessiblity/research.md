# Research: R02-G10-06

- **R1 Pure plans.** Decision: announcement and haptic plans are pure functions of the old and new core (and a refusal
  code), as in features 376 and 386. Rationale: exact host tests; nothing timing-dependent.
- **R2 Fade only the lights.** Decision: ease the aurora's glow, the won lift, the tear cross and the freeze preview
  ribbon; kink crosses and the ribbon's shape follow the player's reversals (as Nocturne Garden's shadow cells do).
  Rationale: the flashing risk is in the glow, the win, the failure mark and the preview that a hold can toggle; a
  reversal is a deliberate, paced player action. The presenter keeps the last preview's samples while its light fades
  out, so the ribbon does not vanish in one frame. Alternatives: cross-fading the ribbon's shape between reversals
  (rejected: a second ribbon for little gain).
- **R3 Sound from the aurora.** Decision: the root follows the worst bend against the limit (110 Hz × 1, 9/8, 5/4, 4/3
  for at most 1×, 2×, 4× the limit or more), one partial per matched checkpoint up to four, an octave when won, halved
  when failed; a loop length at which every partial has a whole number of cycles. Rationale: the sound reflects the
  state without being a puzzle aid beyond what the panel shows; pure and testable.
- **R4 Panel layout.** Decision: as features 376 and 386 — scrolling, Dynamic Type, wrapping rows, adjustable ends, a
  summary element, at most 520 points wide on iPad.
- **R5 Motion rates.** Measured from the shader constants: shimmer 1.6 rad/s (0.25 cycles per second), pulses at most
  0.24 beads per second past a point; both below 3, both still under Reduce Motion (time 0). No change needed.
