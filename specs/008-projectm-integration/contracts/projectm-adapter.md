# Contract: ProjectM reference adapter (Phase 7)

Extends `specs/002-architecture-contracts/contracts/tests-adapter-submodule-regression.md` (FR-F109).

```swift
// VisualCoreRendering (app-neutral)
public enum GLState { @MainActor public static func resetForVisualCore(framebuffer: UInt32, width: Int, height: Int) }   // batch 2a
extension RenderContext { public func redirected(to framebuffer: UInt32, width: Int, height: Int) -> RenderContext }   // EffectScene content capture

// Harnesses/ProjectMReference (not a library; the R1 exception)
@MainActor final class ProjectMScene: RenderScene {
  init(presetPath: String)
  var signal: SyntheticSignal; var loader: PMGLLoadProc          // injectable (tests force creation failure)
  var engineGeneration: Int?; var enginesCreated: Int; var frames: Int; var lastError: Error?
  var viewports: [(width: Int, height: Int)]; var hasEngine: Bool; var presetPath: String
  func loadPreset(path: String) -> Bool          // inside a frame / with context current; failure keeps the previous preset
  func requestPreset(path: String)               // from UI: applied at the start of the next render
}
@MainActor final class EngineFramebufferPath: RenderScene {   // baseline path A (reference renderer sequence)
  init(presetPath: String, width: Int, height: Int)
  var signal: SyntheticSignal; var captureNextFrame: Bool; var captured: [UInt8]; var frames: Int; var lastError: Error?
}
struct SyntheticSignal { mutating func next(frames: Int) -> [Float]; mutating func chunksForVideoFrame(maxFramesPerCall: Int, videoRate: Double = 60) -> [[Float]] }
enum ImageDiff {
  struct Result { var meanAbs: Double; var within8: Double; var passes: Bool; func passes(noiseFloorWithin8: Double) -> Bool }
  static func compare(_ a: [UInt8], _ b: [UInt8]) -> Result?; static func litFraction(_ p: [UInt8], threshold: UInt8 = 8) -> Double
}
```

Baseline rule (SC-F702, amended 2026-11-10): `Result.passes(noiseFloorWithin8:)` with the floor measured in the same run by
two identical `EngineFramebufferPath`s (`EngineNoiseFloorTests`).

Rules: the harness never writes to `External/projectm-ios`; links only VisualCoreRendering, VisualCoreEffects,
VisualCoreEffectsGraph and ProjectMBridge; no preset library, StoreKit, AudioCore or CaptureKit; bundle id
`dev.visualcore.harness.ProjectMReference`.
