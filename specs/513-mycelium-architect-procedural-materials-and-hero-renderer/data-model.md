# Data model: R02-G22-03

| Entity | Fields | Rules |
|---|---|---|
| `MyceliumArchitectSceneSnapshot` | level (board, root, terminals, rocks, toxins, fixed nutrients, sites), arrangement, grown cells with pulses, parent indices and path weights, consumed nutrients, total weight, terminal pulses, pulses run, shown pulse, fit scale s, stage, failure, actions left, budget, nutrient budget, weight limit, level number, time | immutable; made by the adapter from the play; shown pulse 0 … pulses run |
| `MyceliumArchitectTier` | name, index, tubeSides (8, 6, 4), capSegments (16, 12, 8), fuzzStrands (6, 3, 0), spores (24, 12, 0), glowShells (2, 1, 0) | level-0 … level-2, richest first |
| `MyceliumArchitectPalette` | the colours of spec clarification Q3 | equal in Swift and GLSL |
| `MyceliumArchitectElement` | kind (backdrop, floor, site, toxin, rock, blocker, nutrient, vein, sprout, root, terminal, gauge, actionsBar, glow), index, item, centre | painter's order of research R4 |
| `MyceliumArchitectReferencePoint` | kind (boardCentre, root, terminal, gaugeMargin, actionsBar), index, centre | projected by the CPU reference |
| `MyceliumArchitectExperienceCore` | level number, play, shown pulse | controls of spec clarification Q5; digest domain `r02-g22.mycelium-architect.v1`; snapshot schema 1 `{level, records}` |

The material table (24 codes, backdrop 0 … spore 23; `a_uv.x` = code + 0.25 · value + 0.5 when broken) exists twice,
in the geometry and in the shaders, and a test pins the two equal (T-R02G2203-016).
