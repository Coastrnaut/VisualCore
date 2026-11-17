# Data model: A19-P02 (feature 139)

- **`StillImageFormat`** (`VisualCoreRendering`): png, jpeg, heic, each with a `typeIdentifier`. `isAvailable(_:)`
  reads `CGImageDestinationCopyTypeIdentifiers()`.
- **`StillImageEncoder.data(_:format:quality:)`:** opaque, sRGB, with quality 0…1 (default 0.9; ignored for PNG).
  Throws `.encoding` when the format is unavailable or a step fails.
- **`ExperienceSession.renderStill(width:height:time:)`** and **`ExperienceStillRenderer(timed:)`** with
  `callAsFunction(width:height:time:)`; the existing two-argument forms use time 0.
- **Core `ExportFormat`** gains jpeg and heic. `WallpaperProject` stays schema 1, since a format string unknown to an
  older build is already refused as damaged.
- **`CropFrame`:** `frame` (x, y, width, height in canvas points), `top`, `bottom` and `sides` band rectangles.
  `fit(template:orientation:canvasWidth:canvasHeight:margin:)` uses a margin of 0.06 × the short canvas edge, keeps
  the template aspect within one point, and stays inside the canvas.
- **`WallpaperCore`** (`ExperienceCore`, snapshot schema 1):
  - fields: scene 0…3, preset 0…2, parameters (three values, unused ones 0), template 0…8, orientation 0/1,
    animation time 0…3600, format 0…2 and motion 0/1;
  - controls: the eight of clarification Q5;
  - the digest covers every field;
  - outcome `scene-<id>`;
  - `qualityTiers` is `["level-0", "level-1"]`, matching the presenter's two levels and the registration's
    `quality_tiers`, declared now so the X-A19 follow-through finds them equal.
- **`StillExport`:**
  - state idle → planned → rendered → encoded → verified → written, or cancelled or failed with a reason (no-limit,
    does-not-fit, format-unavailable, render, encoding, verification);
  - it owns `TemporaryFolder("LivingWallpapers-Export")` and removes its file on cancel or failure.

## As built (T-A19-217)

- **Export limit:** the presenter reads `context.resources.maxTextureSize` at setup, because a presenter cannot
  reach `RenderHost.maxRenderSize`. A size the host still refuses fails with the reason `render`; the tests pass
  `host.maxRenderSize` directly.
- **`StillExport`:**
  - the retry goes through `run(plan:time:render:cancelAfter:)` with `ExportRefusal.offeredPlan(format:)`;
  - an exporter keeps one file: a new run removes the previous file, and `discard(_:)` removes a handed-back one;
  - a failed file write is `encoding`, and the planner's `unknownTemplate` (impossible from the core's index) is
    `does-not-fit`.
- **`WallpaperCore`:**
  - the seed from `prepare(seed:)` is in the digest, and `restore(payload:seed:)` gives the restored core that seed;
  - the snapshot keys are the eight fields;
  - `scene.parameter` values are declared 0…40 (the union of the scenes' ranges) and checked against the chosen
    scene's own range;
  - `qualityProfile` level-1 has resolution and iteration shares of 0.5.
- **Presenter:**
  - one probe, "corner" at (0, 0), expected dark: every scene darkens its extreme corners to a quarter of the
    preset's deepest colour, which also shows in exported files;
  - `maxFramesPerSecond` is 30.
