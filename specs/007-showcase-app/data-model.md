# Data model: Phase 6

- **ShowcaseSceneDescriptor**: `id` (stable, kebab-case: `gradient-texture`, `animated-geometry`, `distortion`,
  `particles`, `post-processing`), `title`, `summary`, `accessibilityDescription`, `interactionHint`,
  `makeScene: (ShowcaseSettings) -> ShowcaseRenderScene`. Catalog order is fixed; ids unique (tested).
- **ShowcaseRenderScene** (protocol over `RenderScene`): `status: String` (scene-specific diagnostics, e.g.
  `touch=x,y`, `passes=a>b>c`, `particles=n zoom=z`), `lastError: String?`, `handle(_ PointerEvent)`.
- **ShowcaseSettings**: `reduceMotion` (system or `-uitestReduceMotion`), `reduceFlashing` (defaults to
  reduceMotion, user toggle), `injectShaderError` (debug launch argument only).
- **DiagnosticsSnapshot**: `fps`, `frames`, `state`, `generation`, `liveResources`, `liveBytes`, `peakBytes`,
  `warnings`, `leaked`, `error` (`none` or message). Label format:
  `frames=<n> fps=<f> state=<s> gen=<g> live=<n> bytes=<b> peak=<b> warnings=<n> leaked=<n> error=<none|…>`.
- **AuditReport** (JSON): `{target, layers: {spec, packages, imports, binary}: {checked: [...], findings: [...]}, passed: Bool}`.
