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
- **As built (A23-P02):**
  - more identifiers: `move-left`, `move-right`, `move-up`, `move-down` (the selected node by 32 points, the native
    form of `node.move`), `node-row-<id>` (select) and `connection-<target>-<index>` (a connection line of the list);
  - the overlay is drawn over the host, which keeps it out of the accessibility tree, so the list form is the spoken
    path for every node, port and connection (labels from `EditMessages`);
  - the presenter learns the canvas size in points from `pointer`'s `viewSize` and the overlay's report, 1,024 × 768
    until then; test seams also `mirror`, `grid` and `clamp`.
- **As built (A23-P05, feature 170):** `add-node` and `input-<id>-<index>` are no longer a menu and a picker but
  inline expanding button lists (`add-node-<kind>`, `input-<id>-<index>-option-<tag>` with tags `none` and
  `<id>-<output>`), and the Examples menu likewise (`examples`, `example-<id>`), because XCTest never saw the app idle
  while a system menu was open over the 30-frames-a-second canvas.
