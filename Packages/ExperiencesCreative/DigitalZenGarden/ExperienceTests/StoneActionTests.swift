// StoneActionTests — feature 147 (A20-P03) T-A20-304 (FR-A20-301, FR-A20-303; SC-A20-301; clarification Q2;
// contracts/stones.md "Commands", "Selection"). The stone actions of the core: each of place, move, rotate and remove
// undone and redone gives a document equal to the one before and after it; actions needing a selection are refused
// without one, and every refusal leaves the state as it was; placing at 24 stones is refused with its message; moves
// stay inside the tray; the selection and the tool are state outside the digest and the snapshot, and the selection
// clears when its stone leaves the garden. Short runs only.
import Foundation
import Testing
import DigitalZenGardenCore
@testable import DigitalZenGardenExperience
import VisualCoreExperience
import VisualCoreMath

@MainActor
@Suite struct StoneActionTests {
    /// `core` after the accepted `control` with `values` (records an issue when it is refused).
    private func accepted(_ core: GardenCore, _ control: String, _ values: [Double] = []) -> GardenCore {
        let (next, result) = gardenApplied(core, control, values)
        #expect(result == .accepted, "\(control) \(values): \(result.code)")
        return next
    }

    /// A core with one round granite placed at (0.4, 0.5) and selected.
    private func placed() -> GardenCore {
        accepted(GardenCore(), "stone.place", [2, 0.4, 0.5])
    }

    @Test func eachStoneCommandUndoneAndRedoneGivesEqualDocuments() {
        let start = placed()
        #expect(start.document.stones.count == 1 && start.selectedStone == 1)
        #expect(start.document.stones[0].kind == "round-granite" && start.document.stones[0].position == Vec2(0.4, 0.5))
        // The placement itself.
        let empty = GardenCore()
        let undonePlace = accepted(start, "edit.undo")
        #expect(undonePlace.document == empty.document)
        #expect(undonePlace.selectedStone == nil, "the undone placement takes the selection with it")
        #expect(accepted(undonePlace, "edit.redo").document == start.document)
        let steps: [(String, [Double])] = [("stone.move", [0.7, 0.3]), ("stone.rotate", [0.5]),
                                           ("stone.rotate", [-2.5]), ("stone.remove", [])]
        var core = start
        for (control, values) in steps {
            let before = core
            let after = accepted(core, control, values)
            #expect(after.document != before.document, "\(control) changes the garden")
            #expect(after.history.done.count == before.history.done.count + 1, "\(control) is one command")
            let undone = accepted(after, "edit.undo")
            #expect(undone.document == before.document, "\(control) undone")
            let redone = accepted(undone, "edit.redo")
            #expect(redone.document == after.document, "\(control) redone")
            core = after
        }
        #expect(core.document.stones.isEmpty && core.selectedStone == nil, "removing the selected stone clears it")
        let back = accepted(core, "edit.undo")
        #expect(back.document.stones.count == 1 && back.document.stones[0].rotation == -2.5)
        #expect(back.document.stones[0].depth == 0, "the stone returns at its layer")
        #expect(back.selectedStone == nil, "an undone removal does not select")
    }

    @Test func refusalsLeaveTheStateAsItWas() throws {
        let fresh = GardenCore()
        let refusals: [(String, [Double], String)] = [
            ("stone.move", [0.5, 0.5], "action.rule.a20.no-selection"),
            ("stone.rotate", [0.5], "action.rule.a20.no-selection"),
            ("stone.remove", [], "action.rule.a20.no-selection"),
            ("stone.select", [1], "action.rule.a20.unknown-stone"),
            ("stone.select", [1.5], "action.rule.a20.unknown-stone"),
            ("stone.place", [1.5, 0.5, 0.5], "action.rule.a20.invalid-choice"),
            ("stone.place", [5, 0.5, 0.5], "action.out-of-range"),
            ("stone.place", [0, 1.2, 0.5], "action.out-of-range"),
            ("stone.move", [0.5], "action.wrong-value-count"),
            ("stone.rotate", [4], "action.out-of-range"),
            ("tool.mode", [0.5], "action.rule.a20.invalid-choice"),
            ("tool.mode", [2], "action.out-of-range"),
        ]
        let digest = try gardenDigest(fresh)
        for (control, values, code) in refusals {
            let (next, result) = gardenApplied(fresh, control, values)
            #expect(result.code == code, "\(control) \(values)")
            #expect(next == fresh, "\(control) \(values)")
            #expect(try gardenDigest(next) == digest)
        }
        // With a stone, an unknown id is still refused and the selection is kept.
        let core = placed()
        let (next, result) = gardenApplied(core, "stone.select", [42])
        #expect(result.code == "action.rule.a20.unknown-stone")
        #expect(next == core && next.selectedStone == 1)
    }

