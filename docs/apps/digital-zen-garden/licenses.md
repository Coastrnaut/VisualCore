# Digital Zen Garden — licenses and provenance (A20-P01, feature 145)

Everything Digital Zen Garden draws is code written for this repository. No image, texture, font file, model, sound
file, generated asset or third-party asset is bundled.

| Content | Source | License |
|---|---|---|
| Tray `small-tray` (4:3 aspect, 160 × 120 reference sand field) | written for VisualCore; numbers only | original, the repository's license |
| Sand tones `pale`, `warm`, `grey` (one opaque sRGB colour each) | chosen for this experience; numbers only | facts (colour values), no license needed |
| Rake style `fine-rake` (5 tines, 0.06 tray widths wide, depth 0.6) | written for VisualCore; numbers only | original, the repository's license |
| Rake style `wide-rake` (3 tines, 0.10 tray widths wide, depth 1.0) | written for VisualCore; numbers only | original, the repository's license |
| Stone kinds `river-pebble`, `flat-slate`, `round-granite`, `tall-basalt`, `moss-boulder` | written for VisualCore; procedural shapes from base radii in tray widths; drawn in A20-P03 | original, the repository's license |
| Groove profile depth·cos(2π·tines·u/width) for \|u\| ≤ width/2 | written for VisualCore; a cosine formula | original, the repository's license |
| Relief shader `SandScene.reliefFragment` (normals from height differences, one light, grain, tone) | written for VisualCore (A20-P02) over VisualCore's GLSL library `vc/` | original, the repository's license |

Sound is optional, made of procedural
tones from VisualCoreAudio and off by default; it is listed here when it is added. Nothing else is bundled, and
nothing is downloaded.
