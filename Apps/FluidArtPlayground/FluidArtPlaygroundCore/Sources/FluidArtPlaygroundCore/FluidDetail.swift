// FluidDetail.swift — the Simulation detail levels (feature 023 T-A02-503; FR-A02-511, MVP-06; clarification 4,
// research R4): square grids; the device cap is applied later by `FluidConfiguration.validated(maxEdge:)`.

/// Simulation grid levels: Low 64×64, Medium 128×128 (default), High 256×256.
public enum FluidDetail: String, CaseIterable, Sendable, Codable {
    case low, medium, high

    /// Cells per grid edge.
    public var edge: Int {
        switch self {
        case .low: 64
        case .medium: 128
        case .high: 256
        }
    }

    /// The picker label.
    public var name: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    /// The spoken value, for example "Medium, 128 by 128 cells".
    public var accessibilityValue: String { "\(name), \(edge) by \(edge) cells" }

    /// The level nearest to a configuration's shorter grid edge (a device-capped grid keeps its level).
    public init(grid configuration: FluidConfiguration) {
        let edge = min(configuration.gridWidth, configuration.gridHeight)
        self = Self.allCases.min { abs($0.edge - edge) < abs($1.edge - edge) } ?? .medium
    }

    /// Sets the configuration's grid to this level; every other value is kept.
    public func apply(to configuration: inout FluidConfiguration) {
        configuration.gridWidth = edge
        configuration.gridHeight = edge
    }
}
