// PointerPathTests — feature 146 (A20-P02) T-A20-205 (FR-A20-201, FR-A20-205; SC-A20-201; clarification Q2; spec edge
// cases; contracts/experience.md "No gaps"). Drags through the shell's pointer path, without a render host: three
// far-apart pointer events give a committed stroke whose neighbouring points are at most 0.004 + 1e-9 tray widths
// apart; a touch outside the tray waits until it enters it and is clamped to the edge while raking; a drag ending
// outside the tray still ends the stroke; a second finger is ignored; a cancelled touch and `cancelPointers` end the
// drag without a commit; a drag at the stroke cap is refused with the garden unchanged and the message shown; every
// gesture action has a native alternative. Short runs only.
import Foundation
import Testing
import DigitalZenGardenCore
@testable import DigitalZenGardenExperience
import VisualCoreExperience
import VisualCoreMath

@MainActor
@Suite struct PointerPathTests {
    @Test func threeFarApartEventsGiveAStrokeWithoutGaps() async throws {
        let shell = try await GardenTest.shell()
        let points = [Vec2(0.05, 0.1), Vec2(0.95, 0.5), Vec2(0.1, 0.9)]
        GardenTest.drag(shell, tray: points)
        let core = try GardenTest.core(shell)
        #expect(core.document.strokes.count == 1 && !core.isRaking)
        let stroke = try #require(core.document.strokes.first)
        #expect(stroke.points.count > 100, "the sparse drag was resampled")
        #expect(GardenTest.largestGap(stroke.points) <= StrokeResampler.spacing + 1e-9)
        let first = try #require(stroke.points.first)
        let last = try #require(stroke.points.last)
        #expect(StrokeResampler.trayDistance(first, points[0]) < 1e-9)
        #expect(StrokeResampler.trayDistance(last, points[2]) < 1e-9)
        #expect(stroke.rake == "fine-rake")
    }

    @Test func aTouchOutsideTheTrayWaitsAndIsClampedWhileRaking() async throws {
        let shell = try await GardenTest.shell()
        // The 400 × 300 view's tray starts at x = 16 points: x = 4 is outside it.
        GardenTest.touch(shell, .began, at: Vec2(4, 150))
        #expect(try !GardenTest.core(shell).isRaking, "outside the tray nothing begins")
        GardenTest.touch(shell, .moved, at: Vec2(8, 160))
        #expect(try !GardenTest.core(shell).isRaking)
        GardenTest.touch(shell, .moved, at: GardenTest.viewPoint(Vec2(0.5, 0.5)))
        let begun = try GardenTest.core(shell)
        #expect(begun.isRaking && begun.inProgress == [Vec2(0.5, 0.5)])
        GardenTest.touch(shell, .moved, at: Vec2(399, 150))
        let clamped = try GardenTest.core(shell)
        let edge = try #require(clamped.inProgress.last)
        #expect(edge.x == 1 && edge.y >= 0 && edge.y <= 1, "clamped to the tray's right edge")
        GardenTest.touch(shell, .ended, at: Vec2(399, 299))
        let ended = try GardenTest.core(shell)
        #expect(!ended.isRaking && ended.document.strokes.count == 1, "a drag ending outside still ends the stroke")
        #expect(ended.document.strokes[0].points.allSatisfy { TrayFit.isInside($0) })
    }

    @Test func aSecondFingerIsIgnored() async throws {
        let shell = try await GardenTest.shell()
        GardenTest.touch(shell, .began, at: GardenTest.viewPoint(Vec2(0.2, 0.2)), id: 1)
        GardenTest.touch(shell, .moved, at: GardenTest.viewPoint(Vec2(0.4, 0.2)), id: 1)
        let raking = try GardenTest.core(shell)
        GardenTest.touch(shell, .began, at: GardenTest.viewPoint(Vec2(0.8, 0.8)), id: 2)
        GardenTest.touch(shell, .moved, at: GardenTest.viewPoint(Vec2(0.7, 0.7)), id: 2)
        GardenTest.touch(shell, .ended, at: GardenTest.viewPoint(Vec2(0.7, 0.7)), id: 2)
        #expect(try GardenTest.core(shell) == raking, "the second finger sent nothing")
        GardenTest.touch(shell, .ended, at: GardenTest.viewPoint(Vec2(0.6, 0.2)), id: 1)
        let core = try GardenTest.core(shell)
        #expect(core.document.strokes.count == 1)
        #expect(core.document.strokes[0].points.allSatisfy { abs($0.y - 0.2) < 1e-9 })
    }

