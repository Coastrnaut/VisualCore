# Graphics Benchmark Lab — licenses and provenance (A24-P06, feature 178)

Everything Graphics Benchmark Lab ships is code written for this repository. No image file, stored texture, font file,
model, sound file, generated asset or third-party asset is bundled. A person's own results are their own and stay on
the device, in the experience's own storage, unless the person exports them through the share sheet.

| Content | Source | License |
|---|---|---|
| Benchmark cases `quads` (Textured quads), `alu` (Shader ALU) and `particles` (Particles), version 1, with their settings and plans (`Core/BenchmarkCase.swift`) | written for VisualCore (A24-P01); names and numbers only | original, the repository's license |
| Workload pictures (`Experience/Workloads.swift`): the texture made in code (a checker of 16 cells mixed with VisualCore's value noise) drawn in layered full-screen field passes, the shader ALU field pass, and the instanced particles of `Core/ParticleField.swift` drawn by VisualCore's `ParticleRenderer` | written for VisualCore (A24-P02) over VisualCore's GLSL library `vc/` | original, the repository's license |
| Run file `a24.benchmark-run` (schema 3), CSV export, saved-result file `a24.saved-result` and results index `a24.result-library` formats; the committed samples `CoreTests/Fixtures/` and `ExperienceTests/Fixtures/` | written for VisualCore (A24-P01, A24-P03, A24-P04, A24-P06); written by the experience's own encoders | original, the repository's license |
| Statistics, dropped-frame, qualification and repeatability rules (`Core/Statistics.swift`, `Core/DroppedFrameRule.swift`, `Core/RunQualification.swift`, `Core/Repeatability.swift`) | written for VisualCore (A24-P01, A24-P03, A24-P05) | original, the repository's license |
| Status lines, sentences, spoken labels and "About these numbers" (`Experience/BenchPresenter.swift`, `Experience/GBLExplanation.swift`) | written for VisualCore (A24-P02 … A24-P05) | original, the repository's license |
| GLSL library `vc/` (hashes, value noise, colour) | VisualCore (`Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/`) | the repository's license |
| GPU timer `GPUFrameTimer` over `GL_EXT_disjoint_timer_query` | VisualCore (`Packages/VisualCoreRendering/Sources/VisualCoreRendering/GPUFrameTimer.swift`) | the repository's license |

Controls, results, the repeatability view and the explanation are native views drawn with the system's fonts. No
code, number or name of another benchmark tool is used. Nothing is downloaded.
