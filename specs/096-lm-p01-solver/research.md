# Research: A13-P01 (feature 096)

## 0. Verified facts (2026-11-15)

- `Vec2` (Double, dot, scalar cross, length, normalized) and `Ray3`/`RayHit3` (`init?` refusing non-finite or zero
  directions) set the style; `Primitive`/`SceneNode` and `PrimitiveRenderer(… draw(root, camera:, metrics:))` draw 2D
  shapes and thick lines; Tiny Worlds' `ContentCatalog`/`LicenseAudit` and its experience layout (A12-P01) are the
  patterns reused.

## 1. Decisions

- **D1 Ray cast:** standard parametric ray–segment intersection with the 2D cross product: for segment a→b, s = b − a,
  q = a − origin, denom = cross(direction, s); |denom| ≤ 1e-12 → miss (parallel or collinear); t = cross(q, s)/denom,
  u = cross(q, direction)/denom; hit when t > minimumDistance and 0 ≤ u ≤ 1. Normal = perpendicular of s normalised,
  flipped to face the ray. Alternatives: slab tests per tile (rejected: grid-specific; the generic cast serves walls,
  mirrors, targets and the board edge alike).
- **D2 Reflection:** d − 2(d·n)n; incidence and reflection angles equal by construction; the fixture sweeps 360
  incidence angles against horizontal, vertical and 45° segments and checks the angles and |d| within 1e-12.
- **D3 Tracer:** a branch is (origin, direction, excluded segment indices); the first branch starts at the emitter
  cell's centre with the emitter's own four segments excluded (later branches that hit the emitter end with
  "emitter"); each step casts against all tile segments and the
  4 board edges, excluding the last segment; the tile owning the hit decides: wall, target, emitter → end; mirror →
  reflect; prism → reflect and push a straight-on branch (continuing past the prism with the prism's segment excluded);
  board edge → end. Cycle detection keys on (cell entered, direction) across all branches of one trace (a branch
  reaching a state already visited ends with "loop"); caps per clarification 3. Branches are processed in a FIFO order,
  so segments are deterministic.
- **D4 Levels:** 20 levels written as Swift data (`LevelCatalog.bundled`), each verified by a test (valid, unsolved at
  start, solved by its recorded solution); fixtures pin the solved beams of levels 1, 10 and 20.
- **D5 Drawing:** a `SceneNode` tree per state: background rect, a faint grid, tiles (walls filled squares, mirrors
  and prisms thick diagonal lines, targets squares with a lit ring, emitter triangle), the beam as lines of width 0.08
  cell from the tracer's segments; a `Camera2D` fitting the board into the canvas.

## 2. As built (2026-11-15)

- **Grid-snapped reflection (D3):** after `Vec2.reflected(about:)` the tracer snaps the direction to the nearest grid
  direction (`Direction.nearest`); unsnapped, a 45° mirror gives (2e-16, 0.9999999999999998) and the path would drift
  off the cell centres. With snapping every hit lies exactly on cell centres, target squares and board edges; the
  fixtures pin exact values.
- **Loops:** with mirrors alone a loop always returns to the emitter (the rules are reversible and the emitter blocks),
  so "loop" appears only where prism branches meet states already traced; the cycle key is (cell left, direction); a
  prism's straight-on branch keeps its parent's bounce count; splits refused at the 16-branch cap are counted
  (`droppedBranches`).
- **Levels (D4):** the 20 layouts were designed for this repository: lm-01 by hand, lm-02…lm-20 laid out with a small
  search over the same rules for a single solution, then named, reviewed and fixed as Swift data — original content,
  author "VisualCore project", MIT. The tests prove each is valid, unsolved at start and solved by its recorded solution;
  uniqueness of the solution is not claimed (the solvability checker is A13-P05).
- **Codec:** refusal reasons missing-license, unsupported-license, invalid-number, out-of-range, invalid-board,
  duplicate-id; an unreadable document is refused as a whole as `catalog`.
- **Manifest fixtures:** the scenario manifest holds five solved-level fixtures (`fixture-lm-01`, `-05`, `-10`, `-16`,
  `-20`) rather than three: the repository's content-count audit (`test_scripts.py`, `content-counts`) asks for at least
  the planning catalog's five; the first script-test run (`.autonomy/checks/A13-P01.script-tests.json`, exit 1) named
  it. The beam fixtures of the core stay at lm-01, lm-10 and lm-20.
- **Level menu:** every action has a native control; `level.select` is reached through the Level menu (T-A13-115).
