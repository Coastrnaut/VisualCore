// MyceliumArchitectPanelWinTests — feature 514 (R02-G22-04) T-R02G2204-005 (FR-R02G2204-011; SC-R02G2204-005; User
// Story 6). Every move without gestures: all 100 certified levels are won through panel actions only. The panel of
// features 513 and 514 is modelled by a small pure helper (`MyceliumArchitectPanelModel`) that mirrors its controls: the
// cell cursor opens on column 0, row 0 and moves one column or one row per press (Column −/+, Row −/+), clamped to the
// board (presentation only: no action, no action spent, the digest unchanged); Nutrient, Blocker and Clear send exactly
// one `cell.nutrient`, `cell.blocker` or `cell.clear [column, row]` on the cursor's cell; the direction picker opens on
// north and moves one direction per press (Direction −/+, cyclic over north … north-west; presentation only); Seed and
// Unseed send exactly one `root.seed` or `root.unseed [direction]`; "Run" sends `growth.run`; Undo and Redo send
// `play.undo` and `play.redo`. The cursor and the direction persist from one witness action to the next, as the panel's
// selection does. The real adapter `MyceliumArchitectExperienceCore` is prepared from seed n − 1 for level n and driven
// through `apply`; the plan is the stored witness of docs/games/mycelium-architect/levels/NNN.witness.json: each witness
// action as cursor presses to its cell (or direction presses the shorter way round) and its one tool button, then Run.
// After every action the witness's state digest and play fingerprint are reproduced; each level ends won with no more
// actions spent than its budget (exactly the witness's arrangement actions). The 100 levels run in 20 parameterized
// groups of 5 (each level is certified once per process, which dominates the time). Panel Undo then Redo restore the
// adapter digests of every arrangement action exactly. Explicit types, plain loops. Modelled on
// BinaryGardensPanelWinTests (feature 504).
// T-R02G2204-006 extends the model with the panel's placement tool (the "Nutrient tool" and "Blocker tool" buttons,
// presentation only, nutrient at an opening) and "Place at cursor" (one `cell.nutrient` or `cell.blocker [column, row]`
// by the tool on the cursor's cell); "Inspect cursor", "Inspect: none" and "Reset view" send nothing and change no
// digest, so the model counts them as selection presses.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreSimulation
@testable import MyceliumArchitectCore

/// The repository's witness directory, found from this file (five levels up: CoreTests, MyceliumArchitect, the
/// package, Packages).
private let panelWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/mycelium-architect/levels", isDirectory: true)

/// The stored witness of level `number`, read with the plain decoder.
private func panelWitness(_ number: Int) throws -> MyceliumArchitectWitness {
    let name: String = String(format: "%03d.witness.json", number)
    let data: Data = try Data(contentsOf: panelWitnessDirectory.appendingPathComponent(name))
    return try JSONDecoder().decode(MyceliumArchitectWitness.self, from: data)
}

/// A pure model of the Mycelium Architect control panel: the selection its cell cursor and direction picker move and
/// the tool buttons, Seed, Unseed, Run, Undo and Redo that turn it into adapter actions. It mirrors the panel's
/// controls (`MyceliumArchitectControls` and the mirror's cursor); it is not the panel itself.
struct MyceliumArchitectPanelModel {
    /// The cursor's column (0 … width − 1).
    private(set) var column: Int = 0
    /// The cursor's row (0 … height − 1).
    private(set) var row: Int = 0
    /// The selected direction (0 north … 7 north-west).
    private(set) var direction: Int = 0
    /// The board's width.
    let width: Int
    /// The board's height.
    let height: Int
    /// The control presses that sent no action (cursor and direction moves), counted for the report.
    private(set) var selectionPresses: Int = 0
    /// The placement tool the tool buttons choose (nutrient at an opening; presentation only).
    private(set) var tool: MyceliumArchitectTool = .nutrient

    /// The panel showing `core`: the cursor on column 0, row 0, the direction north.
    init(_ core: MyceliumArchitectExperienceCore) {
        width = max(core.play.level.width, 1)
        height = max(core.play.level.height, 1)
    }

