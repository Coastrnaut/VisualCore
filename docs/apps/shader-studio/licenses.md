# Shader Studio — licenses and provenance (A22-P01, feature 159; A22-P03, feature 161)

Everything Shader Studio ships is code written for this repository. No image file, stored texture, font file, model, sound file,
generated asset or third-party asset is bundled. A person's own shaders are their own work and stay on the device.

| Content | Source | License |
|---|---|---|
| Starter templates `gradient`, `noise-flow`, `rings` (GLSL ES 3.00 fragment sources and their uniforms) | written for VisualCore (A22-P01) over VisualCore's GLSL library `vc/` | original, the repository's license |
| Starter template `texture-mix` (GLSL ES 3.00 fragment source mixing two texture inputs by `u_blend`) | written for VisualCore (A22-P03) | original, the repository's license |
| Textures `checker`, `ramp`, `noise` (64 × 64 RGBA made in Swift by `TextureRecipes` at run time, never stored as images) | written for VisualCore (A22-P03); numbers only | original, the repository's license |
| Template prelude `ss/prelude.glsl` (precision, inputs, the time and resolution uniforms, the output) | written for VisualCore (A22-P01) | original, the repository's license |
| GLSL ES 3.00 keyword, type and built-in word lists of the editor's tokenizer | facts of the OpenGL ES Shading Language 3.00 specification; names only | facts, not copyrightable; the list is the repository's license |
| Limits (source bytes, lines, uniforms, texture inputs) | written for VisualCore; numbers only | original, the repository's license |
| GLSL library `vc/` (hashes, gradient noise, fbm, colour) | VisualCore (`Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/`) | the repository's license |

The editor uses the system's monospaced font. Nothing is downloaded.
