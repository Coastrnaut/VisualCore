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
  `stone.place` [3], `stone.select` [2], `stone.cycle` [1], `stone.move` [2], `stone.rotate` [1], `stone.remove` [],
  `tool.mode` [1].