    /// An adapter action of `control` with `values`.
    static func action(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// "Column −" or "Column +": the cursor `step` columns over, clamped to the board; no action is sent.
    mutating func moveColumn(_ step: Int) {
        column = min(max(column + step, 0), width - 1)
        selectionPresses += 1
    }

    /// "Row −" or "Row +": the cursor `step` rows over, clamped to the board; no action is sent.
    mutating func moveRow(_ step: Int) {
        row = min(max(row + step, 0), height - 1)
        selectionPresses += 1
    }

    /// "Direction +": the next direction, north-west wrapping to north; no action is sent.
    mutating func directionPlus() {
        direction = (direction + 1) % 8
        selectionPresses += 1
    }

    /// "Nutrient tool" or "Blocker tool": chooses `tool`; no action is sent.
    mutating func chooseTool(_ tool: MyceliumArchitectTool) {
        self.tool = tool
        selectionPresses += 1
    }

    /// "Inspect cursor", "Inspect: none" or "Reset view": presentation only; no action is sent.
    mutating func presentationPress() {
        selectionPresses += 1
    }

    /// "Direction −": the previous direction, north wrapping to north-west; no action is sent.
    mutating func directionMinus() {
        direction = (direction + 7) % 8
        selectionPresses += 1
    }

    /// The cursor's column and row as action values.
    var cellValues: [Double] { [Double(column), Double(row)] }

    /// "Nutrient": one `cell.nutrient [column, row]` on the cursor's cell.
    func nutrient() -> ExperienceAction { Self.action("cell.nutrient", cellValues) }

    /// "Blocker": one `cell.blocker [column, row]` on the cursor's cell.
    func blocker() -> ExperienceAction { Self.action("cell.blocker", cellValues) }

    /// "Place at cursor": one placement by the tool (`cell.nutrient` or `cell.blocker`) on the cursor's cell.
    func placeAtCursor() -> ExperienceAction { Self.action(tool.controlID, cellValues) }

    /// "Clear": one `cell.clear [column, row]` on the cursor's cell.
    func clear() -> ExperienceAction { Self.action("cell.clear", cellValues) }

    /// "Seed": one `root.seed [direction]` for the selected direction.
    func seed() -> ExperienceAction { Self.action("root.seed", [Double(direction)]) }

    /// "Unseed": one `root.unseed [direction]` for the selected direction.
    func unseed() -> ExperienceAction { Self.action("root.unseed", [Double(direction)]) }

    /// "Run": `growth.run`.
    func run() -> ExperienceAction { Self.action("growth.run") }

    /// "Undo": `play.undo`.
    func undo() -> ExperienceAction { Self.action("play.undo") }

    /// "Redo": `play.redo`.
    func redo() -> ExperienceAction { Self.action("play.redo") }
}

@Suite struct MyceliumArchitectPanelWinTests {
    typealias Core = MyceliumArchitectExperienceCore
    typealias Panel = MyceliumArchitectPanelModel

    /// What `arrangedThroughPanel` returns: the core, the panel, the witness and the adapter digests (the opening,
    /// then after each arrangement action).
    struct Arranged {
        /// The adapter after the witness's arrangement actions.
        var core: Core
        /// The panel model after them.
        var panel: Panel
        /// The stored witness.
        let witness: MyceliumArchitectWitness
        /// The adapter digests: the opening, then after each arrangement action.
        let digests: [StateDigest]
    }

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// Moves the cursor to `cell` one press at a time; no press changes the digest.
    static func moveCursor(to cell: MyceliumArchitectCell, core: Core, panel: inout Panel, number: Int) throws {
        #expect(cell.column >= 0 && cell.column < panel.width && cell.row >= 0 && cell.row < panel.height,
                "level \(number): a witness cell off the board the cursor can reach")
        let before: StateDigest = try digest(core)
        var guardPresses: Int = 0
        while panel.column != cell.column && guardPresses < 64 {
            panel.moveColumn(cell.column > panel.column ? 1 : -1)
            guardPresses += 1
        }
        while panel.row != cell.row && guardPresses < 128 {
            panel.moveRow(cell.row > panel.row ? 1 : -1)
            guardPresses += 1
        }
        #expect(panel.column == cell.column && panel.row == cell.row, "level \(number): cursor did not reach the cell")
        #expect(try digest(core) == before, "a cursor press changed the digest")
    }

    /// Turns the direction picker to `direction` the shorter way round; no press changes the digest.
    static func turnDirection(to direction: MyceliumArchitectDirection, core: Core, panel: inout Panel) throws {
        let before: StateDigest = try digest(core)
        let forward: Int = (direction.rawValue - panel.direction + 8) % 8
        if forward <= 8 - forward {
            for _ in 0..<forward { panel.directionPlus() }
        } else {
            for _ in 0..<(8 - forward) { panel.directionMinus() }
        }
        #expect(panel.direction == direction.rawValue)
        #expect(try digest(core) == before, "a direction press changed the digest")
    }

