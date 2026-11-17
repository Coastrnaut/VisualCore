// OrientationTests — feature 147 (A20-P03) T-A20-306 (FR-A20-305, FR-A20-306; SC-A20-303; clarification Q5;
// contracts/stones.md "Orientation"; the manual's regression fixture). The same garden drawn in a 390 × 844 (portrait)
// and an 844 × 390 (landscape) view inside the one app's session host: the document and the digest are unchanged, the
// sand field and the stone layer are identical (both depend only on the document) and were rebuilt for the new size,
// and every stone centre and stroke point mapped to the view, and to the nearest framebuffer pixel, and back lies within
// one cell (1/480 tray widths) of its stored value. The snapshot stays schema 1. Short runs only.
import Foundation
import Testing
import DigitalZenGardenCore
@testable import DigitalZenGardenExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

@MainActor
@Suite(.serialized) struct OrientationTests {
    /// One cell of the drawn field in tray widths.
    private static let cell = 1.0 / 480

    /// The largest distance in tray widths between `points` mapped into a view of `size` and back, through view
    /// points and through the nearest pixel of the framebuffer tray `trayPixels` (origin bottom-left).
    private func largestRoundTrip(_ points: [Vec2], size: Vec2, trayPixels: SIMD4<Float>) -> Double {
        let tray = TrayFit.rect(width: size.x, height: size.y)
        var largest = 0.0
        for point in points {
            let view = Vec2(tray.x + point.x * tray.width, tray.y + point.y * tray.height)
            if let back = TrayFit.trayPoint(view, viewSize: size) {
                largest = max(largest, StrokeResampler.trayDistance(back, point))
            } else {
                largest = .infinity
            }
            let px = (Double(trayPixels.x) + point.x * Double(trayPixels.z)).rounded(.down) + 0.5
            let py = (Double(trayPixels.y) + (1 - point.y) * Double(trayPixels.w)).rounded(.down) + 0.5
            let pixelBack = Vec2((px - Double(trayPixels.x)) / Double(trayPixels.z),
                                 1 - (py - Double(trayPixels.y)) / Double(trayPixels.w))
            largest = max(largest, StrokeResampler.trayDistance(pixelBack, point))
        }
        return largest
    }

    @Test func portraitAndLandscapeKeepTheGarden() async throws {
        let session = ExperienceSession()
        let portrait = CGSize(width: 390, height: 844)
        let shell = try await GardenTest.open(session, size: portrait)
        GardenTest.rake(shell, from: Vec2(0.1, 0.2), to: Vec2(0.9, 0.3))
        GardenTest.rake(shell, from: Vec2(0.2, 0.8), to: Vec2(0.7, 0.4), rake: 1)
        GardenTest.accept(shell, "stone.place", [4, 0.3, 0.6])
        GardenTest.accept(shell, "stone.place", [1, 0.65, 0.35])
        GardenTest.accept(shell, "stone.rotate", [1.2])
        GardenTest.accept(shell, "stone.place", [3, 0.95, 0.05])
        try GardenTest.draw(session)
        let core = try GardenTest.core(shell)
        let digest = try GardenTest.digest(shell)
        let sand = try #require(shell.presenter.sand)
        let field = sand.shown
        let stones = sand.stones
        let portraitTray = sand.trayPixels
        let replays = sand.replayCount
        let stoneRebuilds = sand.stoneRebuildCount
        #expect(stones == StoneLayer(stones: core.document.stones), "the portrait layer is the document's")
        var points = core.document.stones.map(\.position)
        for stroke in core.document.strokes { points += stroke.points }
        let portraitError = largestRoundTrip(points, size: Vec2(390, 844), trayPixels: portraitTray)
        #expect(portraitError <= Self.cell, "portrait round trip \(portraitError)")

        let view = try #require(session.renderHost?.view)
        view.frame = CGRect(origin: .zero, size: CGSize(width: 844, height: 390))
        view.layoutIfNeeded()
        try GardenTest.draw(session)
        let turned = try #require(shell.presenter.sand)
        #expect(turned.trayPixels != portraitTray, "the tray was fitted again")
        #expect(turned.replayCount == replays + 1 && turned.stoneRebuildCount == stoneRebuilds + 1,
                "both layers were rebuilt for the new size")
        #expect(try GardenTest.core(shell) == core, "the document and the state are unchanged")
        #expect(try GardenTest.digest(shell) == digest)
        #expect(turned.shown == field, "the sand field is identical")
        #expect(turned.stones == stones, "the stone layer is identical")
        let landscapeError = largestRoundTrip(points, size: Vec2(844, 390), trayPixels: turned.trayPixels)
        #expect(landscapeError <= Self.cell, "landscape round trip \(landscapeError)")
        // Back to portrait: still the same garden.
        view.frame = CGRect(origin: .zero, size: portrait)
        view.layoutIfNeeded()
        try GardenTest.draw(session)
        let back = try #require(shell.presenter.sand)
        #expect(back.trayPixels == portraitTray && back.shown == field && back.stones == stones)
        // The snapshot stays schema 1 and holds the same garden.
        #expect(GardenCore.schemaVersion == 1)
        let restored = try GardenCore.restore(payload: core.snapshotPayload(), seed: 1)
        #expect(restored.document == core.document)
        session.close()
        let counts = try #require(session.diagnostics.lastCloseCounts)
        #expect(counts.objects == 0 && counts.leaked == 0)
    }
}
