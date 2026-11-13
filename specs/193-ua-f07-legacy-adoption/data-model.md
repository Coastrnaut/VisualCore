# Data model: UA-F07

## 1. Experience frameworks before the move (research R1)

| Framework target | Sources | Excluded (app only) | Resources |
|---|---|---|---|
| `GenerativeArtStudioExperience` | `Apps/GenerativeArtStudio/App`, `Apps/GenerativeArtStudio/Adapter` | `GenerativeArtStudioApp.swift`, `LaunchCleanup.swift`, `LaunchComposition.swift`, `AppAutomation.swift` | `Apps/GenerativeArtStudio/Shaders` (folder) |
| `FluidArtPlaygroundExperience` | `Apps/FluidArtPlayground/App`, `…/Adapter` | `FluidArtPlaygroundApp.swift`, `AppAutomation.swift`, `TestMode.swift` | none |
| `FractalExplorerExperience` | `Apps/FractalExplorer/App`, `…/Adapter` | `FractalExplorerApp.swift`, `AppAutomation.swift` | none |
| `ParticleUniverseExperience` | `Apps/ParticleUniverse/App`, `…/Adapter` | `ParticleUniverseApp.swift`, `DeviceConditionsSource.swift` | none |

Each framework depends on its Core package and on the VisualCore products its app uses, plus VisualCoreExperience
and VisualCoreExperienceHost. The unified app links the four.

## 2. Adapter types per experience

| Experience | Core (Codable, `ExperienceCore`) | Controls (action ids and value counts) | Presenter wraps | Levels |
|---|---|---|---|---|
| A01 | `GenerativeArtCore { familyID, document: ArtDocument, presetID?, time, playing }` | `family[1]`, `preset[1]`, `palette[1]`, `parameter.<name>[1]`, `reset.<name>[0]`, `resetAll[0]`, `seed.shuffle[0]`, `play[0]`, `pause[0]`, `scrub[1]` | `ArtSceneFactory` scene with `fixedTime` | 1 |
| A02 | `FluidArtCore { configuration, palette, edges, detail, paused, pendingSplats, applied }` | `stroke[4]`, `pinch[1]`, `splash[0]`, `pause[0]`, `resume[0]`, `step[0]`, `reset[0]`, `palette[1]`, `edges[1]`, `detail[1]`, sliders `[1]` | `EffectScene(FluidFieldsScene)` | 3 |
| A03 | `FractalCore { mode, framing (center, span), juliaSeed, cap, radius, paletteID, animate, paletteTime, tour? }` | `mode[1]`, `pan[2]`, `pinch[3]`, `zoomIn[0]`, `zoomOut[0]`, `resetView[0]`, `cap.up[0]`, `cap.down[0]`, `palette[1]`, `animate[1]`, `seed[2]`, `goTo[3]`, `tour.start[1]`, `tour.stop[0]`, `bookmark.open[1]` | `FractalScene` with the viewport derived from the drawable size | 1 |
| A04 | `ParticleCore { scene: ParticleScene, commands, stepIndex, playing, … }` (replay) | `family[1]`, `emitter.add[0]`, `emitter.remove[0]`, `emitter.select[1]`, `size[1]`, `lifetime[1]`, `gradient[1]`, `trails[1]`, `trailStrength[1]`, `blend[1]`, `force.kind[1]`, `force.place[2]`, `force.nudge[2]`, `force.center[0]`, `strength[1]`, `play[0]`, `pause[0]`, `step[0]`, `reseed[0]` | `ParticleLayerScene` (source reads the core; no stepping in the callback) | 4 (draw cap) |

Values are normalized: positions are 0…1 of the view, and indexes are whole numbers within the list's range. Every
core has schema version 1, and its `outcome` is `work-saved` (A01: a composition saved), `nil` (A02, A03), or
`nil` (A04 until its later phases).

## 3. Candidates (research R6)

`ExperienceRegistry.candidates`: the registrations of A01–A04, each with `scenarioManifest` (the nine standard
scenarios plus one `fixture-<n>` scenario per regression fixture of the card, as `docs/catalog` lists them).

## 4. Test map (research R7)

`specs/193-ua-f07-legacy-adoption/test-map.csv`: one row per old test method, 56 rows, with the columns
`app, old_class, old_method, new_class, new_method, note`. `new_method` may name several methods, separated by
`;`. The note says why a behaviour maps to the unified app's equivalent.

## 5. Executed moves

`Catalog/path-map.json` (`schema: 1, moves: [{experience, from, to, commit}]`) and the matching entry of
`docs/migration/path-map.json` set to `done`.
