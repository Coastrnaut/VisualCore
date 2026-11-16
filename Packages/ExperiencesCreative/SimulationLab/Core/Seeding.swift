// Seeding — feature 117 (A16-P01) T-A16-102 (FR-A16-112; clarifications Q1–Q3). The seeded start of each family over
// `VisualCoreSimulation` `SeededRandom(seed:)`, identical for the same spec on every platform:
// - automaton: every cell, in storage order (bottom row first, left to right), is alive when the next
//   `SeededRandom.double()` is below 0.25; one channel, `unorm8` (exact 0 and 1);
// - reaction-diffusion: u = 1 and v = 0 everywhere, then six 4 × 4 patches of u = 0.5, v = 0.25, each placed at a
//   corner (x, y) drawn with `SeededRandom.int(0…n − 1)` (x first) and wrapped across the edges; two channels,
//   `float16`;
// - wave: a Gaussian pulse exp(−r² / (2σ²)) with σ = 3 cells and amplitude 1, centred on a whole cell (x, y) drawn
//   with `SeededRandom.int(6…n − 7)` (x first), the outermost cells held at zero; the previous field equals the
//   current one (the pulse starts at rest); `float16`.
// `pattern(gridSize:alive:)` and `centredPulse(gridSize:precision:)` place exact starts for tests: a centred pulse is
// centred at ((n − 1)/2, (n − 1)/2), so it is mirror-symmetric in both axes.
import Foundation
import VisualCoreSimulation

/// The field of a simulation: the current grid and, for the wave, the previous one.
public struct SimulationField: Equatable, Sendable {
    /// The current field (automaton: alive; reaction-diffusion: u, v; wave: height).
    public var current: FieldGrid
    /// The previous wave field (uⁿ⁻¹); nil for the other families.
    public var previous: FieldGrid?

    /// Creates a field.
    public init(current: FieldGrid, previous: FieldGrid? = nil) {
        self.current = current
        self.previous = previous
    }
}

/// The seeded starts of the three families and exact starts for tests.
public enum Seeding {
    /// The automaton's live-cell density.
    public static let automatonDensity = 0.25
    /// The number of reaction-diffusion patches.
    public static let patchCount = 6
    /// The side of a reaction-diffusion patch, in cells.
    public static let patchSize = 4
    /// The width σ of the wave pulse, in cells.
    public static let pulseWidth = 3.0
    /// The amplitude of the wave pulse.
    public static let pulseAmplitude = 1.0

    /// The seeded start of `spec` (its kind, grid size and seed).
    public static func start(for spec: SimulationSpec) -> SimulationField {
        switch spec.kind {
        case .automaton:
            return SimulationField(current: automatonStart(gridSize: spec.gridSize, seed: spec.seed))
        case .reactionDiffusion:
            return SimulationField(current: reactionStart(gridSize: spec.gridSize, seed: spec.seed))
        case .wave:
            let pulse = waveStart(gridSize: spec.gridSize, seed: spec.seed)
            return SimulationField(current: pulse, previous: pulse)
        }
    }

    /// The seeded automaton start: each cell alive with probability 0.25.
    public static func automatonStart(gridSize n: Int, seed: UInt64) -> FieldGrid {
        var random = SeededRandom(seed: seed)
        var grid = FieldGrid(width: n, height: n, channels: 1)
        for i in 0..<grid.values.count where random.double() < automatonDensity { grid.values[i] = 1 }
        return grid
    }

    /// The seeded reaction-diffusion start: u = 1, v = 0 with six wrapped 4 × 4 patches of u = 0.5, v = 0.25.
    public static func reactionStart(gridSize n: Int, seed: UInt64) -> FieldGrid {
        var random = SeededRandom(seed: seed)
        var grid = FieldGrid(width: n, height: n, channels: 2)
        for cell in 0..<(grid.width * grid.height) { grid.values[cell * 2] = 1 }
        for _ in 0..<patchCount {
            let x0 = random.int(0...(grid.width - 1)), y0 = random.int(0...(grid.height - 1))
            for dy in 0..<patchSize {
                for dx in 0..<patchSize {
                    let x = (x0 + dx) % grid.width, y = (y0 + dy) % grid.height
                    grid[x, y, 0] = 0.5
                    grid[x, y, 1] = 0.25
                }
            }
        }
        return grid.rounded(to: .float16)
    }

    /// The seeded wave start: a pulse (σ = 3, amplitude 1) centred on a seeded whole cell at least 2σ from the edge.
    public static func waveStart(gridSize n: Int, seed: UInt64, precision: StoragePrecision = .float16) -> FieldGrid {
        var random = SeededRandom(seed: seed)
        let margin = Int(2 * pulseWidth)
        let upper = max(margin, n - 1 - margin)
        let cx = random.int(margin...upper), cy = random.int(margin...upper)
        return pulse(gridSize: n, centerX: Double(cx), centerY: Double(cy), precision: precision)
    }

    /// A one-channel automaton grid of side `n` with exactly the cells `alive` (x, y; y = 0 the bottom row) alive;
    /// cells outside the grid are ignored.
    public static func pattern(gridSize n: Int, alive: [(x: Int, y: Int)]) -> FieldGrid {
        var grid = FieldGrid(width: n, height: n, channels: 1)
        for cell in alive where (0..<grid.width).contains(cell.x) && (0..<grid.height).contains(cell.y) {
            grid[cell.x, cell.y, 0] = 1
        }
        return grid
    }

    /// A pulse (σ = 3, amplitude 1) centred at ((n − 1)/2, (n − 1)/2), mirror-symmetric in both axes.
    public static func centredPulse(gridSize n: Int, precision: StoragePrecision = .float16) -> FieldGrid {
        let c = Double(n - 1) / 2
        return pulse(gridSize: n, centerX: c, centerY: c, precision: precision)
    }

    /// A pulse amplitude · exp(−r² / (2σ²)) centred at (`centerX`, `centerY`) with the outermost cells at zero,
    /// rounded to `precision`.
    public static func pulse(gridSize n: Int, centerX: Double, centerY: Double,
                             precision: StoragePrecision = .float16) -> FieldGrid {
        var grid = FieldGrid(width: n, height: n, channels: 1)
        guard grid.width > 2, grid.height > 2 else { return grid }
        let twoSigmaSquared = 2 * pulseWidth * pulseWidth
        for y in 1..<(grid.height - 1) {
            for x in 1..<(grid.width - 1) {
                let dx = Double(x) - centerX, dy = Double(y) - centerY
                grid[x, y, 0] = precision.round(Float(pulseAmplitude * exp(-(dx * dx + dy * dy) / twoSigmaSquared)))
            }
        }
        return grid
    }
}
