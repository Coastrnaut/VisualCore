# Data model: R02-G14-03

| Entity | Fields | Rules |
|---|---|---|
| `MoonlitMechanismSceneSnapshot` | gears (teeth, phases at the shown key frame, blades, depths, centres, slot tables), lamp height and count, wall size, shown key frame with its cast, target and forbidden cells, run report, stage, failure, actionsLeft, budget, levelNumber, time | immutable; built from the adapter |
| `MoonlitMechanismPalette` | night #070A14, paper #E8DFC8, ink #1A1822, gear #C9A24A, rim #E2C277, blade #B08A3C, lamp #8FB4E8, lampGlow #B7CFF2, target #4A6FA8, forbidden #B03A3A, stray #7A3A5A, broken #FF6B4A, cardLit #C9A24A, cardUnlit #2A2A38, alignLit #8FB4E8, alignUnlit #2A2A38, movesLit #E2C277, movesUnlit #2A2A38, glow #F2E2B0 | linear colours in 0 … 1; gear alpha 0.6, blade alpha 0.5 |
| `MoonlitMechanismTier` | level-0: 6 segments per tooth, soft edge, 2 glow shells; level-1: 4 segments, soft edge, 1 glow shell; level-2: 2 segments, none | richest first; logged with reason on change |
| `MoonlitMechanismExperienceCore` | level number, play, shown key frame | digest = level number + play fingerprint; snapshot schema 1 `{level, records}` |
| Mesh streams | backdrop, wall, shadow squares and feathers, outlines, marks, gears (rim, notch, spokes), lamp and ladder, cards, pips, bars: normal, uv = (material code, local coordinate); glow: colour in the normal slot | rebuilt when phases, lamp, shown key frame, stage or tier change |
| Controls | `handle.turn [±1]`, `gear.reseat [g, ±1]`, `lamp.step [±1]`, `machine.run`, `play.undo`, `play.redo`, `level.next`, `frame.show [k]`; chosen gear (gear −/+) | kernel refusals pass through with their codes; the choice does not touch the kernel |
| Candidate registration | id `r02-g14.moonlit-mechanism`, tiers, palette, capabilities, content facts (100 levels, the pinned digest), scenario manifest | `available: false` until X-R02-G14 |
