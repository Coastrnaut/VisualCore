// MushroomWeatherSceneSnapshot — feature 493 (R02-G20-03) T-R02G2003-002 (FR-R02G2003-002, 003, 004; clarifications
// Q1–Q5). What the renderer may read: an immutable copy of the kernel's state — the floor's rows, columns and blocked
// cells, the integer humidity of every cell at each cycle of the predicted run of the current arrangement, the cycles
// run and the shown cycle, the mold bound, every colony with its band, floor, runs and whether it is in band at the
// shown cycle, the required cycles, the pods with their growth cycles, the sites, the vents and their states, the
// moonlight, the failure, the stage, the actions left and the budget, the level number and the presentation time; plus
// the palette and the three quality tiers. The renderer never holds the kernel, so no drawing result can change the
// game (renderer purity), and every drawn humidity is a kernel humidity.
//
// Feature 494 (R02-G20-04) T-R02G2004-002 (FR-R02G2004-002, 004, 006; SC-R02G2004-003; clarification Q3) adds the
// preview of a pod drag or a moon drag. ``MushroomWeatherSceneSnapshot/previewing(_:level:)`` returns a copy whose
// `preview` holds the kind (a pod's slot with its target site or removal, or a moonlight level), the previewed
// arrangement and the previewed run — every cycle's humidity, the colony runs, the pods' growth and the failure —
// computed with the kernel's own `MushroomWeatherForest.run` of the previewed arrangement (no other law). Only a change
// the kernel would accept is previewed (the slot holds a pod; a floor cell the level allows, no colony on it, not the
// pod's own and not another slot's; or removal; a moonlight level 0 … 3 other than the current one); anything else
// gives the copy without a preview. Presentation only: the preview never enters the digest, the game state or the
// kernel, and every snapshot made by the initialisers has no preview, so the existing drawing is unchanged.
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

/// What a drag would change (feature 494, R02-G20-04): a pod moved to a site or removed, or the moonlight level.
public enum MushroomWeatherPreviewKind: Sendable, Equatable {
    /// Slot `slot`'s pod moved to `target`, or removed from its slot when `target` is nil.
    case pod(slot: Int, target: MushroomWeatherCell?)
    /// The moonlight set to `level`, 0 … 3.
    case moonlight(level: Int)
}

/// The preview of one drag (feature 494, R02-G20-04): the previewed arrangement and the kernel's run of it.
/// Presentation only; never in the digest.
public struct MushroomWeatherPreview: Sendable, Equatable {
    /// What the drag would change.
    public let kind: MushroomWeatherPreviewKind
    /// The arrangement as it would be after the change.
    public let arrangement: MushroomWeatherArrangement
    /// The kernel's report of the previewed arrangement (cycles run, colony runs, pod growth, failure).
    public let report: MushroomWeatherReport
    /// The humidity of every cell at cycles 0 … report.cycles of the previewed run (the kernel's), indexed
    /// [cycle][cell], each row-major.
    public let fields: [[Int]]

    /// A preview of the given values (unchecked).
    public init(kind: MushroomWeatherPreviewKind, arrangement: MushroomWeatherArrangement,
                report: MushroomWeatherReport, fields: [[Int]]) {
        self.kind = kind
        self.arrangement = arrangement
        self.report = report
        self.fields = fields
    }

    /// The cycles the previewed run ran.
    public var cyclesRun: Int { report.cycles }
    /// The previewed failure, nil when the previewed run wins.
    public var failure: MushroomWeatherFailure? { report.failure }

    /// The arrangement `arrangement` changed by `kind` in `level`, or nil when the play would refuse the change
    /// (for a pod: slot out of range or empty, a target off the floor, on a colony, not a site of a level with sites,
    /// held by another slot or the pod's own cell; for the moonlight: a level outside 0 … 3 or the current one).
    public static func changed(_ arrangement: MushroomWeatherArrangement, by kind: MushroomWeatherPreviewKind,
                               level: MushroomWeatherLevel) -> MushroomWeatherArrangement? {
        var pods: [MushroomWeatherCell?] = arrangement.pods
        var moonlight: Int = arrangement.moonlight
        switch kind {
        case .pod(let slot, let target):
            guard pods.indices.contains(slot), let own = pods[slot] else { return nil }
            if let cell = target {
                guard level.isFloor(cell), !level.colonyCells.contains(cell), level.allowsPod(cell),
                      cell != own else { return nil }
                for other in pods.indices where other != slot && pods[other] == cell { return nil }
                pods[slot] = cell
            } else {
                pods[slot] = nil
            }
        case .moonlight(let value):
            guard MushroomWeatherLevel.moonlightLevels.contains(value), value != moonlight else { return nil }
            moonlight = value
        }
        return MushroomWeatherArrangement(pods: pods, ventsOpen: arrangement.ventsOpen, moonlight: moonlight)
    }

    /// The preview of changing `arrangement` by `kind` in `level`, run by the kernel
    /// (`MushroomWeatherForest.run` of the previewed arrangement, keeping every cycle's field); nil when the play would
    /// refuse the change (``changed(_:by:level:)``).
    public static func of(_ kind: MushroomWeatherPreviewKind, arrangement: MushroomWeatherArrangement,
                          level: MushroomWeatherLevel) -> MushroomWeatherPreview? {
        guard let next = changed(arrangement, by: kind, level: level) else { return nil }
        let run = MushroomWeatherForest.run(level, arrangement: next, keepFields: true)
        return MushroomWeatherPreview(kind: kind, arrangement: next, report: run.report, fields: run.fields)
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
    /// The previewed drag; nil when no preview (feature 494; presentation only; never in the digest).
    public private(set) var preview: MushroomWeatherPreview? = nil

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

    /// The arrangement the snapshot shows: its pods, vent states and moonlight (feature 494).
    public var arrangement: MushroomWeatherArrangement {
        MushroomWeatherArrangement(pods: pods, ventsOpen: ventsOpen, moonlight: moonlight)
    }

    /// This snapshot with `kind` previewed (feature 494, T-R02G2004-002): ``preview`` is
    /// ``MushroomWeatherPreview/of(_:arrangement:level:)`` of this snapshot's arrangement in `level` (the snapshot's
    /// level), the kernel's run; a change the play would refuse, or a level whose floor, vents or slots differ from the
    /// snapshot's, gives this snapshot without a preview. Presentation only: nothing else changes.
    public func previewing(_ kind: MushroomWeatherPreviewKind,
                           level: MushroomWeatherLevel) -> MushroomWeatherSceneSnapshot {
        var copy: MushroomWeatherSceneSnapshot = self
        guard level.rows == rows, level.columns == columns, level.vents.count == vents.count,
              level.start.pods.count == pods.count else {
            copy.preview = nil
            return copy
        }
        copy.preview = MushroomWeatherPreview.of(kind, arrangement: arrangement, level: level)
        return copy
    }

    /// This snapshot without a preview (feature 494; presentation only).
    public func clearingPreview() -> MushroomWeatherSceneSnapshot {
        var copy: MushroomWeatherSceneSnapshot = self
        copy.preview = nil
        return copy
    }
}
