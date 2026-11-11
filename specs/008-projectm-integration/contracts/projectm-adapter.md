# Contract: ProjectM reference adapter (Phase 7)

Extends `specs/002-architecture-contracts/contracts/tests-adapter-submodule-regression.md` (FR-F109).

```swift
// VisualCoreRendering (app-neutral, batch 2a)
public enum GLState { @MainActor public static func resetForVisualCore(framebuffer: UInt32, width: Int, height: Int) }

// Harnesses/ProjectMReference (not a library; R1 exception)
@MainActor final class ProjectMScene: RenderScene {
  init(presetPath: String, signal: SyntheticSignal = .init())
  var engineGeneration: Int?; var enginesCreated: Int; var frames: Int; var lastError: Error?
  func loadPreset(path: String) -> Bool        // failure keeps the previous preset (reference FR-045)
}
struct SyntheticSignal { mutating func next(frames: Int) -> [Float] }
@MainActor final class EngineFramebufferPath { init(presetPath:registry:width:height:) throws; func render(signal:) ; var pixels: [UInt8] }
enum ImageDiff { static func compare(_ a: [UInt8], _ b: [UInt8]) -> (meanAbs: Double, within8: Double) }
```

Rules: the harness never writes to `External/projectm-ios`; links only VisualCoreRendering, VisualCoreEffects and
ProjectMBridge; no preset library, StoreKit, AudioCore or CaptureKit; bundle id `dev.visualcore.harness.ProjectMReference`.
