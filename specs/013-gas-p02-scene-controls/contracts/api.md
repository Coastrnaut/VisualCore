# Contract: Phase 02 API and UI

```swift
// VisualCoreSimulation
public struct SceneClock: Sendable, Equatable {
  public static let maxDelta: Double; public static let reducedMotionFactor: Double
  public init(duration: Double = 120, speed: Double = 1, isPlaying: Bool = true)
  public private(set) var time: Double; public private(set) var isPlaying: Bool; public var speed: Double {get set} (clamped 0…4)
  public var reducedMotion: Bool; public let duration: Double
  public mutating func advance(by delta: Double); public mutating func scrub(to time: Double)
  public mutating func play(); public mutating func pause(); public mutating func toggle()
}
// VisualCoreParameters
public struct ParameterEditor: Sendable, Equatable {
  public init(schema: ParameterSchema, values: [String: Double] = [:]) throws(ParameterError)   // resolves values as baseline
  public let schema: ParameterSchema; public private(set) var values: [String: Double]; public private(set) var baseline: [String: Double]
  @discardableResult public mutating func set(_ name: String, to value: Double) -> Bool
  @discardableResult public mutating func set(_ name: String, normalized t: Double) -> Bool
  public func normalized(_ name: String) -> Double; public func isModified(_ name: String) -> Bool; public var modifiedNames: [String]
  public mutating func reset(_ name: String); public mutating func resetAll(); public mutating func rebase(_ values: [String: Double]) throws(ParameterError)
  public func formatted(_ name: String) -> String
}
// VisualCoreUI
public struct ParameterPanel: View { public init(editor: Binding<ParameterEditor>) }
```

App UI identifiers:
- `gas.controls.open`, `gas.controls.sheet`;
- `gas.time.playPause`, `gas.time.scrub`, `gas.time.value`;
- `gas.preset.<id>`, `gas.palette.<id>`, `gas.seed.shuffle`, `gas.seed.value`;
- recovery `gas.recovery.message` and `gas.recovery.useDefault`;
- panel rows `vc.param.<name>`, `vc.param.<name>.reset` and `vc.param.resetAll`.
