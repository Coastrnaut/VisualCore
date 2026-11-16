# Contract: paint, spec, histogram, presets and capture (feature 120)

```swift
// SimulationLabCore
public enum PaintMode: Int { case tap = 0, drag = 1 }
public enum SimulationBrush { public static func painted(_ field: SimulationField, kind: SimulationKind, x: Int, y: Int, mode: PaintMode) -> SimulationField? }
extension SimulationModel { public mutating func paint(x: Int, y: Int, mode: PaintMode) -> Bool }  // in SimulationModel.swift; false outside 0…63
public struct SimulationHistogram: Equatable, Sendable {
    public static let binCount = 16
    public let bins: [Int]; public let nonFinite: Int; public let low: Float; public let high: Float
    public static func of(_ field: SimulationField, kind: SimulationKind) -> SimulationHistogram
    public var fullestBin: Int }
public struct ExperimentPreset: Codable, Equatable, Sendable {
    public static let schemaVersion = 1; public static let licenses: Set<String> = ["original", "public-domain"]
    public var name: String; public var spec: SimulationSpec; public var palette: String
    public var annotation: String; public var source: String; public var license: String
    public func problem() -> String?                    // nil when valid
    public func encoded() -> Data; public static func decode(_ data: Data) -> Result<ExperimentPreset, PresetRefusal>
    public static let bundled: [ExperimentPreset] }     // Life, HighLife, Seeds, Spots, Mazes, Pulse

// Actions (SimulationCore)
// sim.paint [x 0…63, y 0…63, mode 0…1]         accepted inside the grid; step count unchanged
// sim.spec  [family 0…2, a, b, Δt 0.05…2]      a, b = rule index and 0 | feed, kill | speed, damping; spec validated

// Experience
@MainActor final class SimulationPresetStore {          // ExperienceStorage files preset-<uuid>.json
    static let cap = 24
    init(storage: ExperienceStorage)
    private(set) var entries: [(id: UUID, preset: ExperimentPreset)]; private(set) var problems: [String]
    func reload(); func save(_ preset: ExperimentPreset) -> String?   // nil or the refusal sentence
    func delete(_ id: UUID) }
@MainActor final class SimulationCapture {               // TemporaryFolder("a16-captures")
    static let size = 1024
    init(folder: TemporaryFolder = .init(name: "a16-captures"))
    private(set) var url: URL?; private(set) var message: String?
    func capture(_ render: (Int, Int) throws -> StillImage) }
```
