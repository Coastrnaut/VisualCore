# Data model: A17-P02 (feature 125)

| Entity | Fields | Rules |
|---|---|---|
| `AnatomyQuality` | level 0 / 1; revolution segments 48 / 24, tube sides 16 / 8, sphere 32 × 16 / 16 × 8; maxTriangles 60,000 / 20,000; maxDraws 32; maxLabels 16 | `levels.count == Core.qualityTiers == 2` |
| `MeshPlacement` | mesh id, kind, schematic parameters, model `Mat4` | one per declared mesh; every declared id has one |
| `SceneItem` | structure index (0…13), structure id, mesh id, layer, mesh, model, world triangles, world sphere (centre, radius) | mesh validates; closed kinds closed; within the level's budget |
| `AnatomyScene` | level, items (inventory order), structure spheres (14), region sphere, triangle count, draw count | over budget → `SceneRefusal(.overBudget)`; a missing declared mesh → `.missingMesh`; a build failure → `.buildFailed` |
| `AnatomyPick` | structure index, distance | nearest visible hit; ties by index; nil on a miss |
| `AnatomyCameraState` | turn (wraps 0…23, 15°), tilt −6…6 (10°), zoom −4…6 (× 0.85) | opening view turn 2, tilt 1, zoom 0; a step beyond a limit is refused |
| `AnatomyViewState` | schema 1, turn, tilt, zoom, visibleLayers [Bool × 3], selection (structure id?), framed (structure id?) | damaged, newer or unknown id refused; a selection on a hidden layer is cleared |
