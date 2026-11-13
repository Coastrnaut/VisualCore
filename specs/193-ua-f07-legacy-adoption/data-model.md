# Data model: UA-F07

## 1. Experience frameworks before the move (research R1)

| Framework target | Sources | Excluded (app only) | Resources |
|---|---|---|---|
| `GenerativeArtStudioExperience` | `Apps/GenerativeArtStudio/App`, `Apps/GenerativeArtStudio/GenerativeArtStudioAdapter` | `GenerativeArtStudioApp.swift`, `LaunchCleanup.swift`, `AppAutomation.swift` (`LaunchComposition.swift` stays: `GalleryView` uses it; corrected 2026-11-13) | `Apps/GenerativeArtStudio/Shaders` (folder) |
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
core has schema version 1, and its `outcome` is `work-saved` (A01: a composition saved), `canvas-painted` (A02: a
splat reached the fields since the last reset), and for A03 and A04 an outcome the completion scenario can reach
(corrected 2026-11-13: `ScenarioManifestValidator` requires the completion scenario to expect an outcome).

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

## 6. As built (2026-11-13)

The adapters as they stand at the end of UA-F07, under `Packages/ExperiencesCreative/<Name>/Experience/Adapter`. A
control written `x.<name>` exists once per parameter of the current family; the number in brackets is the count of
values the action carries.

| Experience | Core | Controls | Levels | Outcome |
|---|---|---|---|---|
| A01 | `GenerativeArtCore` | `family[1]`, `preset[1]`, `palette[1]`, `resetAll[0]`, `seed.shuffle[0]`, `seed.set[1]`, `play[0]`, `pause[0]`, `scrub[1]`, `rate[1]`, `save[0]`, `open[1]`, `rebase[0]`, `parameter.<name>[1]`, `value.<name>[1]`, `reset.<name>[0]` | 1 | `work-saved` (a composition saved) |
| A02 | `FluidArtCore` | `stroke[6]` (x, y, vx, vy, phase, pointer), `pinch[1]`, `brush[1]`, `splash[0]`, `pause[0]`, `resume[0]`, `step[0]`, `reset[0]`, `palette[1]`, `edges[1]`, `detail[1]`, `viscosity[1]`, `dyeFade[1]`, `motionFade[1]`, `quality[1]`, `tuningReset[0]` | 3 (`FluidQuality`) | `canvas-painted` (a splat reached the fields) |
| A03 | `FractalCore` | `mode[1]`, `pan[2]`, `pinch[3]`, `zoomIn[0]`, `zoomOut[0]`, `resetView[0]`, `cap[1]`, `cap.up[0]`, `cap.down[0]`, `palette[1]`, `animate[1]`, `seed[2]`, `goTo[3]`, `tour.start[1]`, `tour.stop[0]`, `radius[1]`, `bookmark.open[1]` | 1 | `deep-zoom` (1,000× or more) |
| A04 | `ParticleCore` (replay `{seed, anchor, rebases, steps, log}`) | `family[1]`, `emitter.add[0]`, `emitter.remove[0]`, `emitter.select[1]`, `size[1]`, `lifetime[1]`, `gradient[1]`, `trails[1]`, `trailStrength[1]`, `blend[1]`, `force.kind[1]`, `force.place[2]`, `force.nudge[2]`, `force.center[0]`, `strength[1]`, `play[0]`, `pause[0]`, `step[0]`, `reseed[0]` | 4 (`SceneQuality`, draw share 1, 0.75, 0.5, 0.25) | `scene-built` (three emitters) |

Each core has schema version 1, and its scenario manifest holds the nine standard scenarios and five
`fixture-<n>` scenarios with digests at seed 7 (`scenario-manifest.json` beside the Core, kept equal by a host
test). Package layout per experience: `<Name>Core`, `<Name>CoreTests`, `<Name>Experience` and
`<Name>ExperienceTests`. The standalone targets of A01–A03 are retired; A04's stays until X-A04 and compiles the
moved sources.
