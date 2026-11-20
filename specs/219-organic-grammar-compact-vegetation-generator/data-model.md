# Data model: R02-F19

| Entity | Fields | Rules |
|---|---|---|
| PlantRule | predecessor (Character), successors [(word, weight)] | 1 … 8 successors, each ≤ 256 symbols; weights finite > 0 |
| PlantGrammar | start, rules, generations, angle δ, step, radius, radiusFactor, seed | ≤ 64 rules, unique predecessors; generations 0 … 12; δ finite 0 … π; step and radius finite > 0; radiusFactor 0 < k ≤ 1; JSON schema 1 |
| PlantBranch | start, end (Vec3), radius, depth | depth = bracket depth |
| PlantMarker | kind (petal, cap, leaf), position, heading, left, up, size | frame orthonormal |
| PlantSkeleton | branches, markers | branches ≤ 65,536 |
| PetalShape | length ℓ, width w, curl c, segments n | 0 < ℓ ≤ 100; 0 < w ≤ ℓ; abs(c) ≤ π; n 2 … 64 |
| CapShape | radius R, height h, rim d, sides s, rings k | 0 < R ≤ 100; 0 < h ≤ 100; 0 ≤ d < h; s 8 … 128; k 2 … 64 |
| StemShape | length L, baseRadius r₀, tipRadius r₁, bend b, sides s, segments m | 0 < L ≤ 100; r₀ ≥ r₁ > 0; abs(b) ≤ π; s 3 … 64; m 1 … 64 |
| PlantInstance | position, scale, yaw, variant, model | model = T · R_y(yaw) · S(scale) |
| PlantError | generations, wordLimit, rule, weight, brackets, turtleParameter, shapeParameter, branchLimit, scatterArea, scatterParameter, newerSchema, malformed | `reasonCode` `r2-f19.*` |