    /// The one panel action of witness action `action` (after moving the cursor or turning the direction picker where
    /// needed), or nil for the run.
    static func panelAction(for action: MyceliumArchitectAction, core: Core, panel: inout Panel,
                            number: Int) throws -> ExperienceAction? {
        switch action {
        case let .nutrient(cell):
            try moveCursor(to: cell, core: core, panel: &panel, number: number)
            let sent: ExperienceAction = panel.nutrient()
            #expect(sent.control == "cell.nutrient" && sent.values == [Double(cell.column), Double(cell.row)])
            return sent
        case let .blocker(cell):
            try moveCursor(to: cell, core: core, panel: &panel, number: number)
            let sent: ExperienceAction = panel.blocker()
            #expect(sent.control == "cell.blocker" && sent.values == [Double(cell.column), Double(cell.row)])
            return sent
        case let .clear(cell):
            try moveCursor(to: cell, core: core, panel: &panel, number: number)
            let sent: ExperienceAction = panel.clear()
            #expect(sent.control == "cell.clear" && sent.values == [Double(cell.column), Double(cell.row)])
            return sent
        case let .seed(direction):
            try turnDirection(to: direction, core: core, panel: &panel)
            let sent: ExperienceAction = panel.seed()
            #expect(sent.control == "root.seed" && sent.values == [Double(direction.rawValue)])
            return sent
        case let .unseed(direction):
            try turnDirection(to: direction, core: core, panel: &panel)
            let sent: ExperienceAction = panel.unseed()
            #expect(sent.control == "root.unseed" && sent.values == [Double(direction.rawValue)])
            return sent
        case .run:
            return nil
        }
    }

