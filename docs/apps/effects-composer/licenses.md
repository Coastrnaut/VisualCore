# Effects Composer — licenses and provenance (A25-P06, feature 185)

Everything Effects Composer ships is code written for this repository. No third-party code, font, image file, stored
texture, model, sound file, generated asset or other third-party asset is bundled with the experience. A picture the
person picks in the system photo picker is their own input: it is held in memory only and never bundled or stored. A
person's own looks are their own and stay on the device, in the experience's own storage.

| Content | Source | License |
|---|---|---|
| The five effects `grade` (Color grade), `blur` (Blur), `distort` (Distort), `vignette` (Vignette) and `posterize` (Posterize), version 1, with their parameters, ranges and defaults (`Core/EffectDefinition.swift`) | written for VisualCore (A25-P01); names and numbers only | original, the repository's license |
| The effects' fragment programs (`Core/EffectPrograms.swift`) and their CPU references (`Core/EffectReference.swift`); the colour domain of each effect (`Core/ColorDomain.swift`) | written for VisualCore (A25-P01, A25-P05) over VisualCore's GLSL library `vc/` (`vc_srgbDecode`, `vc_srgbEncode`) | original, the repository's license |
| The built-in test picture (`Core/TestImage.swift`): red rising with the column, green with the row, blue on a checker | written for VisualCore (A25-P01, A25-P02); computed in code | original, the repository's license |
| The chain, its editing and history, the pass plan (`Core/EffectChain.swift`, `Core/ChainEditing.swift`, `Core/PassPlan.swift`) | written for VisualCore (A25-P01, A25-P02) | original, the repository's license |
| The preview renderer, the picture import, the export, the looks library, the presenter, the controls and the adapter (`Experience/`, `Experience/Adapter/`) | written for VisualCore (A25-P02 … A25-P06) | original, the repository's license |
| Chain file `a25.effect-chain`, look file `a25.preset` and looks index `a25.preset-library` formats; the committed samples `ExperienceTests/Fixtures/` | written for VisualCore (A25-P01, A25-P03, A25-P06); written by the experience's own encoders | original, the repository's license |
| Status lines, sentences and spoken labels (`Experience/ECControls.swift`, `Experience/ComposerPresenter.swift`, `Experience/Adapter/ComposerCore.swift`) | written for VisualCore (A25-P02 … A25-P05) | original, the repository's license |
| GLSL library `vc/` (colour) | VisualCore (`Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/`) | the repository's license |
| VisualCore packages the experience depends on: `VisualCoreExperience`, `VisualCorePersistence`, `VisualCoreMath`, `VisualCoreScenes`, `VisualCoreDiagnostics`, `VisualCoreRendering`, `VisualCoreExperienceHost`, `VisualCoreUI` (`Packages/ExperiencesCreative/Package.swift`) | VisualCore (`Packages/VisualCore`, `Packages/VisualCoreRendering`) | the repository's license |
| System frameworks: Foundation, SwiftUI, UIKit, Observation, PhotosUI (`PhotosPicker`), CoreTransferable (`ShareLink`'s file), ImageIO, CoreGraphics, UniformTypeIdentifiers | part of iOS; linked, not bundled | Apple's platform terms; nothing redistributed |

The experience adds no third-party package (`Packages/ExperiencesCreative/Package.swift` depends only on the local
VisualCore packages). The app's own third-party components (ANGLE and the libraries inside it) are listed in
`docs/legal/third-party.json`, bundled under the app's `Licenses` folder and shown in the app's Acknowledgements; none
of them is added by this experience. The controls are native views drawn with the system's fonts; no font file is
bundled. Nothing is downloaded.
