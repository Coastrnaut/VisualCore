// BrushPreviewTests — feature 146 (A20-P02) T-A20-206 (FR-A20-204; clarification Q4; contracts/experience.md
// "Preview"). The brush preview of a drag: visible at the finger with the rake style's width (scaled to the fitted
// tray) and one line per tine, across the drag direction; it follows the chosen style; it is hidden after the lift and
// after `cancelPointers`; showing and hiding it never changes the digest; the overlay is the canvas overlay. Short runs.
import Foundation
import SwiftUI
import Testing
import DigitalZenGardenCore
@testable import DigitalZenGardenExperience
import VisualCoreExperience
import VisualCoreMath

@MainActor
@Suite struct BrushPreviewTests {
    /// The tray width of the tests' 400 × 300 view, in points.
    private var trayWidth: Double { TrayFit.rect(width: GardenTest.viewSize.x, height: GardenTest.viewSize.y).width }

    @Test func theDragShowsTheRakesWidthAndTines() async throws {
        let shell = try await GardenTest.shell()
        #expect(!shell.presenter.preview.state.visible)
        let start = GardenTest.viewPoint(Vec2(0.3, 0.5))
        GardenTest.touch(shell, .began, at: start)
        var state = shell.presenter.preview.state
        #expect(state.visible && state.position == start)
        let fine = GardenPalette.rakes[0]
        #expect(abs(state.widthPoints - fine.width * trayWidth) < 1e-9)
        #expect(state.tineCount == fine.tines && state.tineOffsets.count == fine.tines && state.tineLines.count == 5)
        #expect(state.corners.count == 4)
        let moved = GardenTest.viewPoint(Vec2(0.3, 0.8))
        GardenTest.touch(shell, .moved, at: moved)
        state = shell.presenter.preview.state
        #expect(state.position == moved)
        #expect(abs(state.direction.x) < 1e-9 && abs(state.direction.y - 1) < 1e-9, "the drag runs down")
        #expect(abs(state.across.x + 1) < 1e-9, "the width lies across the drag")
        let offsets = state.tineOffsets
        #expect(abs(offsets[0] + offsets[offsets.count - 1]) < 1e-9, "the tines are centred")
        #expect(offsets.allSatisfy { abs($0) <= state.widthPoints / 2 })
        GardenTest.touch(shell, .ended, at: moved)
        #expect(!shell.presenter.preview.state.visible, "hidden after the lift")
    }

    @Test func thePreviewFollowsTheRakeStyle() async throws {
        let shell = try await GardenTest.shell()
        #expect(shell.handle(control: "rake.style", values: [1]) == .accepted)
        GardenTest.touch(shell, .began, at: GardenTest.viewPoint(Vec2(0.5, 0.5)))
        let state = shell.presenter.preview.state
        let wide = GardenPalette.rakes[1]
        #expect(state.visible && state.rakeStyle == 1 && state.tineCount == wide.tines)
        #expect(abs(state.widthPoints - wide.width * trayWidth) < 1e-9)
        shell.presenter.cancelPointers()
        #expect(!shell.presenter.preview.state.visible, "hidden after cancelPointers")
    }

    @Test func thePreviewNeverChangesTheDigest() async throws {
        let shell = try await GardenTest.shell()
        GardenTest.drag(shell, tray: [Vec2(0.2, 0.2), Vec2(0.7, 0.4)])
        let digest = try GardenTest.digest(shell)
        let preview = shell.presenter.preview
        preview.show(at: Vec2(100, 100), direction: Vec2(3, 4), rakeStyle: 1, trayWidth: 300)
        #expect(preview.state.visible && abs(preview.state.direction.length - 1) < 1e-12)
        _ = BrushPreview(model: preview).body
        preview.hide()
        #expect(!preview.state.visible)
        #expect(try GardenTest.digest(shell) == digest)
        #expect(shell.canvasOverlay != nil, "the preview is the canvas overlay")
    }
}
