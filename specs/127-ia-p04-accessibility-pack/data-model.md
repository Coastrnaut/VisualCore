# Data model: A17-P04 (feature 127)

| Entity | Fields | Rules |
|---|---|---|
| `AnchoredLabelLayout.Candidate` (VisualCore) | id Int, anchor Vec3, size Vec2 (points), priority Int | ordered by priority, then id |
| `AnchoredLabelLayout.Placement` (VisualCore) | id, point Vec2 (projected anchor), box (minX, minY, maxX, maxY) | canvas points with y down; box minX = x + 6, maxY = y − 6, minY = maxY − height, maxX = minX + width; inside the canvas; no positive-area overlap; ≤ budget |
| `AnatomyLayerSign` | layer, sign ("●", "◆", "▲"), words, colorHex | `stateSignProblems(signs) == []` |
| `AnatomyContentPack` | envelope kind `a17.content-pack`, schemaVersion 2, payload region; digest SHA-256 hex | 1 → 2 wraps the bare region; ≤ 262,144 bytes; damaged, too large, newer refused |
| `AnatomyProvenance` | textLicense, geometryLicense, citations [(id, license)], review status, review sentence | every license in the allowed set; sentence non-empty |
| Gesture steps | drag 0.3°/point (turn every 50 points, tilt every 33.3), pinch at 1/0.85 and 0.85, ≤ 64 steps per event | pinch 3, drag 2, tap 1 |
