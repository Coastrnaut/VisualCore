# Contract: float fields, legend and time step (feature 119)

```swift
final class WaveGPU {             // Experience; internal; requires FloatRenderSupport
    init(registry: ResourceRegistry, gridSize: Int) throws        // throws WaveGPUError.floatTargetsUnavailable / .compile
    func load(_ field: SimulationField) -> Bool                    // current → red, previous (or current) → green
    func step(courant: Float, damping: Float, count: Int) throws   // edge cells written 0
    func readBack() -> SimulationField                             // red → current, green → previous
    var current: RenderTarget { get }
    func release()
}
enum SimulationShaders { static let reactionDisplay: String; static let waveDisplay: String }   // sampler uField
struct SimulationLegendValues: Equatable { kind; minimum: Float; maximum: Float; alive: Int; dead: Int
    static func of(_ field: SimulationField, kind: SimulationKind) -> SimulationLegendValues
    var words: String }                                            // in the canvas description
struct SimulationLegend: View                                      // makeCanvasOverlay returns it
// SimulationPresenter (additions)
static var forceFloatUnsupported: Bool        // test seam
private(set) var floatSupported: Bool
private(set) var floatLoadCount: Int, floatStepCount: Int
static let reloadInterval = 64
static let unsupportedSentence = "Reaction-diffusion and the wave field need floating-point render targets, which this device does not offer."
```

The action: `sim.timestep [Δt]` (declared range 0.05…2.0).
- Accepted for reaction-diffusion with 0.1 ≤ Δt ≤ 1.5625, and for the wave with Δt in 0.05…1 and c · Δt ≤ 1/√2.
- Refused with `a16.unstable` beyond either limit, with the sentence `SimulationRefusal.reactionStep` or `.courant`.
- Refused with `a16.invalid-choice` when Δt is outside the family's own range, or for the automaton.
- On acceptance the field, the step count, running and speed are kept.

Tolerance: `FloatFieldToleranceTests` passes when the smaller of max |GPU − CPU(float16)| and
max |GPU − CPU(float16TowardZero)| is ≤ 0.01 after 10 steps on 16 × 16, for each family.
