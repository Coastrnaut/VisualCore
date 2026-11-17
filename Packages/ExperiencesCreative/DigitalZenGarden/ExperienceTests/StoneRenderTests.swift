// StoneRenderTests — feature 147 (A20-P03) T-A20-304 (FR-A20-302, FR-A20-306; SC-A20-301; clarification Q1;
// contracts/stones.md "Drawing"). The stones drawn inside the one app's session host on the simulator, short runs only
// (small canvases, no sleep, no wall-clock assertion): the stone target read back matches the CPU `StoneLayer` within
// 1/1024 in `rgba16f` and 1/255 in the forced `rgba8` fallback; the stones are drawn in their kinds' colours over the
// sand; the sand under a stone's shadow (away from the light) is darker than the same sand without the stone and no
// sand pixel is brighter; undo, redo, a restore and a context recreation rebuild the same picture.
import Foundation
import Testing
import DigitalZenGardenCore
@testable import DigitalZenGardenExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

@MainActor
@Suite(.serialized) struct StoneRenderTests {
    /// The view size of the picture tests, in points.
    private static let size = CGSize(width: 320, height: 240)

    /// Checks that the stone target of `shell` holds the layer of its core's stones within the format's tolerance.
    private func expectStonesMatch(_ shell: ExperienceShell<GardenPresenter>, _ note: String) throws {
        let sand = try #require(shell.presenter.sand, "\(note)")
        let core = try GardenTest.core(shell)
        let expected = StoneLayer(stones: core.document.stones, columns: SandScene.columns, rows: SandScene.rows)
        #expect(sand.stones == expected, "\(note): the CPU layer is the rasterization")
        let target = try #require(sand.stoneTarget, "\(note)")
        let difference = SandScene.stoneMaxDifference(target.readFloatPixels(), layer: expected)
        let tolerance: Float = sand.format == .rgba16f ? 1.0 / 1024 : 1.0 / 255
        #expect(difference <= tolerance, "\(note): read back differs by \(difference)")
    }

    @Test func theStoneTargetMatchesTheLayerInHalfFloatAndInTheFallback() async throws {
        for fallback in [false, true] {
            let session = ExperienceSession()
            let shell = try await GardenTest.open(session, forceFallback: fallback)
            GardenTest.accept(shell, "stone.place", [4, 0.4, 0.5])
            GardenTest.accept(shell, "stone.place", [1, 0.45, 0.55])
            GardenTest.accept(shell, "stone.rotate", [0.6])
            try GardenTest.draw(session)
            let sand = try #require(shell.presenter.sand)
            #expect(sand.format == (fallback ? .rgba8 : .rgba16f))
            try expectStonesMatch(shell, fallback ? "rgba8" : "rgba16f")
            #expect(sand.stones.coveredCount > 500, "the stones cover cells")
            session.close()
            let counts = try #require(session.diagnostics.lastCloseCounts)
            #expect(counts.objects == 0 && counts.leaked == 0, "both targets are released")
        }
    }

    @Test func theSandInAStonesShadowIsDarker() async throws {
        var frames: [GardenFrame] = []
        var trayPixels = SIMD4<Float>(0, 0, 0, 0)
        var layer = StoneLayer()
        for withStone in [false, true] {
            let session = ExperienceSession()
            session.qualityPin = 1
            let shell = try await GardenTest.open(session, size: Self.size)
            if withStone { GardenTest.accept(shell, "stone.place", [3, 0.5, 0.5]) }
            frames.append(try GardenTest.picture(session))
            let sand = try #require(shell.presenter.sand)
            trayPixels = sand.trayPixels
            if withStone { layer = sand.stones }
            session.close()
        }
        let without = frames[0]
        let with = frames[1]
        #expect(without.width == with.width && without.height == with.height)
        var darker = 0
        var brighter = 0
        var stonePixels = 0
        var darkerX = 0.0
        var darkerY = 0.0
        for py in 0..<with.height {
            for px in 0..<with.width {
                let tx = (Double(px) + 0.5 - Double(trayPixels.x)) / Double(trayPixels.z)
                let ty = (Double(py) + 0.5 - Double(trayPixels.y)) / Double(trayPixels.w)
                guard tx > 0, ty > 0, tx < 1, ty < 1 else { continue }
                let cx = tx * Double(layer.columns)
                let cy = ty * Double(layer.rows)
                // Pixels on a cell boundary may fall either way; leave them out.
                if abs(cx - cx.rounded()) < 0.02 || abs(cy - cy.rounded()) < 0.02 { continue }
                let row = layer.rows - 1 - Int(cy)
                let index = (py * with.width + px) * 4
                let a = Int(without.rgba[index]) + Int(without.rgba[index + 1]) + Int(without.rgba[index + 2])
                let b = Int(with.rgba[index]) + Int(with.rgba[index + 1]) + Int(with.rgba[index + 2])
                if layer.kind(column: Int(cx), row: row) != 0 {
                    stonePixels += 1
                    continue
                }
                if b < a - 3 {
                    darker += 1
                    darkerX += tx
                    darkerY += ty
                } else if b > a + 3 {
                    brighter += 1
                }
            }
        }
        #expect(stonePixels > 100, "the basalt is drawn")
        #expect(darker > 50, "the shadow darkens the sand (\(darker) pixels)")
        #expect(brighter == 0, "no sand pixel is brighter (\(brighter))")
        // The light falls from the upper left, so the shadow lies to the right of and below the stone.
        if darker > 0 {
            #expect(darkerX / Double(darker) > 0.5, "the shadow lies right of the stone")
            #expect(darkerY / Double(darker) < 0.5, "the shadow lies below the stone (framebuffer y up)")
        }
    }

