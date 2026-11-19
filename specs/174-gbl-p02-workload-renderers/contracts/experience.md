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
- **As built (A24-P02):** the scenario manifest holds the nine standard scenarios and five fixtures (the planning
  catalog's count: `fixture-case-quads`, `fixture-case-alu`, `fixture-case-particles`, `fixture-run-start-stop`,
  `fixture-refused-fraction`); the outcome is `case-<id>` of the selected case; the frame probe of the quads case is
  computed from the last drawn frame at the centre of checker cell (1,2) and expects the red colour class, the other
  cases declare none; the case titles are "Textured quads", "Shader ALU" and "Particles".
