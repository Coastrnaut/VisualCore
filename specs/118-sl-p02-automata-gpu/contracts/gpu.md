# Contract: GPU paths (feature 118)

```swift
final class AutomatonGPU {        // Experience; internal
    init(registry: ResourceRegistry, gridSize: Int) throws
    func load(_ field: FieldGrid) -> Bool                  // CPU field (0 or 1) → RGBA8 red 0/255 into the read target
    func step(rule: AutomatonRule, count: Int) throws      // count ping-pong steps
    func readBack() -> FieldGrid                           // red ≥ 128 → 1
    var current: RenderTarget { get }                      // the target the display pass samples
    func release()
}
final class GrayScottGPU {        // Experience; internal; requires FloatRenderSupport
    init(registry: ResourceRegistry, gridSize: Int) throws
    func load(_ field: FieldGrid) -> Bool                  // two channels u, v
    func step(feed: Float, kill: Float, timeStep: Float, count: Int) throws
    func readBack() -> FieldGrid                           // readFloatPixels → u, v
    func release()
}
```
Tolerance: `GrayScottToleranceTests` passes when max |GPU − CPU| ≤ 0.01 after 10 steps on 16 × 16 against the CPU
reference rounded with `float16` or `float16TowardZero`; it fails with "Floating-point render targets are not
available" when `FloatRenderSupport.detect(in:)` reports no support.