    @Test func undoRedoRestoreAndARecreationRebuildTheSamePicture() async throws {
        let session = ExperienceSession()
        let shell = try await GardenTest.open(session)
        GardenTest.rake(shell, from: Vec2(0.1, 0.5), to: Vec2(0.9, 0.5))
        GardenTest.accept(shell, "stone.place", [0, 0.3, 0.4])
        let placed = try GardenTest.picture(session)
        let sand = try #require(shell.presenter.sand)
        let rebuilds = sand.stoneRebuildCount
        GardenTest.accept(shell, "stone.move", [0.6, 0.6])
        let moved = try GardenTest.picture(session)
        #expect(sand.stoneRebuildCount == rebuilds + 1, "a stone change rebuilds the layer once")
        #expect(GardenTest.differingPixels(moved.rgba, placed.rgba) > 0, "the stone moved")
        try expectStonesMatch(shell, "moved")
        GardenTest.accept(shell, "edit.undo")
        let frame1 = try GardenTest.picture(session)
        #expect(frame1.rgba == placed.rgba, "undo draws the earlier picture")
        try expectStonesMatch(shell, "undo")
        GardenTest.accept(shell, "edit.redo")
        let frame2 = try GardenTest.picture(session)
        #expect(frame2.rgba == moved.rgba, "redo draws the later picture")
        let snapshot = try shell.snapshot()
        GardenTest.accept(shell, "stone.remove")
        let removed = try GardenTest.picture(session)
        #expect(GardenTest.differingPixels(removed.rgba, moved.rgba) > 0)
        try shell.restore(snapshot)
        let frame3 = try GardenTest.picture(session)
        #expect(frame3.rgba == moved.rgba, "a restore draws the saved garden")
        session.recreateContext()
        #expect(session.state == .running)
        let frame4 = try GardenTest.picture(session)
        #expect(frame4.rgba == moved.rgba, "a new context draws the same picture")
        try expectStonesMatch(shell, "recreated")
        // A still garden uploads its stones once.
        let uploads = try #require(shell.presenter.sand).stoneUploadCount
        for _ in 0..<3 { try GardenTest.draw(session) }
        #expect(try #require(shell.presenter.sand).stoneUploadCount == uploads)
        session.close()
        let counts = try #require(session.diagnostics.lastCloseCounts)
        #expect(counts.objects == 0 && counts.leaked == 0)
    }

    @Test func stoneUploadValuesAreRowsBottomUp() {
        let stone = Stone(id: 1, kind: "river-pebble", position: Vec2(0.5125, 1.0 / 60), rotation: 0, scale: 1,
                          depth: 0)
        let layer = StoneLayer(stones: [stone], columns: 40, rows: 30)
        let values = SandScene.stoneUploadValues(layer)
        #expect(values.count == 40 * 30 * 4)
        // The pebble lies near the top of the tray: the last GL rows (the field's first rows).
        let topRow = (29 * 40 + 20) * 4
        #expect(values[topRow + 1] == 0.2 && values[topRow] > 0.5 && values[topRow + 3] == 1)
        #expect(values[(0 * 40 + 20) * 4 + 1] == 0)
        #expect(SandScene.stoneMaxDifference(values, layer: layer) == 0)
        #expect(SandScene.stoneMaxDifference([], layer: layer) == .infinity)
    }
}
