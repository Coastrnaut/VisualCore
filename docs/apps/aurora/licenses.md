# Aurora — licenses and provenance (A21-P01, feature 152)

Everything Aurora draws is code written for this repository. No image, texture, font file, model, sound file,
recording, generated asset or third-party asset is bundled.

| Content | Source | License |
|---|---|---|
| Presets `polar-night`, `violet-veil`, `dawn-haze` (palettes and scene values) | written for VisualCore; numbers only | original, the repository's license |
| Scene bounds (ribbons 1…4, turbulence, cloudiness, stars 0…400, speed 0…2) | written for VisualCore; numbers only | original, the repository's license |
| Sky shader `aurora-sky.frag` (stars, clouds and ribbons over noise, a 600 s seamless loop) | written for VisualCore (A21-P01) over VisualCore's GLSL library `vc/` | original, the repository's license |
| Noise port `SkyNoise` and reference `SkyReference` | written for VisualCore; a Swift port of VisualCore's `vc/` hash and noise | original, the repository's license |
| GLSL library `vc/` (hashes, gradient noise, fbm) | VisualCore (`Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/`) | the repository's license |

The scenes are stylized art, not a depiction of measured aurora activity. The optional sound comes in later phases,
synthesised in code; it is listed here when it is added. Nothing else is bundled, and nothing is downloaded.
