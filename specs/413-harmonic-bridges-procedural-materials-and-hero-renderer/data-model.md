# Data model: R02-G12-03

| Entity | Fields | Rules |
|---|---|---|
| `HarmonicBridgesSceneSnapshot` | islands, strings (ends, length, peg, locked), report, modes per step and string, threshold, start, goal, steps, stage, failure, actionsLeft, budget, levelNumber, time | immutable; built from the adapter |
| `HarmonicBridgesPalette` | ground #07060C, islandFace #7A4A2E, islandEdge #E0A070, string #C88A5A, membrane #4FD8E8, markFilled #B8F4FF, markHollow #7A6A9C, start #F2D2A8, goal #A894FF, glow #8FF4FF, shell #6FE0F0, pip #4FD8E8, pipUnlit #3A3348, gaugeLit #E0A070, gaugeUnlit #2A2433 | linear colours in 0 … 1 |
| `HarmonicBridgesTier` | level-0: motion, 2 wave shells, 2 glow shells; level-1: motion, no shells, 1 glow shell; level-2: at rest, none | richest first; logged with reason on change |
| `HarmonicBridgesExperienceCore` | level number, play | digest = level number + play fingerprint; snapshot schema 1 `{level, records}` |
| Mesh streams | ground, prisms (faces and edges), start ring, goal star, strings, membranes, marks, glow rings, pips, gauge: normal, uv = (material code, local coordinate); glow and shells: colour in the normal slot | the wave and the shown step move by uniforms |
| Controls | `string.tune [s, p]`, `crossing.test`, `play.undo`, `play.redo`, `level.next`; chosen string and peg (string −/+, peg −/+) | kernel refusals pass through with their codes; the chosen string and peg do not touch the kernel |
| Candidate registration | id `r02-g12.harmonic-bridges`, tiers, palette, capabilities, content facts (100 levels, digest b832e7ee…c737), scenario manifest | `available: false` until X-R02-G12 |
