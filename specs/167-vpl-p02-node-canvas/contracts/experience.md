# Contract: Visual Programming Lab experience (A23-P02)

- **Factory:** `VisualProgrammingLabExperience.make(id:storage:)` returns the shell, as `ShaderStudioExperience` does.
- **Core:** `LabCore: ExperienceCore`, controls:
  `node.add [0…6, −4096…4096, −4096…4096]`, `node.move [1…9999, −4096…4096, −4096…4096]`, `node.remove [1…9999]`,
  `node.select [0…9999]`, `edge.connect [1…9999, 0…1, 1…9999, 0…2]`, `edge.disconnect [1…9999, 0…2]`.
- **Presenter:** `LabPresenter: ExperiencePresenter`; `maxFramesPerSecond` 30; quality tier `level-0`;
  `makeCanvasOverlay` gives `CanvasOverlay`; `makeControls` gives `LabControls`; `pointer` maps touches per the
  spec's clarification Q3; test seams: `view`, `feedback`, `drawnFrames`.
- **Accessibility identifiers:** `node-<id>`, `port-<id>-in-<index>`, `port-<id>-out-<index>`, `wire-<target>-<index>`,
  `add-node`, `remove-node`, `node-list`, `input-<id>-<index>` (a picker), `status`, `feedback`.
- **VisualCore names used:** `ExperienceCore`, `ExperienceControl`, `ExperienceSnapshot`, `DigestBuilder`,
  `StateDigest`, `ExperiencePresenter`, `ExperienceShell`, `ExperienceActionPort`, `RenderContext`, `FrameInfo`,
  `FullScreenShaderScene`, `ShaderBundle`, `PointerEvent`, `PointerPhase`, `PlaneViewport`, `Vec2`.
