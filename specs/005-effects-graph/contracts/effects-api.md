# Contract: effects API (Phase 4)

```swift
// VisualCoreEffectsGraph (pure)
public struct EffectGraphDescription: Codable, Equatable, Sendable { version (= 1), passes, output }
public struct EffectPassDescription: Codable, Equatable, Sendable { id, type, inputs: [String: String], output, scale = 1, params: [String: [Double]] }
public let effectSceneSource = "scene"
public enum EffectGraphValidator { static let defaultQuota = 256 << 20
  static func validate(_ g: EffectGraphDescription, width: Int, height: Int, quotaBytes: Int = defaultQuota)
    throws(EffectGraphError) -> ValidatedGraph }   // order, estimatedBytes, parameters (defaults + clamps), warnings
public enum PassSchemas { static let maxPasses = 32; static let all: [String: PassSchema]; static func schema(for type: String) -> PassSchema? }
public struct FlashLimiterModel { init(limitPerSecond: Double = 0.3); static let maxDelta = 0.1; var adapted: Double?
  mutating func step(measured: Double, dt: Double) -> (displayed: Double, gain: Double, bias: Double); mutating func reset() }

// VisualCoreEffects (iOS)
@MainActor public final class EffectRenderer {
  init(graph: EffectGraphDescription, registry: ResourceRegistry, quotaBytes: Int = EffectGraphValidator.defaultQuota) throws  // structure validated before GPU work
  func render(scene: RenderTarget, time: Double, delta: Double) throws -> RenderTarget   // final output, valid until the next call
  var failedPasses: Set<String>; var lastOrder: [String]; var lastWarnings: [String]
  func invalidate() }   // resize / recreation: drops programs and histories, rebuilt next frame
@MainActor public final class EffectScene: RenderScene { static let flashLimitPassID = "__flashLimit"
  init(content: RenderScene, graph: EffectGraphDescription)
  var graph; var reduceFlashing: Bool; var flashLimitPerSecond: Double (= 0.3)   // changes rebuild the renderer
  var effectiveGraph: EffectGraphDescription   // graph + final flashLimit pass when reduceFlashing
  var renderer: EffectRenderer?; var lastError: Error? }

// VisualCoreRendering (F03, made public for effects diagnostics)
ResourceRegistry.warn(_ message: String) -> Bool   // deduplicated warning in the ledger
```

Behavior: undeclared input slots are warned about and ignored; `cycle` names only passes on a cycle;
intermediate targets return to the pool after their last consumer within a frame (FR-F407); a failing
pass copies its first input and is reported once per generation (FR-F408).
Pass parameters and defaults: `PassSchemas` (documented in `Packages/VisualCoreRendering/README.md`).
