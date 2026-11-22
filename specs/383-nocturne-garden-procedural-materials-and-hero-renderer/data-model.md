# Data model: R02-G09-03

| Entity | Fields | Rules |
|---|---|---|
| `NocturneGardenSceneSnapshot` | width, height, target, forbidden, shadow and leaking cells (sorted), blooms (kind, column, row, size), sun, stage, failure, moves, budget, levelNumber, time | immutable; built from the adapter; cells within the bed |
| `NocturneGardenPalette` | ground #0A1230, mist #B8C4E0, mistHighlight #E6ECF7, shadow #05060A, gold #E8C872, coral #FF7A5C, leak #FF3B30, body #10131C, glow #FFB88A, lantern #FFD9A0, spent #FF7A5C, unspent #3A4558 | linear colours in 0 … 1 |
| `NocturneGardenTier` | level-0: 3 mist layers, stem depth 3, feather 0.3, 2 glow shells; level-1: 2, 2, 0.15, 1; level-2: 1, 1, 0, 0 | richest first; logged with reason on change |
| `NocturneGardenExperienceCore` | level number, play | digest = level number + play fingerprint; snapshot schema 1 `{level, records}` |
| Mesh streams | ground, mist, shadow, feather, rim, hatch, crosses, stems, leaves, heads, lantern, marks: normal, uv = (material code, shade); glow: colour in the normal slot, uv = (glow, 0) | mist drift and sway move by uniforms |
| Controls | `bloom.plant [0 … 5, column, row, size]`, `bloom.move [bloom, column, row]`, `bloom.resize [bloom, size]`, `bloom.remove [bloom]`, `sun.set [elevation]`, `play.undo`, `play.redo`, `level.next`; pickers (kind, column, row, size, bloom) | kernel refusals pass through with their codes; pickers do not touch the kernel |
| Candidate registration | id `r02-g09.nocturne-garden`, tiers, palette, capabilities, content facts (100 levels, digest ce13750a…52dd), scenario manifest | `available: false` until X-R02-G09 |