    /// Prepares level `number` from seed `number − 1`, checks it is the stored witness's level and applies every
    /// witness arrangement action through the panel (one panel action each), checking the witness digest and
    /// fingerprint after each.
    static func arrangedThroughPanel(_ number: Int) async throws -> Arranged {
        let witness: MyceliumArchitectWitness = try panelWitness(number)
        var core: Core = try await Core.prepare(seed: UInt64(number - 1))
        #expect(core.levelNumber == number)
        #expect(core.play.level.fingerprint == witness.level.fingerprint, "level \(number) differs from its witness")
        #expect(core.play.stage == .playing)
        var panel: Panel = Panel(core)
        #expect(witness.actions.last == .run, "level \(number): the witness does not end with the run")
        let offset: Int = witness.fingerprints.count - witness.actions.count
        #expect(offset >= 1)
        #expect(core.play.fingerprint == witness.fingerprints[offset - 1], "level \(number): opening fingerprint")
        var digests: [StateDigest] = [try digest(core)]
        for index in 0..<(witness.actions.count - 1) {
            let witnessAction: MyceliumArchitectAction = witness.actions[index]
            let sent: ExperienceAction? = try panelAction(for: witnessAction, core: core, panel: &panel,
                                                          number: number)
            let action: ExperienceAction = try #require(sent, "level \(number) action \(index): no panel action")
            #expect(core.apply(action) == .accepted, "level \(number) action \(index) refused")
            #expect(core.play.actionsSpent == index + 1, "level \(number) action \(index): more than one action")
            #expect(MyceliumArchitectWitness.digest(arrangement: core.play.arrangement, spent: core.play.actionsSpent)
                    == witness.digests[index], "level \(number) action \(index): witness digest")
            #expect(core.play.fingerprint == witness.fingerprints[offset + index],
                    "level \(number) action \(index): witness fingerprint")
            digests.append(try digest(core))
        }
        return Arranged(core: core, panel: panel, witness: witness, digests: digests)
    }

    /// Wins level `number` through panel actions only, within its budget.
    static func winThroughPanel(_ number: Int) async throws {
        var arranged: Arranged = try await arrangedThroughPanel(number)
        let arrangementCount: Int = arranged.witness.actions.count - 1
        #expect(arranged.core.apply(arranged.panel.run()) == .accepted)
        #expect(arranged.core.play.stage == .won, "level \(number) not won through the panel")
        #expect(arranged.core.outcome?.code == Core.wonCode)
        #expect(arranged.core.play.fingerprint == arranged.witness.fingerprints.last)
        #expect(arranged.core.play.actionsSpent == arrangementCount)
        #expect(arranged.core.play.actionsSpent <= arranged.core.play.level.budget, "level \(number) over budget")
    }

    /// Levels 5 g + 1 … 5 g + 5 of group `group` (0 … 19).
    @Test(arguments: Array(0..<20))
    func panelWinsGroup(_ group: Int) async throws {
        for number in (group * 5 + 1)...(group * 5 + 5) {
            try await Self.winThroughPanel(number)
        }
    }

    /// Panel Undo walks back every arrangement action to the earlier digests exactly, and Redo forward to the later
    /// ones; nothing is left to undo at the opening or to redo at the end; the redone arrangement still wins on Run.
    @Test(arguments: [1, 50, 100])
    func panelUndoRedoRestoresDigests(_ number: Int) async throws {
        var arranged: Arranged = try await Self.arrangedThroughPanel(number)
        let count: Int = arranged.digests.count - 1
        #expect(count > 0)
        for index in stride(from: count - 1, through: 0, by: -1) {
            #expect(arranged.core.apply(arranged.panel.undo()) == .accepted)
            #expect(try Self.digest(arranged.core) == arranged.digests[index], "undo \(index) of level \(number)")
        }
        #expect(arranged.core.apply(arranged.panel.undo()) != .accepted)
        #expect(try Self.digest(arranged.core) == arranged.digests[0])
        for index in 1...count {
            #expect(arranged.core.apply(arranged.panel.redo()) == .accepted)
            #expect(try Self.digest(arranged.core) == arranged.digests[index], "redo \(index) of level \(number)")
        }
        #expect(arranged.core.apply(arranged.panel.redo()) != .accepted)
        #expect(arranged.core.apply(arranged.panel.run()) == .accepted)
        #expect(arranged.core.outcome?.code == Core.wonCode)
    }

    /// The cursor stays on the board: Column − and Row − at column 0, row 0 and Column + and Row + at the far corner
    /// stay put, and the direction picker wraps both ways; no press changes the digest or spends an action.
    @Test func cursorClampsAndDirectionWraps() async throws {
        let core: Core = try await Core.prepare(seed: 0)
        var panel: Panel = Panel(core)
        let before: StateDigest = try Self.digest(core)
        panel.moveColumn(-1)
        panel.moveRow(-1)
        #expect(panel.column == 0 && panel.row == 0)
        for _ in 0..<(panel.width + 2) { panel.moveColumn(1) }
        for _ in 0..<(panel.height + 2) { panel.moveRow(1) }
        #expect(panel.column == panel.width - 1 && panel.row == panel.height - 1)
        panel.directionMinus()
        #expect(panel.direction == 7)
        panel.directionPlus()
        #expect(panel.direction == 0)
        #expect(try Self.digest(core) == before)
        #expect(core.play.actionsSpent == 0)
    }

    /// The tool buttons choose what "Place at cursor" sends (nutrient at an opening), the presentation-only buttons
    /// send nothing, and a witness placement made through "Place at cursor" reproduces the witness digest of the same
    /// action made through its own button (level 1's first placement, when its witness has one).
    @Test func theToolChoosesWhatPlaceAtCursorSends() async throws {
        let core: Core = try await Core.prepare(seed: 0)
        var panel: Panel = Panel(core)
        let before: StateDigest = try Self.digest(core)
        #expect(panel.tool == .nutrient)
        #expect(panel.placeAtCursor().control == "cell.nutrient" && panel.placeAtCursor().values == panel.cellValues)
        panel.chooseTool(.blocker)
        #expect(panel.tool == .blocker)
        #expect(panel.placeAtCursor().control == "cell.blocker" && panel.placeAtCursor().values == panel.cellValues)
        panel.chooseTool(.nutrient)
        #expect(panel.placeAtCursor().control == "cell.nutrient")
        panel.presentationPress()
        #expect(panel.selectionPresses == 3)
        #expect(try Self.digest(core) == before, "no tool or presentation press changes the digest")

        let witness: MyceliumArchitectWitness = try panelWitness(1)
        var first: MyceliumArchitectAction?
        for action in witness.actions {
            switch action {
            case .nutrient, .blocker:
                if first == nil { first = action }
            default:
                break
            }
        }
        guard let placement = first else { return }
        var byButton: Core = core
        var buttonPanel: Panel = Panel(core)
        let sent: ExperienceAction = try #require(try Self.panelAction(for: placement, core: byButton,
                                                                       panel: &buttonPanel, number: 1))
        var byPlace: Core = core
        var placePanel: Panel = Panel(core)
        switch placement {
        case let .nutrient(cell):
            try Self.moveCursor(to: cell, core: byPlace, panel: &placePanel, number: 1)
            placePanel.chooseTool(.nutrient)
        case let .blocker(cell):
            try Self.moveCursor(to: cell, core: byPlace, panel: &placePanel, number: 1)
            placePanel.chooseTool(.blocker)
        default:
            break
        }
        let placed: ExperienceAction = placePanel.placeAtCursor()
        #expect(placed.control == sent.control && placed.values == sent.values)
        let buttonResult: ActionResult = byButton.apply(sent)
        let placeResult: ActionResult = byPlace.apply(placed)
        #expect(buttonResult == placeResult)
        #expect(try Self.digest(byButton) == Self.digest(byPlace), "the same placement either way")
    }
}
