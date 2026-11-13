// LifecycleRegressionTests — feature 016 T-A01-508: the manual's Phase 05 regression fixture. Background/foreground and
// context recreation restore every family at the same time without stale GL handles or leaks (FR-A01-505, SC-A01-504).
import XCTest
import GenerativeArtStudioCore
import VisualCoreDiagnostics
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation
import VisualCoreTestSupport
@testable import GenerativeArtStudioExperience

@MainActor
final class LifecycleRegressionTests: XCTestCase {
    private func model(_ family: SceneFamilyID) throws -> SceneModel {
        let f = FamilyCatalog.family(family)
        let m = SceneModel(family: f, reduceMotion: false, editor: CompositionEditor(family: f, document: try ArtRender.document(family)))
        let host = try XCTUnwrap(m.host)
        host.view.frame = CGRect(origin: .zero, size: ArtRender.size)
        host.view.layoutIfNeeded()
        m.scene.displayScale = Double(host.pixelSize.height) / ArtRender.size.height
        m.clocked.clock.pause()
        m.scrub(to: ArtRender.time)
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertNil(m.scene.errorMessage, family.rawValue)
        return m
    }

    private func background() { NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil) }
    private func foreground() { NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil) }

    func testBackgroundForegroundRestoresEveryFamily() throws {
        for family in SceneFamilyID.allCases {
            let m = try model(family)
            defer { m.close() }
            let host = try XCTUnwrap(m.host)
            let before = host.readPixels()
            background()
            XCTAssertFalse(host.renderOneFrame(present: false), "\(family): no GPU work in the background")
            foreground()
            XCTAssertTrue(host.renderOneFrame(present: false), "\(family): renders after foreground")
            let d = ImageComparison.compare(before, host.readPixels())
            XCTAssertLessThanOrEqual(d.meanAbsolute, 1, "\(family) background/foreground")
            XCTAssertEqual(m.clocked.clock.time, ArtRender.time, accuracy: 1e-9, "\(family): same scene time")
            print("SC-A01-504 \(family.rawValue) background: mean=\(d.meanAbsolute) max=\(d.maxAbsolute)")
        }
    }

    func testContextRecreationRestoresWithoutStaleUseOrLeaks() throws {
        for family in SceneFamilyID.allCases {
            let m = try model(family)
            defer { m.close() }
            let host = try XCTUnwrap(m.host)
            let before = host.readPixels()
            let liveBefore = host.resources.stats.liveCount
            let generation = host.generation
            host.recreateContext()
            XCTAssertGreaterThan(host.generation, generation, "\(family): new context generation")
            XCTAssertEqual(host.resources.stats.leaked, 0, "\(family): the scene released everything before the old context ended")
            let staleAfterRecovery = host.resources.stats.staleRejected
            for _ in 0..<5 { XCTAssertTrue(host.renderOneFrame(present: false)) }
            XCTAssertEqual(host.resources.stats.staleRejected - staleAfterRecovery, 0, "\(family): no stale handle used after recovery")
            XCTAssertNil(m.scene.errorMessage, "\(family)")
            let d = ImageComparison.compare(before, host.readPixels())
            XCTAssertLessThanOrEqual(d.meanAbsolute, 1, "\(family) recreation")
            XCTAssertEqual(host.resources.stats.liveCount, liveBefore, "\(family): resources recreated one for one")
            print("SC-A01-504 \(family.rawValue) recreation: mean=\(d.meanAbsolute) max=\(d.maxAbsolute) stale=0")
        }
    }

    func testRepeatedCyclesDoNotGrowResources() throws {
        let m = try model(.particles)
        defer { m.close() }
        let host = try XCTUnwrap(m.host)
        let liveBefore = host.resources.stats.liveCount
        for i in 0..<20 {
            background()
            foreground()
            XCTAssertTrue(host.renderOneFrame(present: false), "cycle \(i)")
        }
        for _ in 0..<3 {
            host.recreateContext()
            XCTAssertTrue(host.renderOneFrame(present: false))
        }
        XCTAssertEqual(host.resources.stats.liveCount, liveBefore, "20 background cycles + 3 recreations")
        XCTAssertEqual(host.resources.stats.leaked, 0)
    }

    func testExportAfterRecoveryMatchesExportBefore() throws {
        for family in SceneFamilyID.allCases {
            let m = try model(family)
            defer { m.close() }
            let host = try XCTUnwrap(m.host)
            let size = ExportSize(width: 256, height: 320)
            let before = try ExportRunner.render(m, size: size)
            background(); foreground()
            host.recreateContext()
            XCTAssertTrue(host.renderOneFrame(present: false))
            let after = try ExportRunner.render(m, size: size)
            XCTAssertEqual(ImageComparison.compare(before.rgba, after.rgba).maxAbsolute, 0, "\(family) export after recovery")
        }
    }

    func testLimiterSurvivesRecreation() throws {
        let m = try model(.gradientNoise)
        defer { m.close() }
        let host = try XCTUnwrap(m.host)
        m.apply(AccessibilityPreferences(reduceFlashing: .on).resolve(SystemAccessibility()))
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertNotNil(m.effect.renderer)
        let liveBefore = host.resources.stats.liveCount
        host.recreateContext()
        for _ in 0..<3 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        XCTAssertNil(m.effect.lastError)
        XCTAssertNotNil(m.effect.renderer, "the limiter graph is rebuilt on the new context")
        XCTAssertFalse(m.effect.bypassEffects)
        XCTAssertEqual(host.resources.stats.liveCount, liveBefore)
        XCTAssertEqual(host.resources.stats.leaked, 0)
    }
}