    @Test func cancellingEndsTheDragWithoutACommit() async throws {
        let shell = try await GardenTest.shell()
        GardenTest.touch(shell, .began, at: GardenTest.viewPoint(Vec2(0.2, 0.5)))
        GardenTest.touch(shell, .moved, at: GardenTest.viewPoint(Vec2(0.6, 0.5)))
        #expect(shell.presenter.preview.state.visible)
        shell.presenter.cancelPointers()
        #expect(!shell.presenter.preview.state.visible && shell.presenter.activePointer == nil)
        GardenTest.touch(shell, .moved, at: GardenTest.viewPoint(Vec2(0.9, 0.9)))
        GardenTest.touch(shell, .ended, at: GardenTest.viewPoint(Vec2(0.9, 0.9)))
        let cancelled = try GardenTest.core(shell)
        #expect(cancelled.document.strokes.isEmpty, "nothing was committed")
        #expect(shell.presenter.cancelledStroke == cancelled.inProgress, "the cancelled stroke is not drawn")
        GardenTest.drag(shell, tray: [Vec2(0.3, 0.3), Vec2(0.3, 0.7)])
        let core = try GardenTest.core(shell)
        #expect(core.document.strokes.count == 1 && shell.presenter.cancelledStroke == nil)
        #expect(core.document.strokes[0].points.allSatisfy { abs($0.x - 0.3) < 1e-9 }, "only the new drag")
        // The cancelled phase of a touch does the same.
        GardenTest.touch(shell, .began, at: GardenTest.viewPoint(Vec2(0.5, 0.5)), id: 4)
        GardenTest.touch(shell, .cancelled, at: GardenTest.viewPoint(Vec2(0.5, 0.6)), id: 4)
        #expect(try GardenTest.core(shell).document.strokes.count == 1)
        #expect(!shell.presenter.preview.state.visible)
    }

    @Test func aDragAtTheStrokeCapIsRefusedWithTheGardenUnchanged() async throws {
        let shell = try await GardenTest.shell()
        for _ in 0..<GardenDocument.maxStrokes {
            shell.handle(control: "stroke.begin", values: [0.5, 0.5, 0])
            shell.handle(control: "stroke.end")
        }
        let full = try GardenTest.core(shell)
        #expect(full.document.strokes.count == GardenDocument.maxStrokes)
        GardenTest.drag(shell, tray: [Vec2(0.1, 0.1), Vec2(0.9, 0.9)])
        let core = try GardenTest.core(shell)
        #expect(core.document == full.document, "the garden is unchanged")
        #expect(core.outcome?.code == "refused-over-cap")
        #expect(shell.presenter.mirror.message == GardenPresenter.fullMessage)
        #expect(shell.handle(control: "edit.undo") == .accepted)
        #expect(shell.presenter.mirror.message == nil)
    }

    @Test func everyGestureActionHasANativeAlternative() async throws {
        let shell = try await GardenTest.shell()
        let presenter = shell.presenter
        #expect(presenter.gestureActions == ["stroke.begin", "stroke.add", "stroke.end"])
        #expect(GestureAlternatives.missing(gesture: presenter.gestureActions, native: presenter.nativeActions).isEmpty)
        let required: Set<String> = ["stroke.begin", "stroke.add", "stroke.end", "rake.style", "sand.tone",
                                     "edit.undo", "edit.redo"]
        #expect(presenter.nativeActions.isSuperset(of: required))
        #expect(presenter.nativeActions.isSubset(of: Set(GardenCore.controls.map(\.id))))
    }
}
