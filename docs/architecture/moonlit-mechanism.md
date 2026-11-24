# Moonlit Mechanism (R02-G14) — rules

Experience `r02-g14.moonlit-mechanism` (free) of the one VisualCore app; package `Packages/ExperiencesRound02`, target
`MoonlitMechanismCore` (feature 431, R02-G14-01). A train of interlocking gears stands in front of a lamp; each gear
carries open and solid blades whose shadows fall on a paper wall. Turning the handle turns the whole train; re-seating a
gear shifts it by one tooth against its neighbours; raising or lowering the lamp moves every shadow by its gear's depth.
The wall shows a sequence of key frames, each with a target symbol. A run steps the machine through the key frames and
wins when every meshing pair is aligned, every required key frame's target is covered within the stray allowance and no
key frame shadows a forbidden cell. Everything here is pure, exact integer logic; drawing, controls and sound come in
later features of R02-G14.

## Gears, the train and the wall

- **Gears.** 2 … 5; gear 0 is the driver; every other gear meshes with exactly one lower-index parent, so the train is a
  tree. Each gear has 6 … 20 teeth, a starting phase in whole teeth, a blade pattern (one bit per slot, at least one
  solid and one open), a depth 1 … 3, a centre on the wall and a slot table (per slot, the wall-cell offsets, within ±8,
  that a solid blade at that slot covers).
- **Meshes.** A pair (parent p, child c) has the divisor g = gcd(Tₚ, T_c), at least 2, and an alignment value a below
  it; the pair is aligned when (phaseₚ + phase_c) mod g = a. Its angular relation error is the cyclic distance from
  alignment (0 … ⌊g / 2⌋).
- **Wall.** W 8 … 24 × H 6 … 16 cells, numbered row by row; 2 … 5 lamp heights with a starting height.
- **Key frames.** 2 … 6, each with a handle-turn count (strictly increasing, the first ≥ 0), a non-empty target and a
  required flag (at least one required); 0 … 12 forbidden cells, disjoint from every target; a stray allowance 0 … 4;
  an action budget 1 … 40.

## Turns, re-seats, the lamp and shadows

- **Turn.** A gear's direction is +1 at an even distance from the driver and −1 at an odd one; a turn of ±1 moves every
  gear to (phase + direction · step) mod T. Meshing gears move by +s and −s, so a turn never changes an alignment.
- **Re-seat.** Moves one gear (never the driver) by ±1 tooth; it can break the alignment with its parent and children.
- **Lamp.** Steps the height by ±1 within range.
- **Shadow.** The blade at bit b of a gear at phase q sits at slot (b + q) mod T; a solid blade covers its slot's
  offsets from the gear's centre, moved down by height · depth rows (the light matrix as an integer shift that grows with
  depth); cells off the wall are dropped. A key frame's shadow is the union over every gear at the set-up's phases
  turned by the key frame's turns.

## Runs, failures and the truth metric

A run (one action) first checks every mesh in child order and is `jammed` by the first misaligned pair; it then walks
the key frames in order: a shadow on a forbidden cell fails `forbidden` (the lowest-numbered cell) at any key frame; at
a required key frame uncovered target cells fail `missing` and more stray cells than the allowance fail `stray`;
otherwise the level is won. After any other action, a budget fully spent without a win fails `budget`. The truth metric
— every pair's alignment error and every key frame's covered, missing, stray and forbidden counts — is reported after
every action (`MoonlitMechanismRunReport`) and never decides on its own.

## Play, records and the puzzle contract

The play (`MoonlitMechanismPlay`) follows loading → tutorial (when the level has one) → playing ⇄ paused → won or
failed → result. Actions are validated in the order stage, previous fingerprint, action (`r02-g14.stage`,
`r02-g14.stale`, `r02-g14.action`); every accepted action appends a record with previous and next fingerprints (SHA-256
of the schema, the level fingerprint, the phases, the lamp height, the actions spent, the stage and the failure). Undo
and redo restore exact states; undo from failed returns to playing (an honest retry, recorded); a won level is final.
A trace replays to the same states. Levels are JSON schema 1 with sorted keys and a fingerprint, re-checked on decode
(`r02-g14.level`, `r02-g14.newer-schema`, `r02-g14.malformed`). `MoonlitMechanismRules` expresses the rules as an
R02-F23 `PuzzleRules` (moves in the order turn −1, +1; every re-seat by gear, −1 then +1; lamp −1, +1 in range; run) for
the level certification of R02-G14-02.
