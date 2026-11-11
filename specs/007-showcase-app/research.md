# Research: Phase 6

- **R1 Project spec** — Decision: root `project.yml` (XcodeGen 2.46.0) with targets `Showcase` (application),
  `ShowcaseTests` (unit, hosted) and `ShowcaseUITests`; local packages `Packages/VisualCore`,
  `Packages/VisualCoreRendering`. Rationale: README §8 makes it the single source of truth for Showcase and
  apps. Alternatives: `Showcase/Showcase.yml` (harness style) — rejected for the canonical rule.
- **R2 Dependency audit** — Decision: `scripts/audit_showcase_dependencies.py` with four layers:
  (a) parse `project.yml` (target dependencies, packages, frameworks, sources) for deny-listed names/paths
  (`External/projectm-ios`, ProjectMBridge, ANGLERendering, Rendering, PresetLibrary, CaptureKit, CaptureUI,
  AudioCore, Diagnostics(reference), CANGLE, CFlashLimiter, ProjectM.xcframework, projectM, MilkDrop);
  (b) resolved package graph (`swift package show-dependencies --format json` for each local package plus
  the xcodebuild `-showBuildSettings`-free check of `Package.resolved`, if any) must contain no deny-listed
  package; (c) `import` lines in `Showcase/` sources; (d) every Mach-O in the built `.app`: `otool -L` libraries
  and `nm -a` symbols matching `projectm|milkdrop|presetlibrary|projectmbridge` (case-insensitive). Output
  JSON report; exit 1 on any finding. Fixtures (`scripts/fixtures/showcase_audit/`) cover import, package
  reference, linked framework and symbol list contamination; `test_scripts.py` runs them. Note: the ANGLE
  libEGL/libGLESv2 frameworks are allowed (renderer baseline, constitution I) even though built in the
  reference tree; only ProjectM engine/preset/bridge modules are denied.
- **R3 Scenes** — gradient+texture: bundled shaders via `ShaderLibrary` (`common.glsl` include), texture from
  `checker.png` decoded with `CGImage` → RGBA8 → `Texture.upload(rgba:)`. Animated geometry: `MeshRenderer`
  (cube + sphere) on an `OrbitCamera`, `Timeline` spin; drag orbits. Distortion: content gradient rendered into
  a target, custom ripple pass whose center/strength follow the drag (bundled `ripple.frag`) — demonstrates
  touch-driven shaders. Particles: F05 `ParticleSystem` + `PrimitiveRenderer` + gestures. Post-processing:
  `EffectScene` over the animated content with graph colorMatrix → bloom → distort (+ flashLimit when Reduce
  Flashing); toggle switches between the graph and passthrough copy.
- **R4 Diagnostics** — `RenderHost` lifecycle state/generation/presentedFrameCount/framePacing,
  `resources.stats` (live counts/bytes/peak/warnings/leaked), `lastError`; overlay polls at 4 Hz on the main
  actor; "Simulate context loss" calls `recreateContext()`.
- **R5 Smoke test** — XCUITest: launch, for each `showcase.scene.<id>` open it, wait until the diagnostics
  label's `frames=` increases and `error=none`, go back; plus drag/pinch on particles, toggle on
  post-processing, context loss (generation +1, `leaked=0`), background/foreground. Runs on both runtimes.
- **R6 Texture upload** — `Texture.upload(rgba: [UInt8])` uses `glTexSubImage2D` for rgba8 textures, rejects
  size mismatches (returns false) and stale/released textures. Smallest framework change; simulator-tested.
