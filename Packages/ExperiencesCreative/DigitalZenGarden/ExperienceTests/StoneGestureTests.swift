// StoneGestureTests — feature 147 (A20-P03) T-A20-305 (FR-A20-303, FR-A20-304; SC-A20-302; clarifications Q3, Q4;
// contracts/stones.md "Selection", "Gestures"). The stone tool through the shell's pointer path, without a render host:
// a tap sends `stone.select` with the topmost stone's id and empty sand sends 0; an unknown id is refused; a drag that
// starts on the selected stone shows the move and sends one `stone.move` on lift; a two-finger turn sends one
// `stone.rotate` at its end; a cancelled drag or turn sends nothing; the native controls select the neighbours, turn by
// 15° and nudge; removing the selected stone clears the selection and its outline; the spoken selection value; the rake
// tool rakes over stones without moving them; every gesture action is a native action. Short runs only.
import Foundation
import Testing
import DigitalZenGardenCore
@testable import DigitalZenGardenExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite struct StoneGestureTests {
    /// A shell in the stone tool with a moss boulder (id 1) at (0.5, 0.5) under a flat slate (id 2) at (0.52, 0.5);
    /// the slate is selected.
    private func overlapping() async throws -> ExperienceShell<GardenPresenter> {
        let shell = try await GardenTest.shell()
        GardenTest.accept(shell, "tool.mode", [1])
        GardenTest.accept(shell, "stone.place", [4, 0.5, 0.5])
        GardenTest.accept(shell, "stone.place", [1, 0.52, 0.5])
        return shell
    }

    /// A tap of pointer `id` at the tray point `tray`.
    private func tap(_ shell: ExperienceShell<GardenPresenter>, _ tray: Vec2, id: Int = 1) {
        GardenTest.touch(shell, .began, at: GardenTest.viewPoint(tray), id: id)
        GardenTest.touch(shell, .ended, at: GardenTest.viewPoint(tray), id: id)
    }

    @Test func aTapSelectsTheTopmostStoneAndEmptySandSelectsNone() async throws {
        let shell = try await overlapping()
        tap(shell, Vec2(0.1, 0.1))
        #expect(try GardenTest.core(shell).selectedStone == nil, "empty sand sends 0")
        tap(shell, Vec2(0.51, 0.5))
        #expect(try GardenTest.core(shell).selectedStone == 2, "the slate lies on top in the overlap")
        tap(shell, Vec2(0.44, 0.5))
        #expect(try GardenTest.core(shell).selectedStone == 1, "only the boulder lies there")
        #expect(shell.presenter.mirror.selectedStone == 1)
        // An unknown id is refused and the selection is kept.
        let unknown = shell.handle(control: "stone.select", values: [99])
        #expect(unknown.code == "action.rule.a20.unknown-stone")
        #expect(try GardenTest.core(shell).selectedStone == 1)
        #expect(try GardenTest.core(shell).history.done.count == 2, "selecting is no command")
    }

    @Test func aDragFromTheSelectedStoneShowsTheMoveAndSendsOneMoveOnLift() async throws {
        let shell = try await overlapping()
        let before = try GardenTest.core(shell)
        GardenTest.touch(shell, .began, at: GardenTest.viewPoint(Vec2(0.52, 0.5)))
        GardenTest.touch(shell, .moved, at: GardenTest.viewPoint(Vec2(0.58, 0.55)))
        GardenTest.touch(shell, .moved, at: GardenTest.viewPoint(Vec2(0.62, 0.6)))
        #expect(try GardenTest.core(shell) == before, "nothing is sent while the finger moves")
        let shown = try #require(shell.presenter.shownSelection)
        #expect(abs(shown.position.x - 0.62) < 1e-9 && abs(shown.position.y - 0.6) < 1e-9, "the overlay shows the drag")
        #expect(shell.presenter.preview.selection.visible)
        GardenTest.touch(shell, .ended, at: GardenTest.viewPoint(Vec2(0.62, 0.6)))
        let after = try GardenTest.core(shell)
        #expect(after.history.done.count == before.history.done.count + 1, "one move")
        let stone = try #require(after.selected)
        #expect(stone.id == 2 && abs(stone.position.x - 0.62) < 1e-9 && abs(stone.position.y - 0.6) < 1e-9)
        #expect(after.document.stones.first { $0.id == 1 }?.position == Vec2(0.5, 0.5), "the boulder stays")
        // A drag that starts on empty sand moves nothing and is no tap.
        GardenTest.touch(shell, .began, at: GardenTest.viewPoint(Vec2(0.1, 0.8)))
        GardenTest.touch(shell, .moved, at: GardenTest.viewPoint(Vec2(0.3, 0.8)))
        GardenTest.touch(shell, .ended, at: GardenTest.viewPoint(Vec2(0.3, 0.8)))
        #expect(try GardenTest.core(shell) == after)
    }

    @Test func aTwoFingerTurnSendsOneRotateAtItsEnd() async throws {
        let shell = try await overlapping()
        let before = try GardenTest.core(shell)
        let pivot = Vec2(150, 150)
        GardenTest.touch(shell, .began, at: pivot, id: 1)
        GardenTest.touch(shell, .began, at: pivot + Vec2(60, 0), id: 2)
        let angle = Double.pi / 6
        // Finger 2 turns clockwise on the screen around finger 1 in three steps.
        for step in 1...3 {
            let a = angle * Double(step) / 3
            GardenTest.touch(shell, .moved, at: pivot + Vec2(60 * cos(a), 60 * sin(a)), id: 2)
        }
        #expect(try GardenTest.core(shell) == before, "nothing is sent while turning")
        let shown = try #require(shell.presenter.shownSelection)
        #expect(abs(shown.rotation - angle) < 1e-9, "the overlay shows the turn")
        GardenTest.touch(shell, .ended, at: pivot + Vec2(60 * cos(angle), 60 * sin(angle)), id: 2)
        GardenTest.touch(shell, .ended, at: pivot, id: 1)
        let after = try GardenTest.core(shell)
        #expect(after.history.done.count == before.history.done.count + 1, "one turn")
        let stone = try #require(after.selected)
        #expect(abs(stone.rotation - angle) < 1e-9, "clockwise on the screen is a positive rotation")
        #expect(stone.position == Vec2(0.52, 0.5), "turning does not move the stone")
        #expect(shell.presenter.mirror.selectionValue == "Flat slate selected, 2 of 2, turned 30°")
        #expect(GardenPresenter.selectionValue(after) == shell.presenter.mirror.selectionValue)
    }

    @Test func aCancelledDragOrTurnSendsNothing() async throws {
        let shell = try await overlapping()
        let before = try GardenTest.core(shell)
        GardenTest.touch(shell, .began, at: GardenTest.viewPoint(Vec2(0.52, 0.5)))
        GardenTest.touch(shell, .moved, at: GardenTest.viewPoint(Vec2(0.7, 0.7)))
        GardenTest.touch(shell, .cancelled, at: GardenTest.viewPoint(Vec2(0.7, 0.7)))
        #expect(try GardenTest.core(shell) == before)
        #expect(shell.presenter.shownSelection?.position == Vec2(0.52, 0.5), "the outline returns")
        // A turn cut off by `cancelPointers` (the app suspended) sends nothing either.
        GardenTest.touch(shell, .began, at: Vec2(150, 150), id: 3)
        GardenTest.touch(shell, .began, at: Vec2(210, 150), id: 4)
        GardenTest.touch(shell, .moved, at: Vec2(200, 180), id: 4)
        shell.presenter.cancelPointers()
        GardenTest.touch(shell, .ended, at: Vec2(200, 180), id: 4)
        GardenTest.touch(shell, .ended, at: Vec2(150, 150), id: 3)
        #expect(try GardenTest.core(shell) == before)
        #expect(shell.presenter.stoneTracker.count == 0 && shell.presenter.turnStart == nil)
    }

    @Test func theNativeControlsSelectTurnNudgeAndRemove() async throws {
        let shell = try await overlapping()
        var core = try GardenTest.core(shell)
        let next = try #require(StoneControlValues.select(direction: 1, stones: core.document.stones,
                                                          selected: core.selectedStone))
        #expect(next == [1], "after the top stone comes the lowest")
        GardenTest.accept(shell, "stone.select", next)
        #expect(shell.presenter.mirror.selectionValue == "Moss boulder selected, 1 of 2, turned 0°")
        core = try GardenTest.core(shell)
        let previous = try #require(StoneControlValues.select(direction: -1, stones: core.document.stones,
                                                              selected: core.selectedStone))
        #expect(previous == [2])
        let turn = try #require(StoneControlValues.turn(steps: 1, stones: core.document.stones, selected: 1))
        GardenTest.accept(shell, "stone.rotate", turn)
        core = try GardenTest.core(shell)
        let turned = try #require(core.selected)
        #expect(abs(turned.rotation - Double.pi / 12) < 1e-12)
        let left = try #require(StoneControlValues.turn(steps: -2, stones: core.document.stones, selected: 1))
        #expect(abs(left[0] + Double.pi / 12) < 1e-12)
        let nudge = try #require(StoneControlValues.nudge(dx: 1, dy: 1, stones: core.document.stones, selected: 1))
        #expect(abs(nudge[0] - 0.52) < 1e-12 && abs(nudge[1] - (0.5 + 0.02 / 0.75)) < 1e-12)
        GardenTest.accept(shell, "stone.move", nudge)
        #expect(StoneControlValues.turn(steps: 1, stones: core.document.stones, selected: nil) == nil)
        #expect(StoneControlValues.select(direction: 1, stones: [], selected: nil) == nil)
        #expect(StoneControlValues.place(kind: 9) == [4, 0.5, 0.5])
        // Removing the selected stone clears the selection and its outline.
        #expect(shell.presenter.preview.selection.visible)
        GardenTest.accept(shell, "stone.remove")
        #expect(try GardenTest.core(shell).selectedStone == nil)
        #expect(shell.presenter.mirror.selectedStone == nil && !shell.presenter.preview.selection.visible)
        #expect(shell.presenter.mirror.selectionValue == GardenPresenter.noSelectionValue)
        #expect(shell.presenter.mirror.stones.map(\.id) == [2])
    }

    @Test func theStoneCapMessageIsShownUntilAStoneIsRemoved() async throws {
        let shell = try await GardenTest.shell()
        for index in 0..<GardenDocument.maxStones {
            shell.handle(control: "stone.place", values: [0, 0.04 * Double(index + 1), 0.5])
        }
        let result = shell.handle(control: "stone.place", values: [0, 0.5, 0.5])
        #expect(result.code == "action.rule." + GardenRule.stoneCap)
        shell.presenter.mirror.stoneCapShown = true
        shell.presenter.follow(try GardenTest.core(shell))
        #expect(shell.presenter.mirror.message == GardenCore.stoneCapMessage)
        GardenTest.accept(shell, "stone.remove")
        #expect(shell.presenter.mirror.message == nil && !shell.presenter.mirror.stoneCapShown)
    }

    @Test func theRakeToolRakesOverStonesWithoutMovingThem() async throws {
        let shell = try await overlapping()
        GardenTest.accept(shell, "tool.mode", [0])
        let before = try GardenTest.core(shell)
        GardenTest.drag(shell, tray: [Vec2(0.3, 0.5), Vec2(0.7, 0.5)])
        let after = try GardenTest.core(shell)
        #expect(after.document.strokes.count == 1, "the drag raked")
        #expect(after.document.stones == before.document.stones && after.selectedStone == 2)
        #expect(shell.presenter.describe(after).hasSuffix("2 stones, Flat slate selected, 2 of 2, turned 0°"))
    }

    @Test func everyGestureActionIsANativeAction() async throws {
        let shell = try await GardenTest.shell()
        let presenter = shell.presenter
        #expect(presenter.gestureActions.isSuperset(of: GardenCore.stoneGestureActionIDs))
        #expect(presenter.gestureActions.isSubset(of: presenter.nativeActions))
        #expect(GestureAlternatives.missing(gesture: presenter.gestureActions, native: presenter.nativeActions).isEmpty)
        for id in ["stone.place", "stone.select", "stone.move", "stone.rotate", "stone.remove", "tool.mode"] {
            #expect(presenter.nativeActions.contains(id), "\(id)")
        }
    }
}
