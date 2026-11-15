# Data model: A12-P05

| Entity | Fields | Rules |
|---|---|---|
| `DetailTier` | index 0…2, terrain columns, rows, vertices (per preset), draws(props) = 2 + props, thumbnail 160 × 120 | lower tiers never raise a count; derived, never saved |
| `TierPolicy` | lastWarning: Double? (frame-clock seconds); hold 30 s | tier = max(host, lowPower ? 2 : 0, held ? 2 : 0); presentation only, never saved |
| `WorldState` | unchanged (schema 2) | the digest never depends on the tier |
