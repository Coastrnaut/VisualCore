# Contract: effects API (Phase 4)

```swift
// VisualCoreEffectsGraph (pure)
public struct EffectGraphDescription: Codable, Equatable { version, passes, output }
public enum EffectGraphValidator { static func validate(_ g: EffectGraphDescription, width: Int, height: Int,
                                    quotaBytes: Int = 256 << 20) throws(EffectGraphError) -> ValidatedGraph }
public enum PassSchemas { static func schema(for type: String) -> PassSchema?; static let maxPasses = 32 }
public struct FlashLimiterModel { init(limitPerSecond: Double = 0.3); mutating func step(measured: Double, dt: Double) -> (displayed: Double, gain: Double) }

// VisualCoreEffects (iOS)
@MainActor public final class EffectRenderer { init(graph: EffectGraphDescription, registry: ResourceRegistry) throws
  func render(scene: RenderTarget, size: (Int, Int), time: Double, delta: Double) -> RenderTarget?  // final output
  var failedPasses: Set<String>; var reduceFlashing: Bool; func invalidate() }   // resize / recreation
@MainActor public final class EffectScene: RenderScene { init(content: RenderScene, graph: EffectGraphDescription)
  var reduceFlashing: Bool; var lastError: Error? }
```
Pass parameters and defaults: `PassSchemas` (documented in `Packages/VisualCoreRendering/README.md`).
