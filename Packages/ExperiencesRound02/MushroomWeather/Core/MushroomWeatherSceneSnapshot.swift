// MushroomWeatherSceneSnapshot — feature 493 (R02-G20-03) T-R02G2003-002 (FR-R02G2003-002, 003, 004; clarifications
// Q1–Q5). What the renderer may read: an immutable copy of the kernel's state — the floor's rows, columns and blocked
// cells, the integer humidity of every cell at each cycle of the predicted run of the current arrangement, the cycles
// run and the shown cycle, the mold bound, every colony with its band, floor, runs and whether it is in band at the
// shown cycle, the required cycles, the pods with their growth cycles, the sites, the vents and their states, the
// moonlight, the failure, the stage, the actions left and the budget, the level number and the presentation time; plus
// the palette and the three quality tiers. The renderer never holds the kernel, so no drawing result can change the
// game (renderer purity), and every drawn humidity is a kernel humidity.
import Foundation

/// The palette of Mushroom Weather, as linear colours 0 … 1 (fern jade, amber spores and deep blue on a midnight
/// forest; clarification Q3).
public enum MushroomWeatherPalette {
    /// The sky at the bottom of the backdrop, #050A1A.
    public static let midnight = rgb(0x05, 0x0A, 0x1A)
    /// The sky at the top of the backdrop, #0E1A33.
    public static let midnightTop = rgb(0x0E, 0x1A, 0x33)
    /// The moon disc and its phase ticks, #E8EEF7.
    public static let moon = rgb(0xE8, 0xEE, 0xF7)
    /// A floor cell, #12261C.
    public static let moss = rgb(0x12, 0x26, 0x1C)
    /// A blocked cell's log or stone, #2A2118.
    public static let log = rgb(0x2A, 0x21, 0x18)
    /// The decorative fronds, #1F4A33.
    public static let frond = rgb(0x1F, 0x4A, 0x33)
    /// The mist of a dry cell, #0B1E4A.
    public static let mistLow = rgb(0x0B, 0x1E, 0x4A)
    /// The mist of a cell at the mold bound, #3A6FD8.
    public static let mistHigh = rgb(0x3A, 0x6F, 0xD8)
    /// A pod site's ring, #C9A15A.
    public static let site = rgb(0xC9, 0xA1, 0x5A)
    /// A colony's lathed stalk, #D8E6D0.
    public static let stalk = rgb(0xD8, 0xE6, 0xD0)
    /// A colony's cap while in band, #5FD3A0.
    public static let cap = rgb(0x5F, 0xD3, 0xA0)
    /// A colony's cap while out of band, #3F6E5A.
    public static let capOut = rgb(0x3F, 0x6E, 0x5A)
    /// A spore pod, #F2A93B.
    public static let pod = rgb(0xF2, 0xA9, 0x3B)
    /// A droplet breathed by a pod, #FFC861.
    public static let droplet = rgb(0xFF, 0xC8, 0x61)
    /// A canopy vent, #6E8B7A.
    public static let vent = rgb(0x6E, 0x8B, 0x7A)
    /// A colony's band on its gauge, #9FF5C8.
    public static let band = rgb(0x9F, 0xF5, 0xC8)
    /// A gauge's humidity marker, #F2A93B.
    public static let marker = rgb(0xF2, 0xA9, 0x3B)
    /// A lit actions bar, #F2A93B.
    public static let actionsLit = rgb(0xF2, 0xA9, 0x3B)
    /// An unlit actions bar, #1A2A3A.
    public static let actionsUnlit = rgb(0x1A, 0x2A, 0x3A)
    /// What a failure names, #FF6B5E.
    public static let broken = rgb(0xFF, 0x6B, 0x5E)
    /// The glow shells, #F7FFF9.
    public static let glow = rgb(0xF7, 0xFF, 0xF9)

    /// The palette's main hex values (midnight, cap, pod, mist high, moss), as registered in the catalog.
    public static let hex: [String] = ["#050A1A", "#5FD3A0", "#F2A93B", "#3A6FD8", "#12261C"]

    /// Every colour of the palette by name with its hex value, in declaration order (21 entries).
    static let all: [(name: String, hex: String, colour: SIMD3<Double>)] = [
        ("midnight", "#050A1A", midnight), ("midnightTop", "#0E1A33", midnightTop), ("moon", "#E8EEF7", moon),
        ("moss", "#12261C", moss), ("log", "#2A2118", log), ("frond", "#1F4A33", frond),
        ("mistLow", "#0B1E4A", mistLow), ("mistHigh", "#3A6FD8", mistHigh), ("site", "#C9A15A", site),
        ("stalk", "#D8E6D0", stalk), ("cap", "#5FD3A0", cap), ("capOut", "#3F6E5A", capOut), ("pod", "#F2A93B", pod),
        ("droplet", "#FFC861", droplet), ("vent", "#6E8B7A", vent), ("band", "#9FF5C8", band),
        ("marker", "#F2A93B", marker), ("actionsLit", "#F2A93B", actionsLit),
        ("actionsUnlit", "#1A2A3A", actionsUnlit), ("broken", "#FF6B5E", broken), ("glow", "#F7FFF9", glow),
    ]

