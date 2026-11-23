# Data model: R02-G13-03

| Entity | Fields | Rules |
|---|---|---|
| `AcousticConstellatorSceneSnapshot` | stars (positions, rates, starting phases), links, symbol, listen report, threshold, hold, window, stage, failure, actionsLeft, budget, levelNumber, time | immutable; built from the adapter |
| `AcousticConstellatorPalette` | sky #05060F, star #F4F1E8, hand #F4F1E8, silver #B8C0D0, teal #3FD6C6, guide #8A5A9C, broken #FF6B4A, coherenceLit #3FD6C6, coherenceUnlit #2A2433, thresholdMark #F4F1E8, holdLit #3FD6C6, holdUnlit #3A3348, movesLit #B8C0D0, movesUnlit #2A2433, shell #6FE0D8, glow #8FF4EA | linear colours in 0 … 1 |
| `AcousticConstellatorTier` | level-0: pulse, 2 wave shells, 2 glow shells; level-1: pulse, no shells, 1 glow shell; level-2: no pulse, none | richest first; logged with reason on change |
| `AcousticConstellatorExperienceCore` | level number, play | digest = level number + play fingerprint; snapshot schema 1 `{level, records}` |
| Mesh streams | sky, guides, links, broken links, stars, hands, coherence bars and mark, hold pips, moves bars: normal, uv = (material code, local coordinate); glow and shells: colour in the normal slot | the pulse moves by uniforms |
| Controls | `link.add [a, b]`, `link.remove [a, b]`, `star.nudge [s, ±1]`, `constellation.listen`, `play.undo`, `play.redo`, `level.next`; chosen star and partner (star −/+, partner −/+) | kernel refusals pass through with their codes; the choices do not touch the kernel |
| Candidate registration | id `r02-g13.acoustic-constellator`, tiers, palette, capabilities, content facts (100 levels, the pinned digest), scenario manifest | `available: false` until X-R02-G13 |
