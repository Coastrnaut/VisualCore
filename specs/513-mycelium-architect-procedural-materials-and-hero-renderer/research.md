# Research: R02-G22-03

- **R1 One fit rule per level.** Decision: s = 1.9 / max(W, H); cell (c, r) at ((c + 0.5 − W/2)·s, 0.05 + (H/2 − r −
  0.5)·s, 0). Rationale: every board fills the same square, nothing a player does changes the scale, and the CPU
  reference uses the same function.
- **R2 Presentation sources outside the kernel scans.** Decision: the adapter, snapshot, geometry, shaders and scenarios
  live in `Core/Presentation/`; feature 511's invariant scans and feature 512's `Core/Content` scan keep their file
  lists: both list one directory without recursion (`contentsOfDirectory` of `Core/` and of `Core/Content/`,
  checked 2026-11-27), so a subfolder stays outside them. Rationale: shaders legitimately contain
  `sin(`/`cos(` and the snapshot uses Doubles; the kernel's no-clock, no-float rules must keep applying to the kernel
  only (feature 503's lesson).
- **R3 Drawn values are judged values.** Decision: veins are drawn for exactly the kernel's segments with grown pulse
  ≤ the shown pulse, from parent to child cell centres; terminals are open exactly when the kernel's terminal pulse is
  ≤ the shown pulse; the weight fill is the kernel's total weight. Rationale: renderer purity (INV-10).
- **R4 Painter's order for everything.** Decision: backdrop, floor and grid, sites, toxins, rocks, blockers, nutrients,
  veins (in growth order), sprouts, root cap, terminal caps, gauges, actions bars, then the additive glow; depth testing
  off and no culling (the window surface has no depth buffer). Rationale: features 493 and 503.
- **R5 Tapered tubes.** Decision: each segment is a tube of n sides (8, 6, 4 by tier) whose radius goes from 0.16·s at
  the root end to 0.06·s by the child's path weight over the network's largest path weight; normals point outward from
  the tube axis; caps are flattened domes of 16, 12, 8 segments. Rationale: "instanced tapered cylinder branch segments
  and procedural cap mushrooms" with bounded triangle counts.
- **R6 Materials in uv, flats by signed distance.** Decision: as feature 503: `a_uv.x` = material code + value scale ·
  value + broken offset; flats (sites, pips, bars, rings) cut out by signed distance. Rationale: the shared renderer binds
  only position, normal and uv.
- **R7 Decoration only.** Decision: vein pulses (brightness travelling along path weight with time), toxin ripples,
  hyphae fuzz, spores and glow are decoration; Reduce Motion stops them; Reduce Flashing caps the glow. Rationale:
  renderer purity and accessibility.
- **R8 Shape is the non-colour twin.** Decision: every element kind has its own shape (spec edge cases); reached and
  unreached terminals differ by open/closed and filled/hollow pips. Rationale: FR-R02G2203-010.
- **R9 Camera.** Decision: eye (0, −1.9, 2.8) looking at (0, −0.3, 0), fitted to x −1.05 … 1.05, y −1.45 … 1.05,
  z 0 … 0.25 with a 5 % margin for aspect 0.4 … 2.5. Rationale: the board and gauges fit every phone and tablet aspect.
- **R10 The shown pulse.** Decision: `growth.show [pulse]` declares 0 … 128 so the engine refuses only values outside;
  the adapter refuses a pulse above the pulses run with `r02-g22.pulse` without touching the kernel; the shown pulse is
  never in the digest and resets to the pulses run after every action. Rationale: presentation state, as feature 503's
  shown tick.
- **R11 Reuse of R02-G21-03 patterns.** Decision: adapter structure, certified-candidate table, snapshot, presenter,
  fallback, tier log, frame probes, scenario manifest and registration follow `BinaryGardens…` one for one. Rationale:
  proven at X-R02-G21.
- **R12 Quality profile.** Decision: one `QualityLevel` per tier, best first, element share = spores / 24 (1, 0.5, 0)
  and the tier's tessellation; the Core's `qualityTiers` names equal the presenter's levels (X gate rule).
