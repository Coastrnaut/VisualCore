// BinaryGardensDifficulty — feature 502 (R02-G21-02) T-R02G2102-003 (FR-R02G2102-002, 003; clarifications Q1 … Q3).
// The seven controls of a Binary Gardens level in their fixed order (star 1 ring, phase, luminosity; star 2 ring, phase,
// luminosity; tilt) with their legal values, the certified plan of a level (the fewest arrangement actions — the
// winning arrangement's parent chain from the start in the solver's breadth-first sweep — the arrangements judged at
// each smaller depth, the nearest miss with its arrangement and the work) and the difficulty metrics derived from the
// level and its plan: witness length, worlds, narrowest comfortable band, tightest window, adjustable controls, move
// space, arrangements searched, work and nearest miss, with R02-F24's shared difficulty record. Integers only.
// Modelled on `MushroomWeatherDifficulty` (feature 492).
import VisualCoreSimulation

/// One of the seven controls of a level, in the fixed order of the solver's moves and the generator's draws.
public enum BinaryGardensControl: Int, Sendable, Hashable, Codable, CaseIterable {
    /// Star 1's ring.
    case star1Ring
    /// Star 1's phase.
    case star1Phase
    /// Star 1's luminosity.
    case star1Luminosity
    /// Star 2's ring.
    case star2Ring
    /// Star 2's phase.
    case star2Phase
    /// Star 2's luminosity.
    case star2Luminosity
    /// The orbit tilt.
    case tilt

    /// Whether the player may change the control in `level`: the star's flag, or T_max > 0 for the tilt.
    public func isAdjustable(in level: BinaryGardensLevel) -> Bool {
        switch self {
        case .star1Ring, .star2Ring: level.stars[rawValue / 3].ringAdjustable
        case .star1Phase, .star2Phase: level.stars[rawValue / 3].phaseAdjustable
        case .star1Luminosity, .star2Luminosity: level.stars[rawValue / 3].luminosityAdjustable
        case .tilt: level.maxTilt > 0
        }
    }

    /// The legal values ascending: the ring indices, the phases on the level's grid (0, g, 2g, … < 48), the
    /// luminosity indices or the tilts 0 … T_max.
    public func values(in level: BinaryGardensLevel) -> [Int] {
        switch self {
        case .star1Ring, .star2Ring: Array(level.ringRadii.indices)
        case .star1Phase, .star2Phase: Array(stride(from: 0, to: BinaryGardensSky.cycle, by: level.phaseStep))
        case .star1Luminosity, .star2Luminosity: Array(level.luminosityLevels.indices)
        case .tilt: Array(0...level.maxTilt)
        }
    }

    /// The control's value in `arrangement`.
    public func value(of arrangement: BinaryGardensArrangement) -> Int {
        switch self {
        case .star1Ring, .star2Ring: arrangement.rings[rawValue / 3]
        case .star1Phase, .star2Phase: arrangement.phases[rawValue / 3]
        case .star1Luminosity, .star2Luminosity: arrangement.luminosities[rawValue / 3]
        case .tilt: arrangement.tilt
        }
    }

    /// The action that sets the control to `value`.
    public func action(_ value: Int) -> BinaryGardensAction {
        switch self {
        case .star1Ring, .star2Ring: .ring(star: rawValue / 3, index: value)
        case .star1Phase, .star2Phase: .phase(star: rawValue / 3, step: value)
        case .star1Luminosity, .star2Luminosity: .luminosity(star: rawValue / 3, index: value)
        case .tilt: .tilt(step: value)
        }
    }

    /// `arrangement` with the control set to `value` (unchecked).
    public func setting(_ value: Int, in arrangement: BinaryGardensArrangement) -> BinaryGardensArrangement {
        var rings: [Int] = arrangement.rings
        var phases: [Int] = arrangement.phases
        var luminosities: [Int] = arrangement.luminosities
        var tilt: Int = arrangement.tilt
        switch self {
        case .star1Ring, .star2Ring: rings[rawValue / 3] = value
        case .star1Phase, .star2Phase: phases[rawValue / 3] = value
        case .star1Luminosity, .star2Luminosity: luminosities[rawValue / 3] = value
        case .tilt: tilt = value
        }
        return BinaryGardensArrangement(rings: rings, phases: phases, luminosities: luminosities, tilt: tilt)
    }

