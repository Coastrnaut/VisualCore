// FramePacing.swift — frame-rate cap and render scale from thermal state and Low Power Mode
// (feature 003 T-F205; FR-F206). Same table as the audited reference QualityGovernor
// (docs/architecture/current-rendering-pipeline.md §4): never below 30 fps.

/// Frame-rate cap and render scale chosen from thermal state and Low Power Mode.
public struct FramePacing: Sendable, Equatable {
    /// Mirrors `ProcessInfo.ThermalState` so this module stays platform-neutral.
    public enum Thermal: Int, Sendable, Codable, CaseIterable { case nominal, fair, serious, critical }

    /// A display-link frame-rate range (`CAFrameRateRange` on iOS).
    public struct Range: Sendable, Equatable {
        /// Lowest acceptable frames per second.
        public var minimum: Int
        /// Highest allowed frames per second.
        public var maximum: Int
        /// Requested frames per second.
        public var preferred: Int
        /// Creates a range from minimum, maximum and preferred frames per second.
        public init(minimum: Int, maximum: Int, preferred: Int) {
            self.minimum = minimum; self.maximum = maximum; self.preferred = preferred
        }
    }

    /// Floor for every cap: 30 fps.
    public static let minimumFPS = 30
    /// Largest frame delta passed to simulations: 0.1 s.
    public static let maximumDelta = 0.1

    /// Frame-rate cap: 30 under Low Power Mode or serious/critical thermal state, else the request (at least 30).
    public let maxFPS: Int
    /// Drawable scale factor: 0.75 at critical thermal state, else 1.0.
    public let renderScale: Double

    /// Derives the cap and scale; `requestedMaxFPS` below 30 is raised to 30.
    public init(thermal: Thermal, lowPower: Bool, requestedMaxFPS: Int) {
        let requested = max(Self.minimumFPS, requestedMaxFPS)
        let pressured = lowPower || thermal == .serious || thermal == .critical
        maxFPS = pressured ? Self.minimumFPS : requested
        renderScale = thermal == .critical ? 0.75 : 1.0
    }

    /// At least 30 fps, at most the cap, preferring the cap.
    public var range: Range { Range(minimum: Self.minimumFPS, maximum: maxFPS, preferred: maxFPS) }

    /// Frame delta clamped to 0…0.1 s (debugger pauses, backgrounding).
    public static func clampedDelta(_ delta: Double) -> Double { min(max(delta, 0), maximumDelta) }
}