    /// The linear colour of 8-bit components.
    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SIMD3<Double> {
        SIMD3(Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }
}

/// A quality tier: what the scene draws beyond the shared content (clarification Q2). The backdrop, moon, floor,
/// blocked cells, mist, sites, stalks, caps, pods, vents, gauges, bars, colours and positions are the same at every
/// tier; only the lathe detail, the droplets, the fronds, the motes and the glow differ.
public struct MushroomWeatherTier: Sendable, Equatable, Hashable {
    /// The tier's name, `level-0` … `level-2`.
    public let name: String
    /// The tier's index, 0 (richest) … 2 (the design's "Tier 0, D3-safe").
    public let index: Int
    /// The segments around a lathed stalk, cap or pod (0: flat caps and pods).
    public let latheSegments: Int
    /// The droplets breathed by each pod.
    public let droplets: Int
    /// Whether the decorative fronds are drawn.
    public let fronds: Bool
    /// The drifting spore motes.
    public let motes: Int
    /// The glow shells around the caps and pods.
    public let glowShells: Int

    /// The three tiers, richest first.
    public static let all: [MushroomWeatherTier] = [
        MushroomWeatherTier(index: 0, latheSegments: 16, droplets: 12, fronds: true, motes: 8, glowShells: 2),
        MushroomWeatherTier(index: 1, latheSegments: 10, droplets: 6, fronds: true, motes: 4, glowShells: 1),
        MushroomWeatherTier(index: 2, latheSegments: 0, droplets: 0, fronds: false, motes: 0, glowShells: 0),
    ]

    /// A tier of the given values, named `level-<index>`.
    init(index: Int, latheSegments: Int, droplets: Int, fronds: Bool, motes: Int, glowShells: Int) {
        name = "level-\(index)"
        self.index = index
        self.latheSegments = latheSegments
        self.droplets = droplets
        self.fronds = fronds
        self.motes = motes
        self.glowShells = glowShells
    }

    /// Whether caps and pods are flat.
    public var flatCaps: Bool { latheSegments == 0 }

