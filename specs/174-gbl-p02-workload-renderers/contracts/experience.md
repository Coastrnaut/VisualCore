# Contract: Graphics Benchmark Lab experience (A24-P02)

- **Factory:** `GraphicsBenchmarkLabExperience.make(id:storage:)` returns the shell, as `VisualProgrammingLabExperience`.
- **Core:** `BenchCore: ExperienceCore`, controls `case.select [0…2]`, `run.start []`, `run.stop []`.
- **Presenter:** `BenchPresenter: ExperiencePresenter`; `maxFramesPerSecond` 60; quality tier `level-0`; `makeControls`
  gives `GBLControls`; test seams: `recorder`, `workloadFrame`, `drawnFrames`, `feedTime` (synthetic frame times).
- **Accessibility identifiers** (prefixed `experience.a24.graphics-benchmark-lab.`): `case-quads`, `case-alu`,
  `case-particles`, `run-start`, `run-stop`, `status`, `summary`.
- **VisualCore names used:** `ExperienceCore`, `ExperienceControl`, `ExperienceSnapshot`, `DigestBuilder`,
  `StateDigest`, `ExperiencePresenter`, `ExperienceShell`, `ExperienceActionPort`, `RenderContext`, `FrameInfo`,
  `FieldPass`, `FieldUniform`, `RenderTarget`, `ResourceRegistry`, `ParticleRenderer`, `ParticleInstance`,
  `ParticleBlend`, `Camera2D`, `ViewMetrics`, `Vec2`, `Vec4`.