    /// The control an arrangement action sets and the value it sets it to; nil for the run.
    static func of(_ action: BinaryGardensAction) -> (control: BinaryGardensControl, value: Int)? {
        switch action {
        case .ring(let star, let index): (star == 0 ? .star1Ring : .star2Ring, index)
        case .phase(let star, let step): (star == 0 ? .star1Phase : .star2Phase, step)
        case .luminosity(let star, let index): (star == 0 ? .star1Luminosity : .star2Luminosity, index)
        case .tilt(let step): (.tilt, step)
        case .run: nil
        }
    }
}

/// A certified plan: the fewest arrangement actions after which the run wins (clarification Q2).
public struct BinaryGardensPlan: Sendable, Equatable, Codable {
    /// The winning arrangement's parent chain from the start in the solver's sweep (the `run` is not included).
    public let actions: [BinaryGardensAction]
    /// The winning arrangement.
    public let arrangement: BinaryGardensArrangement
    /// The arrangements judged at each depth below the plan's size (depth 0 is the start: 1), none winning.
    public let arrangementsByDepth: [Int]
    /// The smallest light loss among the arrangements judged at smaller depths (the start included).
    public let nearestMiss: Int
    /// The arrangement of ``nearestMiss``: the first in judging order among equal losses.
    public let nearestMissArrangement: BinaryGardensArrangement
    /// The arrangements judged in all, the winning one included.
    public let work: Int

    /// A plan of the given values.
    public init(actions: [BinaryGardensAction], arrangement: BinaryGardensArrangement, arrangementsByDepth: [Int],
                nearestMiss: Int, nearestMissArrangement: BinaryGardensArrangement, work: Int) {
        self.actions = actions
        self.arrangement = arrangement
        self.arrangementsByDepth = arrangementsByDepth
        self.nearestMiss = nearestMiss
        self.nearestMissArrangement = nearestMissArrangement
        self.work = work
    }

    /// The number of arrangement actions (the witness length without the `run`).
    public var size: Int { actions.count }
}

/// The difficulty metrics of a certified level, from the level and its plan (clarification Q3).
public struct BinaryGardensDifficulty: Sendable, Hashable, Codable {
    /// The witness length (arrangement actions).
    public let actions: Int
    /// The number of worlds.
    public let worlds: Int
    /// The narrowest comfortable band: the smallest c_hi − c_lo over the worlds, in milliflux.
    public let narrowestBand: Int
    /// The tightest window: the largest required window W over the worlds, in ticks.
    public let tightestWindow: Int
    /// The number of adjustable controls.
    public let adjustable: Int
    /// The move space: Σ over the adjustable controls of their other legal values.
    public let moveSpace: Int
    /// The arrangements judged at depths below the plan.
    public let arrangementsSearched: Int
    /// The arrangements judged in all.
    public let work: Int
    /// The smallest light loss among the arrangements judged at smaller depths.
    public let nearestMiss: Int

    /// The metrics of `level` certified by `plan`.
    public init(level: BinaryGardensLevel, plan: BinaryGardensPlan) {
        actions = plan.size
        worlds = level.worlds.count
        var narrowest: Int = Int.max
        var tightest: Int = 0
        for world in level.worlds {
            narrowest = min(narrowest, world.comfortHigh - world.comfortLow)
            tightest = max(tightest, world.window)
        }
        narrowestBand = narrowest
        tightestWindow = tightest
        var count: Int = 0
        var space: Int = 0
        for control in BinaryGardensControl.allCases where control.isAdjustable(in: level) {
            count += 1
            space += control.values(in: level).count - 1
        }
        adjustable = count
        moveSpace = space
        arrangementsSearched = plan.arrangementsByDepth.reduce(0, +)
        work = plan.work
        nearestMiss = plan.nearestMiss
    }

    /// The shared difficulty record (R02-F24): the witness length as the shortest solution, the arrangements judged as
    /// the states explored.
    public var puzzleDifficulty: PuzzleDifficulty { PuzzleDifficulty(shortest: actions, explored: work) }
}