    /// The tier of `index`, clamped to 0 … 2.
    public static func of(_ index: Int) -> MushroomWeatherTier {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// A colony as the scene draws it: its cell, band, survival floor, runs and whether it is in band at the shown cycle.
public struct MushroomWeatherSceneColony: Sendable, Equatable {
    /// The colony's cell.
    public let cell: MushroomWeatherCell
    /// The lowest humidity inside the band.
    public let low: Int
    /// The highest humidity inside the band.
    public let high: Int
    /// The survival floor of a sensitive colony, nil when the colony is not sensitive.
    public let survivalFloor: Int?
    /// The consecutive cycles in band ending at the last cycle run (the report's).
    public let finalRun: Int
    /// The longest run of consecutive cycles in band (the report's).
    public let longestRun: Int
    /// Whether the colony's humidity at the shown cycle is inside its band (edges included).
    public let inBand: Bool

    /// A scene colony of the given values.
    public init(cell: MushroomWeatherCell, low: Int, high: Int, survivalFloor: Int?, finalRun: Int, longestRun: Int,
                inBand: Bool) {
        self.cell = cell
        self.low = low
        self.high = high
        self.survivalFloor = survivalFloor
        self.finalRun = finalRun
        self.longestRun = longestRun
        self.inBand = inBand
    }
}

/// An immutable copy of what the renderer may read (see the file header).
public struct MushroomWeatherSceneSnapshot: Sendable, Equatable {
    /// The floor's rows R.
    public let rows: Int
    /// The floor's columns C.
    public let columns: Int
    /// The blocked cells, row-major.
    public let blocked: [MushroomWeatherCell]
    /// The humidity of every cell at cycles 0 … cyclesRun of the predicted run of the current arrangement, each
    /// row-major (rows · columns values, blocked cells 0), indexed [cycle][cell].
    public let fields: [[Int]]
    /// The cycles run by the predicted run (the run length T, or the failing cycle).
    public let cyclesRun: Int
    /// The shown cycle, 0 … cyclesRun (presentation only; never part of the digest).
    public let shownCycle: Int
    /// The mold bound M.
    public let moldBound: Int
    /// The colonies, by colony index.
    public let colonies: [MushroomWeatherSceneColony]
    /// The required cycles K every colony must end in band.
    public let requiredCycles: Int
    /// The pod cell of every slot, nil for an empty slot.
    public let pods: [MushroomWeatherCell?]
    /// The cycle at which each slot's pod grew, nil when it did not (or the slot is empty).
    public let grownAt: [Int?]
    /// The pod sites, row-major (empty for a level without sites).
    public let sites: [MushroomWeatherCell]
    /// The vent cells, by vent index.
    public let vents: [MushroomWeatherCell]
    /// Whether each vent is open, by vent index.
    public let ventsOpen: [Bool]
    /// The moonlight level L, 0 … 3.
    public let moonlight: Int
    /// The failure: the play's on a failed play, otherwise the report's prediction.
    public let failure: MushroomWeatherFailure?
    /// The stage.
    public let stage: MushroomWeatherStage
    /// The actions left.
    public let actionsLeft: Int
    /// The action budget.
    public let budget: Int
    /// The level number, 1 … 100.
    public let levelNumber: Int
    /// The presentation time in seconds (never negative or non-finite).
    public let time: Double

    /// A snapshot of `play` with cycle `shownCycle` shown (clamped to 0 … cycles run).
    public init(play: MushroomWeatherPlay, shownCycle: Int, levelNumber: Int, time: Double) {
        let level: MushroomWeatherLevel = play.level
        let arrangement: MushroomWeatherArrangement = play.arrangement
        // The kernel's own run of the current arrangement, keeping every cycle's field (no other law).
        let run = MushroomWeatherForest.run(level, arrangement: arrangement, keepFields: true)
        let report: MushroomWeatherReport = run.report
        let shown: Int = min(max(shownCycle, 0), report.cycles)
        let field: [Int] = run.fields[shown]
        var colonies: [MushroomWeatherSceneColony] = []
        for (index, colony) in level.colonies.enumerated() {
            let runs: MushroomWeatherColonyRuns = report.colonies[index]
            colonies.append(MushroomWeatherSceneColony(cell: colony.cell, low: colony.low, high: colony.high,
                                                       survivalFloor: colony.survivalFloor, finalRun: runs.finalRun,
                                                       longestRun: runs.longestRun,
                                                       inBand: colony.isInBand(field[level.index(of: colony.cell)])))
        }
        rows = level.rows
        columns = level.columns
        blocked = level.blocked
        fields = run.fields
        cyclesRun = report.cycles
        self.shownCycle = shown
        moldBound = level.moldBound
        self.colonies = colonies
        requiredCycles = level.required
        pods = arrangement.pods
        grownAt = report.grownAt
        sites = level.sites ?? []
        vents = level.vents.map(\.cell)
        ventsOpen = arrangement.ventsOpen
        moonlight = arrangement.moonlight
        failure = play.failure ?? report.failure
        stage = play.stage
        actionsLeft = play.actionsLeft
        budget = level.budget
        self.levelNumber = levelNumber
        self.time = time.isFinite ? max(0, time) : 0
    }

    /// A snapshot of the given values, unchecked (presentation variants and tests: fields, failures and stages a play
    /// may not reach); `shownCycle` is clamped to 0 … `cyclesRun` and `time` made finite and non-negative.
    init(rows: Int, columns: Int, blocked: [MushroomWeatherCell], fields: [[Int]], cyclesRun: Int, shownCycle: Int,
         moldBound: Int, colonies: [MushroomWeatherSceneColony], requiredCycles: Int, pods: [MushroomWeatherCell?],
         grownAt: [Int?], sites: [MushroomWeatherCell], vents: [MushroomWeatherCell], ventsOpen: [Bool],
         moonlight: Int, failure: MushroomWeatherFailure?, stage: MushroomWeatherStage, actionsLeft: Int, budget: Int,
         levelNumber: Int, time: Double) {
        self.rows = rows
        self.columns = columns
        self.blocked = blocked
        self.fields = fields
        self.cyclesRun = cyclesRun
        self.shownCycle = min(max(shownCycle, 0), max(cyclesRun, 0))
        self.moldBound = moldBound
        self.colonies = colonies
        self.requiredCycles = requiredCycles
        self.pods = pods
        self.grownAt = grownAt
        self.sites = sites
        self.vents = vents
        self.ventsOpen = ventsOpen
        self.moonlight = moonlight
        self.failure = failure
        self.stage = stage
        self.actionsLeft = actionsLeft
        self.budget = budget
        self.levelNumber = levelNumber
        self.time = time.isFinite ? max(0, time) : 0
    }

    /// Whether the play is won.
    public var isWon: Bool { stage == .won }

    /// The humidity of every cell at the shown cycle, row-major.
    public var shownField: [Int] { fields[shownCycle] }

    /// The humidity of `cell` at the shown cycle.
    public func humidity(_ cell: MushroomWeatherCell) -> Int { fields[shownCycle][cell.row * columns + cell.column] }

    /// Whether slot `slot`'s pod has grown by the end of the shown cycle (its integral reached G at or before it).
    public func isGrown(_ slot: Int) -> Bool {
        guard slot < grownAt.count, let cycle = grownAt[slot] else { return false }
        return shownCycle >= cycle
    }
}
