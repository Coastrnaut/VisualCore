# Contract: Light Maze feedback (feature 099)

## Action
| Action | Values | Effect | Refusal |
|---|---|---|---|
| `hint.show` | none | selects the hinted turnable tile | `a13.already-solved` when the board is solved |

Native controls: Hint (`experience.a13.light-maze.hint`) sends `hint.show`; Describe
(`experience.a13.light-maze.describe`) shows and speaks the full description (no action, no state change).

## Words
- Hint: "Hint: turn the mirror at row R, column C." / "Hint: turn the prism at row R, column C."
- Refused hint: "Level N is already solved."
- Solve: "Level N solved in M moves. Level N+1 is open." — the second sentence only when the solve opened it; "move"
  singular for 1.
- Summary (canvas accessible value): the A13-P01 canvas description with "K of T targets lit" before the solved words:
  "Light Maze: level 1, First light; 1 mirror, 1 target; beam ends at the wall; 0 of 1 targets lit; not solved."

## Success cue
- Once per transition to solved: border (success colour) and tick polyline while solved; brightness per
  `SuccessCue.brightness`; sound: sine 660 → 990 Hz, 0.25 s, attack 0.01 s, release 0.1 s, gain 0.3, no noise;
  haptic `success`; words as above. Suspension stops the sound and ends the brightening.

## Signs
Nine states with distinct signs (spec clarification 4); colours ≥ 3 : 1 against the board.
