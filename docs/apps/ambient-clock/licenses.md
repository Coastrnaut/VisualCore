# Ambient Clock — licenses of the visual content (A18-P03, feature 133)

Everything the clock draws is code written for this repository. No image, texture, font file, model, sound or
generated asset is bundled.

| Content | Source | License |
|---|---|---|
| Theme "Noise gradient" (fragment in `Experience/NoiseGradientTheme.swift`) | written for VisualCore over the `vc/noise.glsl` and `vc/color.glsl` library | original, the repository's license |
| Theme "Particle drift" (`Experience/ParticleDriftTheme.swift`) | written for VisualCore; procedural discs in hashed cells over `vc/hash.glsl` | original, the repository's license |
| Theme "Wave field" (`Experience/WaveFieldTheme.swift`) | written for VisualCore; a sum of sine waves | original, the repository's license |
| Theme "SDF shapes" (`Experience/SDFShapesTheme.swift`) | written for VisualCore over `vc/sdf.glsl` | original, the repository's license |
| Palettes (`Core/ThemeCatalog.swift`) | chosen for this experience; numbers only | facts (colour values), no license needed |
| Time and date text | the system font, drawn by SwiftUI | part of iOS; nothing bundled |

The time and date strings come from the system's own locale data through Foundation's formatters. Nothing else is
bundled, and nothing is downloaded.
