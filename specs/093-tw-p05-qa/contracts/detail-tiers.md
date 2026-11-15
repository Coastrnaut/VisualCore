# Contract: A12-P05 detail tiers, pressure and claims

- Tiers: 0 → terrain level 0 (64 × 64 cells; city 48 × 48), 1 → level 1 (32; 24), 2 → level 2 (16; 12); draws world parts
  (2; asteroid garden 1) + props at every tier; thumbnail 160 × 120 at every tier.
- Policy: tier = max(host tier clamped 0…2, Low Power Mode ? 2 : 0, memory floor); a memory warning holds tier 2 until
  30 s of frame time after the last warning; thermal steps come from the host's governor. A tier change rebuilds the
  terrain renderer once; the world, its document and digest never change.
- Quality: `WorldsCore.qualityTiers` 3; profile `level-0…level-2`; registration `quality_tiers` the same.
- Stale objects: 20 load/unload cycles keep the live counts of cycle 1; close leaves 0 objects and 0 leaks.
- Claims scan refuses (whole words, case-insensitive; README non-goals line exempt): accurate, accuracy, precise,
  precision, scientific, realistic, real-world, geographic, fps, frames per second, battery, `<number> ms`.
