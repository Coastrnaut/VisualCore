# Data model: R02-G15-03

| Entity | Fields | Rules |
|---|---|---|
| `VoxelOrigamiSceneSnapshot` | cubes (cells, orientations, parents, rest directions), turns, turnable hinges, chosen hinge, target cells at the best alignment, report, stage, failure, actionsLeft, budget, levelNumber, time | immutable; built from the adapter |
| `VoxelOrigamiPalette` | night #0B0D16, ivory #EDE8DC, ivoryShade #B9B2A3, target #2EE6D6, targetGlow #8FF5EC, hinge #7F7A70, hingeChosen #FF3C8C, glyphSolid #2EE6D6, glyphHollow #4A4E5C, dots #3A3D48, coveredLit #FF3C8C, coveredUnlit #2A2D3A, movesLit #2EE6D6, movesUnlit #2A2D3A, broken #FF6B4A, glow #FFF4E0 | linear colours in 0 … 1 |
| `VoxelOrigamiTier` | level-0: 2 bevel steps, edges 0.06 s, 2 glow shells; level-1: 1 step, 0.05 s, 1 shell; level-2: no bevel, 0.04 s, none | richest first; logged with reason on change |
| `VoxelOrigamiExperienceCore` | level number, play, chosen hinge | digest = level number + play fingerprint; snapshot schema 1 `{level, records}` |
| Mesh streams | backdrop, target wireframes, cubes (faces, bevels, glyphs, dots), hinge bars, pips, bars: normal, uv = (material code, local coordinate); glow: colour in the normal slot | rebuilt when the cells, the chosen hinge, the stage or the tier change |
| Controls | `hinge.turn [h, ±1]`, `play.undo`, `play.redo`, `level.next`, `hinge.choose [h]` | kernel refusals pass through with their codes; the choice does not touch the kernel |
| Candidate registration | id `r02-g15.voxel-origami`, tiers, palette, capabilities, content facts (100 levels, the pinned digest), scenario manifest | `available: false` until X-R02-G15 |
