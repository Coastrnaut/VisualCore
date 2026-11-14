# Research: A05-P05

## D1 — Tier outside the digest
- **Decision**: the core stores `qualityTier` (not encoded in the snapshot, not written to the digest); the reference
  composition stays at 24 segments; the presenter draws a tier mesh.
- **Rationale**: `setQualityTier` must not change the digest; the camera rule needs a stable bounding radius.

## D2 — Levels
- **Decision**: Full/High/Medium/Low with element shares 1, ⅔, ½, ⅓ → 24/16/12/8 segments
  (`TessellationChoice.segments(full: 24, minimum: 8, share:)`).
- **Rationale**: a third of the triangles at Low meets "≤ 50%"; 8 segments keep petals recognisably round.

## D3 — Cache
- **Decision**: `MeshCache(maxEntries: 16, maxBytes: 32 MiB)`, key `UInt64` (`StableHash` of the signature fields),
  value `Mesh`, LRU by a use counter; a mesh larger than `maxBytes` is returned but not stored; `maxEntries == 0`
  disables storing.
- **Rationale**: deterministic, host-testable, bounded memory (manual risk 1).

## D4 — Proportion checks
- **Decision**: kaleidoscope pixel bounding box; tilings via the presenter's world-to-pixel mapping at a probe pair;
  solid via the projected bounding sphere using the drawn camera and the view aspect.
- **Rationale**: tilings fill the view, so their extent cannot be measured; the mapping is what keeps proportions.
