// FluidConfiguration.swift — the validated, bounded fluid configuration (feature 019 T-A02-108; FR-A02-101;
// data-model.md). Every value the GPU sees passes through `validated`, so grids, time constants and iteration counts
// are always bounded (constitution IX, A02 Bounded GPU rule).

/// One corrected configuration value.
public struct ConfigurationIssue: Sendable, Equatable, Codable {
    /// The field name, for example `gridWidth`.
    public let field: String
    /// The value that was requested, as text.
    public let requested: String
    /// The value that is used instead, as text.
    public let applied: String
}

/// Simulation settings for the playground (version 1). Values outside their bounds are corrected by `validated`.
public struct FluidConfiguration: Sendable, Equatable, Codable {
    /// Grid edge bounds before the device cap.
    public static let gridEdgeRange = 16...512
    /// Dissipation bounds, per second.
    public static let dissipationRange = 0.0...10.0
    /// Viscosity bounds (stored now, used in Phase 03).
    public static let viscosityRange = 0.0...1.0
    /// Pressure iteration bounds (stored now, used in Phase 03).
    public static let pressureIterationRange = 1...80
    /// Bounds of the velocity range used for RGBA8 velocity encoding, in cells per step.
    public static let velocityRangeBounds = 0.5...64.0
    /// Brush radius bounds, as a fraction of the shorter grid edge (feature 020).
    public static let brushRadiusRange = 0.005...0.25
    /// Force scale bounds (feature 020).
    public static let forceScaleRange = 0.0...4.0
    /// Bounds of the splats applied per frame (feature 020).
    public static let splatsPerFrameRange = 1...64

    /// Schema version; only 1 exists.
    public var version = 1
    /// Simulation grid width in cells (16…512, then ≤ the device's maximum render size).
    public var gridWidth = 128
    /// Simulation grid height in cells (16…512, then ≤ the device's maximum render size).
    public var gridHeight = 128
    /// Dye dissipation per second (0…10): each step multiplies dye by 1 / (1 + d·Δt).
    public var dyeDissipation = 1.0
    /// Velocity dissipation per second (0…10).
    public var velocityDissipation = 0.2
    /// Viscosity (0…1; Phase 03).
    public var viscosity = 0.0
    /// Pressure solver iterations (1…80; Phase 03).
    public var pressureIterations = 20
    /// Largest velocity magnitude stored in RGBA8 fallback storage (0.5…64 cells per step).
    public var velocityRange = 4.0
    /// Seed of the initial dye pattern.
    public var seed: UInt64 = 1
    /// Splat radius as a fraction of the shorter grid edge (0.005…0.25).
    public var brushRadius = 0.04
    /// Multiplier from finger velocity to fluid force (0…4).
    public var forceScale = 1.0
    /// Most splats applied in one frame (1…64); extra splats are thinned evenly along each path.
    public var maxSplatsPerFrame = 16

    /// The defaults.
    public init() {}

    /// The configuration with every value in bounds, and one issue per corrected field. Non-finite numbers become
    /// the field's default. Grid edges are clamped to 16…512 and then to `maxEdge` (never below 16).
    /// Validating a validated configuration returns no issues.
    public func validated(maxEdge: Int = 512) -> (FluidConfiguration, issues: [ConfigurationIssue]) {
        let defaults = FluidConfiguration()
        var out = self
        var issues: [ConfigurationIssue] = []
        func note<T: Equatable>(_ field: String, _ requested: T, _ applied: T) {
            if requested != applied { issues.append(ConfigurationIssue(field: field, requested: "\(requested)", applied: "\(applied)")) }
        }
        func edge(_ v: Int) -> Int {
            let upper = max(Self.gridEdgeRange.lowerBound, min(Self.gridEdgeRange.upperBound, maxEdge))
            return min(max(v, Self.gridEdgeRange.lowerBound), upper)
        }
        func real(_ v: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
            v.isFinite ? min(max(v, range.lowerBound), range.upperBound) : fallback
        }
        out.version = 1
        note("version", version, out.version)
        out.gridWidth = edge(gridWidth)
        note("gridWidth", gridWidth, out.gridWidth)
        out.gridHeight = edge(gridHeight)
        note("gridHeight", gridHeight, out.gridHeight)
        out.dyeDissipation = real(dyeDissipation, Self.dissipationRange, defaults.dyeDissipation)
        noteReal("dyeDissipation", dyeDissipation, out.dyeDissipation, &issues)
        out.velocityDissipation = real(velocityDissipation, Self.dissipationRange, defaults.velocityDissipation)
        noteReal("velocityDissipation", velocityDissipation, out.velocityDissipation, &issues)
        out.viscosity = real(viscosity, Self.viscosityRange, defaults.viscosity)
        noteReal("viscosity", viscosity, out.viscosity, &issues)
        out.pressureIterations = min(max(pressureIterations, Self.pressureIterationRange.lowerBound), Self.pressureIterationRange.upperBound)
        note("pressureIterations", pressureIterations, out.pressureIterations)
        out.velocityRange = real(velocityRange, Self.velocityRangeBounds, defaults.velocityRange)
        noteReal("velocityRange", velocityRange, out.velocityRange, &issues)
        out.brushRadius = real(brushRadius, Self.brushRadiusRange, defaults.brushRadius)
        noteReal("brushRadius", brushRadius, out.brushRadius, &issues)
        out.forceScale = real(forceScale, Self.forceScaleRange, defaults.forceScale)
        noteReal("forceScale", forceScale, out.forceScale, &issues)
        out.maxSplatsPerFrame = min(max(maxSplatsPerFrame, Self.splatsPerFrameRange.lowerBound), Self.splatsPerFrameRange.upperBound)
        note("maxSplatsPerFrame", maxSplatsPerFrame, out.maxSplatsPerFrame)
        return (out, issues)
    }

    /// Like `note`, but NaN (which never equals itself) counts as changed only when the applied value differs.
    private func noteReal(_ field: String, _ requested: Double, _ applied: Double, _ issues: inout [ConfigurationIssue]) {
        if !(requested == applied) {
            issues.append(ConfigurationIssue(field: field, requested: "\(requested)", applied: "\(applied)"))
        }
    }
}
