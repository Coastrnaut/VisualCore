# Research: A01-P05

APIs verified by the read-only audit (2026-11-11):
- `EffectScene(content:graph:)`, `reduceFlashing`, `flashLimitPerSecond` (default 0.3), `effectiveGraph`, `lastError`
  (VisualCoreEffects/EffectScene.swift);
- the `flashLimit` pass keeps mean Rec. 709 luma change ≤ limit per second (EffectPasses.swift);
- `EffectGraphValidator` rejects a graph whose output is not produced by a pass, so an empty graph is invalid and a
  one-pass `copy` graph is used;
- RenderHost observes `UIApplication.didEnterBackgroundNotification` (finish, then suspend) and
  `willEnterForegroundNotification` (resume); `recreateContext()` is public; `resources.stats.staleRejected` and
  `leaked` exist;
- `SceneClock.reducedMotion` and `reducedMotionFactor` (0.5);
- SDK: `MADimFlashingLightsEnabled()` and `kMADimFlashingLightsChangedNotification`
  (MediaAccessibility/MAVideoAccommodations.h, iOS 16.4+), `UIAccessibility.isReduceMotionEnabled` and
  `UIAccessibility.reduceMotionStatusDidChangeNotification`;
- XCTest `XCUIApplication.performAccessibilityAudit(for:_:)` (iOS 17+).

- **R1 Where the preferences live.** Decision: VisualCoreSimulation. It is pure and already holds the reduced-motion
  factor that the resolution feeds. Alternatives: a new module (rejected: an extra product for three small types), or
  VisualCoreUI (rejected: not host-testable, Principle IV).
- **R2 Resolution.** effective = choice == .system ? systemValue : (choice == .on). Rate = reduceMotion ? 0.5 : 1. An
  unknown raw value decodes to `.system`.
- **R3 Limiter wiring.** Always wrap the clocked scene in `EffectScene` with a one-pass copy graph. When Reduce
  Flashing is not effective, `bypassEffects` renders the content directly, so the default path is unchanged and costs
  nothing. Alternative: `replaceScene` on each toggle, rejected because it tears down and rebuilds every resource and
  resets the clock state.
- **R4 Bypass semantics.** `render` with `bypassEffects` calls `content.render(context, frame)` on the host-bound
  framebuffer and never touches the renderer, so the limiter's model and history survive. `setup`, `resize` and
  `teardown` are unchanged, so resources are identical in both modes.
- **R5 Flash test.** Content is a test `ArtScene` that clears to black on even frames and white on odd ones, wrapped
  the way the app wraps scenes. Each frame is read back and its mean luma computed. With limiting, |Δ| ≤ 0.3 × (1/60)
  + 1/255. Without limiting, |Δ| ≈ 1.
- **R6 Background simulation.** Tests post the two UIApplication notifications on `NotificationCenter.default`,
  which is what the host observes. While backgrounded, `renderOneFrame` returns false; after foreground it returns
  true. A real background transition is campaign II.
- **R7 Audit.** `try app.performAccessibilityAudit()` covers all audit types, with an issue handler that returns true
  (ignored) only for issues whose element is `gas.scene.canvas` and whose type is contrast. Each ignored issue is
  logged, and the documented list is kept in the regression baseline. The largest text size is set with the launch
  arguments `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`.
- **R8 Flashing-light notification.** `kMADimFlashingLightsChangedNotification` is posted on the local notification
  center, which bridges to `NotificationCenter.default`, so it is observed by name like the Reduce Motion
  notification (analyze U1).
