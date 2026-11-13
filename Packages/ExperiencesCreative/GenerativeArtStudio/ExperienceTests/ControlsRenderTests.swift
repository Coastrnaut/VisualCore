// ControlsRenderTests — feature 013 T-A01-208 (FR-A01-202, FR-A01-204; SC-A01-202, SC-A01-203; R5).
import XCTest
import GenerativeArtStudioCore
import VisualCoreRendering
import VisualCoreSimulation
import VisualCoreTestSupport
@testable import GenerativeArtStudioExperience

@MainActor
final class ControlsRenderTests: XCTestCase {
    func testParameterChangeIsVisibleAndResetAllRestoresThePresetImage() throws {
        for family in FamilyCatalog.all {
            var editor = CompositionEditor(family: family)
            let preset = try ArtRender.pixels(editor.composition)
            let name = family.schema.definitions[0].name
            let t = editor.editor.normalized(name)
            editor.setParameter(name, normalized: t > 0.6 ? t - 0.35 : t + 0.35)
            let changed = try ArtRender.pixels(editor.composition)
            let d = ImageComparison.compare(preset, changed)
            XCTAssertGreaterThanOrEqual(d.meanAbsolute, 1, "\(family.id).\(name) change is visible")
            editor.resetAll()
            let back = ImageComparison.compare(preset, try ArtRender.pixels(editor.composition))
            XCTAssertGreaterThanOrEqual(back.fractionWithin(2), 0.99, "\(family.id) reset all")
            print("SC-A01-202 \(family.id.rawValue).\(name): change mean=\(d.meanAbsolute) reset within2=\(back.fractionWithin(2))")
        }
    }

    private func renderPaused(_ document: ArtDocument, at time: Double) throws -> (pixels: [UInt8], host: RenderHost, clocked: ClockedArtScene) {
        let scene = ArtSceneFactory.makeScene(for: document)
        var clock = SceneClock()
        clock.pause()
        clock.scrub(to: time)
        let clocked = ClockedArtScene(inner: scene, clock: clock)
        let host = try RenderHost(scene: clocked)
        host.view.frame = CGRect(origin: .zero, size: ArtRender.size)
        host.view.layoutIfNeeded()
        for _ in 0..<3 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        return (host.readPixels(), host, clocked)
    }

    func testPausedScrubbedSceneIsDeterministic() throws {
        for family in SceneFamilyID.allCases {
            let doc = try ArtRender.document(family)
            let a = try renderPaused(doc, at: 2.0), b = try renderPaused(doc, at: 2.0)
            defer { a.host.destroy(); b.host.destroy() }
            XCTAssertEqual(a.clocked.clock.time, 2.0, "paused clock does not advance")
            XCTAssertEqual(ImageComparison.compare(a.pixels, b.pixels).maxAbsolute, 0, "\(family) scrub determinism")
            let c = try renderPaused(doc, at: 3.5)
            defer { c.host.destroy() }
            print("SC-A01-203 \(family.rawValue): t=2.0 twice max=0; vs t=3.5 mean=\(ImageComparison.compare(a.pixels, c.pixels).meanAbsolute)")
        }
    }

    func testLiveEditsEqualAFreshRenderOfTheNewComposition() throws {
        for family in SceneFamilyID.allCases {
            var editor = CompositionEditor(family: FamilyCatalog.family(family))
            let live = try renderPaused(editor.composition, at: 1.5)
            defer { live.host.destroy() }
            editor.choosePalette("neon")
            editor.setSeed(31337)
            ArtSceneFactory.apply(editor.composition, to: live.clocked.inner)
            XCTAssertTrue(live.host.renderOneFrame(present: false))
            let fresh = try renderPaused(editor.composition, at: 1.5)
            defer { fresh.host.destroy() }
            let d = ImageComparison.compare(live.host.readPixels(), fresh.pixels)
            XCTAssertEqual(d.maxAbsolute, 0, "\(family) live edit equals fresh render")
        }
    }

    func testControlsNeverCreateAnotherRenderHost() throws {
        let model = SceneModel(family: FamilyCatalog.family(.particles), reduceMotion: false)
        defer { model.close() }
        let host = try XCTUnwrap(model.host)
        host.view.frame = CGRect(origin: .zero, size: ArtRender.size)
        host.view.layoutIfNeeded()
        XCTAssertTrue(host.renderOneFrame(present: false))
        model.editor.setParameter("count", normalized: 0.9)
        model.editor.choosePreset("particles-burst")
        model.editor.choosePalette("ocean")
        model.editor.setSeed(99)
        model.togglePlay()
        model.scrub(to: 4)
        model.editor.resetAll()
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertTrue(model.host === host, "one render host for the screen's lifetime")
        XCTAssertTrue(model.clocked.inner === model.scene, "the scene object is reused; only its inputs change")
        XCTAssertEqual(model.clocked.clock.time, 4)
        XCTAssertEqual(host.resources.stats.leaked, 0)
    }
}