    @Test func placingAtTwentyFourStonesIsRefusedWithItsMessage() {
        var core = GardenCore()
        for index in 0..<GardenDocument.maxStones {
            let x = 0.05 + 0.9 * Double(index % 6) / 5
            let y = 0.1 + 0.8 * Double(index / 6) / 3
            core = accepted(core, "stone.place", [Double(index % 5), x, y])
        }
        #expect(core.document.stones.count == 24 && core.isAtStoneCap)
        #expect(core.document.stones.map(\.depth) == Array(0..<24), "each above the last")
        let (next, result) = gardenApplied(core, "stone.place", [0, 0.5, 0.5])
        #expect(result.code == "action.rule." + GardenRule.stoneCap)
        #expect(next == core, "the garden is unchanged")
        #expect(GardenCore.stoneCapMessage == "The garden holds 24 stones.")
    }

    @Test func movesStayInsideTheTray() {
        var core = placed()
        core = accepted(core, "stone.move", [1, 0])
        #expect(core.document.stones[0].position == Vec2(1, 0), "the tray's corner is inside")
        // The controls and the drag clamp before they send.
        let stones = core.document.stones
        let nudged = StoneControlValues.nudge(dx: 1, dy: -1, stones: stones, selected: 1)
        #expect(nudged == [1, 0])
        let dragged = GardenPresenter.draggedCentre(Vec2(0.9, 0.5), from: Vec2(100, 100), to: Vec2(900, -400),
                                                    viewSize: GardenTest.viewSize)
        #expect(dragged == Vec2(1, 0))
        #expect(TrayClamp.clamped(-0.2, Double.nan) == Vec2(0, 0.5))
    }

    @Test func unchangedMovesAndTurnsAreAcceptedWithoutACommand() {
        let core = placed()
        let moved = accepted(core, "stone.move", [0.4, 0.5])
        #expect(moved == core && moved.history.done.count == 1)
        let turned = accepted(core, "stone.rotate", [0])
        #expect(turned == core)
    }

    @Test func theSelectionAndTheToolAreStateOutsideTheDigest() throws {
        let core = placed()
        let digest = try gardenDigest(core)
        let tool = accepted(core, "tool.mode", [1])
        #expect(tool.toolMode == 1 && tool != core)
        let none = accepted(tool, "stone.select", [0])
        #expect(none.selectedStone == nil && none != tool)
        let again = accepted(none, "stone.select", [1])
        #expect(again.selectedStone == 1)
        for state in [tool, none, again] { #expect(try gardenDigest(state) == digest) }
        #expect(try again.snapshotPayload() == core.snapshotPayload(), "the snapshot is the document only")
        let restored = try GardenCore.restore(payload: again.snapshotPayload(), seed: 1)
        #expect(restored.selectedStone == nil && restored.toolMode == 0, "a restore clears the selection")
        #expect(restored.document == core.document)
        var reset = again
        reset.reset()
        #expect(reset.selectedStone == nil && reset.toolMode == 0)
        // A redo of a removal clears the selection of the removed stone.
        let removed = accepted(again, "stone.remove")
        let undone = accepted(accepted(removed, "edit.undo"), "stone.select", [1])
        #expect(undone.selectedStone == 1)
        #expect(accepted(undone, "edit.redo").selectedStone == nil)
    }

    @Test func theNewActionsAreDeclared() {
        let ids = GardenCore.controls.map(\.id)
        for id in ["stone.place", "stone.select", "stone.move", "stone.rotate", "stone.remove", "tool.mode"] {
            #expect(ids.contains(id), "\(id)")
        }
        let select = GardenCore.controls.first { $0.id == "stone.select" }
        #expect(select?.ranges == [0...4_294_967_295])
        let rotate = GardenCore.controls.first { $0.id == "stone.rotate" }
        #expect(rotate?.ranges == [-Double.pi...Double.pi])
    }
}
