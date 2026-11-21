// ColorfallCanyonsHints — feature 345 (R02-G05-05) T-R02G0505-002 (FR-R02G0505-002, 003; SC-R02G0505-002, 003;
// clarifications Q1, Q5; research R1, R2, R6). Progressive hints computed from the current state of a play and the
// plain-English explanation of a failure. A hint is the first edit of the plan — the smallest winning edit set applied
// now, found by `ColorfallCanyonsSolver.plan(_:from:budget:)` from the play's fluid with the actions left — or "run"
// when the plan is empty, or "stuck" when no set wins. Applying the plan's first edit leaves the rest of the plan winning
// (no tick passes between edits), so following exact hints from any state that can still win wins. Hints never change a
// play, are unlimited and do not affect stars; the hint level is presentation (held by the presenter, reset to 1 after
// any change of the play). A failure is explained from the failed play's fluid in the kernel's verdict order: the first
// contaminated protected basin, else the first overflowing basin, else (time) the first basin whose target is not met.

/// What a hint suggests (clarification Q1).
public enum ColorfallCanyonsHintKind: String, Sendable, Codable {
    /// Lower one carvable cell.
    case carve
    /// Toggle one spring's valve.
    case valve
    /// Make no edit: let the fluid run to the win.
    case run
    /// No win is reachable from here: undo the last change or retry the level.
    case stuck
}

/// One hint of a play (clarification Q1). The suggested action is the same at every level; only the text reveals more.
public struct ColorfallCanyonsHint: Sendable, Equatable {
    /// The hint level, 1 … 3: 1 names what to do, 2 adds where (the row or the spring's colour), 3 is exact.
    public let level: Int
    /// What the hint suggests.
    public let kind: ColorfallCanyonsHintKind
    /// The cell to carve (`carve`); nil otherwise.
    public let cell: Int?
    /// The spring whose valve to toggle (`valve`); nil otherwise.
    public let spring: Int?
    /// The ticks left in the play: the level's tick limit minus the current tick.
    public let ticks: Int
    /// The number of edits in the plan (0 for `run` and `stuck`).
    public let planSize: Int
    /// The 1-based row of ``cell`` (`carve`), else 0.
    let row: Int
    /// The 1-based column of ``cell`` (`carve`), else 0.
    let column: Int
    /// The name of ``spring``'s colour (`valve`), else empty.
    let colorName: String
    /// Whether ``spring``'s valve is open now (`valve`), else false.
    let valveOpen: Bool

    /// A hint of the given values (not checked); `row` and `column` are 1-based.
    init(level: Int, kind: ColorfallCanyonsHintKind, cell: Int?, spring: Int?, ticks: Int, planSize: Int, row: Int,
         column: Int, colorName: String, valveOpen: Bool) {
        self.level = level
        self.kind = kind
        self.cell = cell
        self.spring = spring
        self.ticks = ticks
        self.planSize = planSize
        self.row = row
        self.column = column
        self.colorName = colorName
        self.valveOpen = valveOpen
    }

    /// The text shown when no win is reachable, at every level (clarification Q1).
    public static let stuckText: String = "No win is reachable from here: undo the last change or retry the level."

    /// The hint in plain English (clarification Q1), with r, c the 1-based row and column, <colour> the spring's colour
    /// and N the ticks left:
    /// - carve: "Carve a channel", "Carve near row r", "Carve row r, column c"
    /// - valve: "Switch a valve", "Switch the <colour> spring", "Open the <colour> valve" (closed now) or "Close the
    ///   <colour> valve" (open now)
    /// - run: "Let the fluid run", "Run to the end", "Run: N ticks"
    /// - stuck: ``stuckText`` at every level
    public var text: String {
        switch (kind, level) {
        case (.carve, 1): return "Carve a channel"
        case (.carve, 2): return "Carve near row \(row)"
        case (.carve, _): return "Carve row \(row), column \(column)"
        case (.valve, 1): return "Switch a valve"
        case (.valve, 2): return "Switch the \(colorName) spring"
        case (.valve, _): return (valveOpen ? "Close the " : "Open the ") + colorName + " valve"
        case (.run, 1): return "Let the fluid run"
        case (.run, 2): return "Run to the end"
        case (.run, _): return "Run: \(ticks) ticks"
        case (.stuck, _): return Self.stuckText
        }
    }
}

