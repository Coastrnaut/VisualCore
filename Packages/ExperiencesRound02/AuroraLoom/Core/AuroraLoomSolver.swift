// AuroraLoomSolver — feature 302 (R02-G01-02) T-R02G0102-002/003 (FR-R02G0102-002; clarification Q2; research R1, R2).
// Ribbons do not interact, so each is solved on its own among its 256 settings: bounded coordinate descent first, then the
// exact grid, which proves the fewest changes. The shortest solution is the sum over the ribbons.

/// How the solver reached its result.
public enum AuroraLoomSolveMethod: String, Sendable, Codable, CaseIterable {
    /// Descent alone reached a winning setting at the optimal number of changes on every ribbon.
    case descent
    /// The exact grid search was needed for at least one ribbon.
    case grid
}

/// A proven shortest solution of a level.
public struct AuroraLoomSolution: Sendable, Equatable {
    /// The fewest moves that win.
    public let shortest: Int
    /// A shortest move list: by ribbon, wave before phase.
    public let moves: [AuroraLoomMove]
    /// The winning setting the moves reach.
    public let setting: AuroraLoomSteps
    /// The setting evaluations spent (descent and grid).
    public let work: Int
    /// The number of winning settings of each ribbon.
    public let winningSettings: [Int]
    /// How the result was reached.
    public let method: AuroraLoomSolveMethod

    /// A solution of the given values.
    public init(shortest: Int, moves: [AuroraLoomMove], setting: AuroraLoomSteps, work: Int, winningSettings: [Int],
                method: AuroraLoomSolveMethod) {
        self.shortest = shortest
        self.moves = moves
        self.setting = setting
        self.work = work
        self.winningSettings = winningSettings
        self.method = method
    }
}

/// The exact shortest-solution solver of Aurora Loom (clarification Q2; research R1, R2).
///
/// A ribbon's score for a (wave, phase) setting is its largest |residual| over the four gates and the ticks
/// 0 … 2P − 1 with only that ribbon's steps changed; the setting wins the ribbon when the score is within the tolerance.
/// Each ribbon is solved on its own: bounded coordinate descent from its start steps, then the exact grid of all 256
/// settings, which proves the fewest changes (0, 1 or 2). Every score computation counts as one evaluation of work.
public enum AuroraLoomSolver {
    /// The largest number of descent sweeps (one wave step and one phase step each) per ribbon.
    public static let maxSweeps = 32

    /// A proven shortest solution of `level`, or nil when some ribbon has no winning setting.
    ///
    /// Per ribbon the chosen setting is the winning one with the fewest changes from the start, ties by (wave, phase)
    /// ascending; moves are ordered by ribbon, then wave before phase. The method is `descent` when descent alone reached a
    /// winning setting at the optimal number of changes on every ribbon, `grid` otherwise.
    public static func solve(_ level: AuroraLoomLevel) -> AuroraLoomSolution? {
        solve(level, from: level.startSteps)
    }

