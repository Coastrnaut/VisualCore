# Data model: A05-P05

- **GeometryCore.qualityTier**: Int 0…3 (clamped), default 0; not in the snapshot or digest. `segments(forTier:)` =
  `TessellationChoice.segments(full: 24, minimum: 8, share: GeometryCore.qualityProfile.levels[tier].elementShare)`.
- **Mesh signature** (cache key): StableHash of (kind, order, repeats, scale, motif seed, segments).
- **MeshCache**: maxEntries (≥ 0), maxBytes (≥ 0); counts hits, misses, evictions; entries (key, mesh, bytes, lastUse).