/// The hint engine of Colorfall Canyons (clarification Q1; research R1, R2).
public enum ColorfallCanyonsHints {
    /// The plan of `play`: ``ColorfallCanyonsSolver/plan(_:from:budget:)`` from the play's fluid with the actions left
    /// as the budget; nil when no win is reachable with edits applied now.
    public static func plan(_ play: ColorfallCanyonsPlay) -> ColorfallCanyonsSolution? {
        ColorfallCanyonsSolver.plan(play.level, from: play.fluid, budget: max(0, play.remaining))
    }

    /// The hint of `level` (clamped to 1 … 3) for `play`: while `playing` or `paused`, the first edit of ``plan(_:)``
    /// (`carve` or `valve`), `run` when the plan is empty, `stuck` when there is no plan; when `failed`, `stuck`; nil in
    /// every other stage (loading, tutorial, won, result). The same action is returned at every level.
    public static func hint(level: Int, play: ColorfallCanyonsPlay) -> ColorfallCanyonsHint? {
        let clamped: Int = min(3, max(1, level))
        let lvl: ColorfallCanyonsLevel = play.level
        let ticks: Int = max(0, lvl.tickLimit - play.fluid.tick)
        switch play.stage {
        case .playing, .paused: break
        case .failed: return stuck(level: clamped, ticks: ticks)
        case .loading, .tutorial, .won, .result: return nil
        }
        guard let solution = plan(play) else { return stuck(level: clamped, ticks: ticks) }
        guard let first = solution.edits.first else {
            return ColorfallCanyonsHint(level: clamped, kind: .run, cell: nil, spring: nil, ticks: ticks, planSize: 0,
                                        row: 0, column: 0, colorName: "", valveOpen: false)
        }
        switch first {
        case .carve(let cell):
            return ColorfallCanyonsHint(level: clamped, kind: .carve, cell: cell, spring: nil, ticks: ticks,
                                        planSize: solution.edits.count, row: cell / lvl.columns + 1,
                                        column: cell % lvl.columns + 1, colorName: "", valveOpen: false)
        case .valve(let spring):
            return ColorfallCanyonsHint(level: clamped, kind: .valve, cell: nil, spring: spring, ticks: ticks,
                                        planSize: solution.edits.count, row: 0, column: 0,
                                        colorName: lvl.springs[spring].color.name,
                                        valveOpen: play.fluid.valves[spring])
        }
    }

    /// The `stuck` hint of `level` with `ticks` left.
    private static func stuck(level: Int, ticks: Int) -> ColorfallCanyonsHint {
        ColorfallCanyonsHint(level: level, kind: .stuck, cell: nil, spring: nil, ticks: ticks, planSize: 0, row: 0,
                             column: 0, colorName: "", valveOpen: false)
    }
}

/// The plain-English explanation of a failed play (FR-R02G0505-003; clarification Q5; research R6), recomputed from the
/// failed play's fluid in the kernel's verdict order.
public struct ColorfallCanyonsFailureExplanation: Sendable, Equatable {
    /// Why the play failed.
    public let failure: ColorfallCanyonsFailure
    /// The deciding basin's 1-based number in the level's basin order.
    public let basin: Int
    /// The wrong colour holding the most of the deciding basin's wrong mass (lowest colour on a tie) for
    /// `contamination`; nil for `overflow` and `time`.
    public let color: ColorfallCanyonsColor?
    /// The amount that decided: the basin's wrong mass (`contamination`) or volume (`overflow`, `time`).
    public let amount: Int
    /// The limit it is compared with: the tolerated wrong units (`contamination`), the capacity (`overflow`) or the
    /// target fill (`time`).
    public let limit: Int
    /// The failing tick.
    public let tick: Int
    /// The explanation's sentence before the shared advice.
    private let detail: String

