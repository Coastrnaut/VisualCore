# Data Model: A20-P03 (feature 147)

- **`StoneShape`:** exponents per kind (river-pebble 2.0, flat-slate 2.6, round-granite 2.0, tall-basalt 3.0,
  moss-boulder 2.2), heights per kind (0.6, 0.35, 0.7, 1.0, 0.8), radii = kind radii × scale, rotation, wobble
  ≤ 6 % from a sine series seeded by the id; `contains(_ point:)`, `height(at:)` (dome (1 − d²)^½ × height, 0
  outside), `bounds`.
- **`StoneLayer`:** 480 × 360 cells of (height, kind index + 1, 0 when empty), rasterized in ascending depth so a
  higher stone overwrites a lower one.
- **`StoneSelection`:** `topmost(at:in:)` (the highest-depth stone whose shape contains the point, or nil);
  `cycle(from:direction:in:)` in depth order, wrapping.
- **`GardenCore` additions:** `toolMode` (0 rake, 1 stones), `selectedStone` (UInt32?, state only); actions
  `stone.place` [3], `stone.select` [1: id, 0 = none], `stone.move` [2], `stone.rotate` [1], `stone.remove` [],
  `tool.mode` [1]; selecting an id that no stone has is refused without a change.
- **As built (convergence T-A20-311):**
  - The stone target stores (height, (kind + 1)/5, 0, 1) without an offset in both `rgba16f` and `rgba8`.
  - `stone.place` also selects the new stone. The stone cap is refused with `a20.stone-cap`, and its message shows
    until the garden is below the cap; selection refusals are `a20.no-selection` and `a20.unknown-stone`.
  - A move or turn to the stone's current value is accepted without a command.
  - The presenter and the nudges clamp before sending (the engine refuses values outside 0…1); the core clamps again.
  - A positive rotation turns clockwise on screen ("Turn right" is +15°). A two-finger turn sends the old rotation
    minus the recognizer's counter-clockwise angle, wrapped into −π…π; the spoken degrees are positive clockwise.
  - A tap is a finger that lifts within 10 points of where it landed. A drag that starts off the selected stone sends
    nothing; a second finger drops a one-finger drag and starts a turn.
  - Cycling from no selection gives the lowest stone ("Next") or the highest ("Previous"); "n of count" counts from
    the lowest stone.
  - The selection clears after an undo or redo whose stone is gone, after a restore and after a reset; it survives a
    tool change.
  - Shadow: five taps toward the light at 2, 4, …, 10 cells, each occluded by smoothstep(0, 2, height × 12 cells − d);
    a full shadow darkens the sand by 40 %.
  - Manifest: fixtures `fixture-stone-placed`, `-moved`, `-rotated`, `-removed`, `-remove-undone` and six rejection
    entries (move, rotate, remove without a selection; an unknown id; a fractional `tool.mode`; kind 5).
