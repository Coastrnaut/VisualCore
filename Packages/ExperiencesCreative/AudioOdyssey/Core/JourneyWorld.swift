// JourneyWorld — feature 054 (A07-P01) T-A07-103 (FR-A07-110; data-model "JourneyState.world"). The three worlds of
// Audio Odyssey. The raw values are persisted (snapshot, digest), so they never change: tunnel 0, landscape 1, star
// corridor 2.

/// A world of Audio Odyssey: the geometry generated around the camera rail.
public enum JourneyWorld: Int, CaseIterable, Codable, Sendable {
    /// A 24-sided tube of radius 3 with seeded radius ripples around the rail.
    case tunnel = 0
    /// A rolling strip of terrain 24 units wide under the rail.
    case landscape = 1
    /// Small star octahedra inside a cylinder of radius 6, with thin guide rings.
    case starCorridor = 2

    /// The name shown in the world picker and spoken in the canvas description.
    public var displayName: String {
        switch self {
        case .tunnel: "Tunnel"
        case .landscape: "Landscape"
        case .starCorridor: "Star corridor"
        }
    }
}