    /// The advice that ends every explanation.
    public static let advice: String = "Undo the last change or retry the level."

    /// The explanation (clarification Q5), with k the basin number and r, c its 1-based row and column:
    /// - contamination: "Basin k (row r, column c) took n units of <colour>; it allows at most m." — n the basin's wrong
    ///   mass, m its tolerated wrong units; <colour> names the wrong colour, or "a and b" when two wrong colours are in
    /// - overflow: "Basin k overflowed: v units, its capacity is c."
    /// - time: "Time ran out at tick T: basin k holds cyan a, coral b, yellow c; it needs <target>." — the first basin
    ///   whose target is not met, the target being the basin's ``ColorfallCanyonsBasin/description``
    ///
    /// each followed by a space and ``advice``.
    public var text: String { detail + " " + Self.advice }

    /// The explanation of `play`'s failure, or nil unless the play is `failed` (or `result` after a failure) and its
    /// fluid shows the failure's cause in the kernel's verdict order.
    public init?(play: ColorfallCanyonsPlay) {
        guard play.stage == .failed || play.stage == .result, let failure = play.failure else { return nil }
        let level: ColorfallCanyonsLevel = play.level
        let fluid: ColorfallCanyonsFluid = play.fluid
        self.failure = failure
        tick = fluid.tick
        switch failure {
        case .contamination:
            var found: Int?
            for (index, basin) in level.basins.enumerated()
            where basin.isProtected && basin.wrongMass(fluid.masses[basin.cell]) > basin.toleratedWrong {
                found = index
                break
            }
            guard let index = found else { return nil }
            let target: ColorfallCanyonsBasin = level.basins[index]
            let masses: [Int] = fluid.masses[target.cell]
            var wrong: [ColorfallCanyonsColor] = []
            var dominant: ColorfallCanyonsColor?
            for color in ColorfallCanyonsColor.allCases where target.shares[color.rawValue] == 0 {
                if masses[color.rawValue] > 0 { wrong.append(color) }
                if dominant == nil || masses[color.rawValue] > masses[dominant?.rawValue ?? 0] { dominant = color }
            }
            let amount: Int = target.wrongMass(masses)
            basin = index + 1
            color = dominant
            self.amount = amount
            limit = target.toleratedWrong
            let names: String = wrong.isEmpty ? (dominant?.name ?? "") : wrong.map(\.name).joined(separator: " and ")
            detail = "Basin \(index + 1) (row \(target.cell / level.columns + 1), column \(target.cell % level.columns + 1)) "
                + "took \(amount) units of \(names); it allows at most \(target.toleratedWrong)."
        case .overflow:
            var found: Int?
            for (index, basin) in level.basins.enumerated() where fluid.volume(basin.cell) > basin.capacity {
                found = index
                break
            }
            guard let index = found else { return nil }
            let target: ColorfallCanyonsBasin = level.basins[index]
            let volume: Int = fluid.volume(target.cell)
            basin = index + 1
            color = nil
            amount = volume
            limit = target.capacity
            detail = "Basin \(index + 1) overflowed: \(volume) units, its capacity is \(target.capacity)."
        case .time:
            var found: Int?
            for (index, basin) in level.basins.enumerated() where !basin.accepts(fluid.masses[basin.cell]) {
                found = index
                break
            }
            guard let index = found else { return nil }
            let target: ColorfallCanyonsBasin = level.basins[index]
            let masses: [Int] = fluid.masses[target.cell]
            var parts: [String] = []
            for color in ColorfallCanyonsColor.allCases { parts.append("\(color.name) \(masses[color.rawValue])") }
            basin = index + 1
            color = nil
            amount = fluid.volume(target.cell)
            limit = target.fill
            detail = "Time ran out at tick \(fluid.tick): basin \(index + 1) holds \(parts.joined(separator: ", ")); "
                + "it needs \(target.description)."
        }
    }
}