    /// A proven shortest solution of `level` starting from `steps` instead of the level's start steps, or nil when some
    /// ribbon has no winning setting (feature 305, R02-G01-05, T-R02G0105-002; FR-R02G0105-002; research R1).
    ///
    /// The same per-ribbon descent and grid as ``solve(_:)`` with the same tie rules, the start of every ribbon taken
    /// from `steps`; `solve(level)` is exactly `solve(level, from: level.startSteps)`. When `steps` already wins,
    /// `shortest` is 0 and `moves` is empty. `steps` must hold three wave and three phase steps.
    public static func solve(_ level: AuroraLoomLevel, from steps: AuroraLoomSteps) -> AuroraLoomSolution? {
        var work: Int = 0
        var bestWave: [Int] = [0, 0, 0]
        var bestPhase: [Int] = [0, 0, 0]
        var winningCounts: [Int] = [0, 0, 0]
        var shortest: Int = 0
        var everyReached: Bool = true
        var moves: [AuroraLoomMove] = []
        for ribbon in 0..<3 {
            let scorer: Scorer = Scorer(level: level, ribbon: ribbon)
            let w0: Int = steps.wave[ribbon]
            let p0: Int = steps.phase[ribbon]

            // Bounded coordinate descent.
            var w: Int = w0
            var p: Int = p0
            var sweep: Int = 0
            var endScore: Int = Int.max
            while sweep < maxSweeps {
                sweep += 1
                var nextWave: Int = 0
                var lowest: Int = Int.max
                for value in 0...15 {
                    let s: Int = scorer.score(wave: value, phase: p)
                    work += 1
                    if s < lowest { lowest = s; nextWave = value }
                }
                var nextPhase: Int = 0
                lowest = Int.max
                for value in 0...15 {
                    let s: Int = scorer.score(wave: nextWave, phase: value)
                    work += 1
                    if s < lowest { lowest = s; nextPhase = value }
                }
                endScore = lowest
                let changed: Bool = nextWave != w || nextPhase != p
                w = nextWave
                p = nextPhase
                if !changed { break }
            }
            let descentWins: Bool = endScore <= level.tolerance   // the last phase step scored (w, p)

            // The exact grid.
            var count: Int = 0
            var cost: Int = Int.max
            var chosenWave: Int = 0
            var chosenPhase: Int = 0
            for wave in 0...15 {
                for phase in 0...15 {
                    let s: Int = scorer.score(wave: wave, phase: phase)
                    work += 1
                    guard s <= level.tolerance else { continue }
                    count += 1
                    let changes: Int = (wave != w0 ? 1 : 0) + (phase != p0 ? 1 : 0)
                    if changes < cost { cost = changes; chosenWave = wave; chosenPhase = phase }
                }
            }
            guard count > 0 else { return nil }
            let descentChanges: Int = (w != w0 ? 1 : 0) + (p != p0 ? 1 : 0)
            if !(descentWins && descentChanges == cost) { everyReached = false }

            bestWave[ribbon] = chosenWave
            bestPhase[ribbon] = chosenPhase
            winningCounts[ribbon] = count
            shortest += cost
            if chosenWave != w0 { moves.append(AuroraLoomMove(ribbon: ribbon, control: .wave, step: chosenWave)) }
            if chosenPhase != p0 { moves.append(AuroraLoomMove(ribbon: ribbon, control: .phase, step: chosenPhase)) }
        }
        return AuroraLoomSolution(shortest: shortest, moves: moves,
                                  setting: AuroraLoomSteps(wave: bestWave, phase: bestPhase), work: work,
                                  winningSettings: winningCounts, method: everyReached ? .descent : .grid)
    }

    /// One ribbon's score function with the level's constants hoisted out of the inner loop.
    ///
    /// The residual at gate g and tick n is `wave · s_g · 16 + phase · 256 − Θ_g + (ω_r − Ω) · n` wrapped into
    /// −2,048 … 2,047 (``AuroraLoomHarmony/residual(ribbon:gate:tick:steps:level:)``). When the ribbon turns with the
    /// harmony (ω_r = Ω) the phase and the target both advance by Ω · n, so every tick's residual equals tick 0's and only
    /// tick 0 is visited; this is exact, not an approximation. A ribbon with ω_r ≠ Ω visits all 2P ticks. Either way one
    /// score is one evaluation of work.
    struct Scorer {
        /// Gate positions times 16.
        let positions: [Int]
        /// Gate targets Θ at tick 0.
        let targets: [Int]
        /// The drift per tick, ω_r − Ω.
        let drift: Int
        /// The ticks visited.
        let ticks: Int

        /// The scorer of `ribbon` in `level`.
        init(level: AuroraLoomLevel, ribbon: Int) {
            var positions: [Int] = []
            var targets: [Int] = []
            for gate in level.gates {
                positions.append(gate.position * 16)
                targets.append(gate.target)
            }
            self.positions = positions
            self.targets = targets
            let drift: Int = level.ribbons[ribbon].omega - level.omega
            self.drift = drift
            self.ticks = drift == 0 ? 1 : 2 * level.period
        }

        /// The largest |residual| of the setting (wave, phase) over the four gates and the visited ticks.
        func score(wave: Int, phase: Int) -> Int {
            var largest: Int = 0
            for g in 0..<4 {
                let base: Int = wave * positions[g] + phase * 256 - targets[g]
                var value: Int = base
                for _ in 0..<ticks {
                    let r: Int = abs(AuroraLoomHarmony.signed(value))
                    if r > largest { largest = r }
                    value += drift
                }
            }
            return largest
        }
    }
}
