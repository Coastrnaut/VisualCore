// ProjectMSceneTests — feature 008 T-F705 (US1 AC1–AC4, FR-F702/FR-F703, edge cases). The unmodified engine
// renders the upstream test preset through the VisualCore host on the simulator.
import ProjectMBridge
import VisualCoreRendering
import XCTest
@testable import ProjectMReference

@MainActor
enum HarnessSupport {
    static func preset(_ name: String) -> String { HarnessLinkTests.presetsDirectory.appendingPathComponent(name).path }

    static func host(_ scene: RenderScene, width: CGFloat = 64, height: CGFloat = 64) throws -> RenderHost {
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
        host.view.layoutIfNeeded()
        return host
    }

    static func uniqueColors(_ p: [UInt8]) -> Int {
        var set = Set<UInt32>()
        for i in stride(from: 0, to: p.count, by: 4) { set.insert(UInt32(p[i]) << 16 | UInt32(p[i + 1]) << 8 | UInt32(p[i + 2])) }
        return set.count
    }
}

@MainActor
final class ProjectMSceneTests: XCTestCase {
    func testRendersChangingNonUniformFrames() throws {
        // AC1: 100-square.milk with the synthetic signal over 30 frames.
        let scene = ProjectMScene(presetPath: HarnessSupport.preset("100-square.milk"))
        let host = try HarnessSupport.host(scene)
        XCTAssertNil(scene.lastError)
        for _ in 0..<10 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        let early = host.readPixels()
        for _ in 0..<20 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        let late = host.readPixels()
        XCTAssertEqual(scene.frames, 30)
        XCTAssertGreaterThan(ImageDiff.litFraction(late), 0.01, "the preset drew something")
        XCTAssertGreaterThan(HarnessSupport.uniqueColors(late), 10, "not a uniform image")
        XCTAssertGreaterThan(ImageDiff.compare(early, late)!.meanAbs, 0.5, "frames change over time")
        host.destroy()
        XCTAssertEqual(host.resources.stats.leaked, 0)
    }

    func testResizeFollowsAndRecreationRecreatesTheEngine() throws {
        // AC2 + AC3
        let scene = ProjectMScene(presetPath: HarnessSupport.preset("100-square.milk"))
        let host = try HarnessSupport.host(scene)
        for _ in 0..<5 { _ = host.renderOneFrame(present: false) }
        host.view.frame = CGRect(x: 0, y: 0, width: 96, height: 48)
        host.view.layoutIfNeeded()
        for _ in 0..<5 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        XCTAssertEqual(scene.viewports.last?.width, host.pixelSize.width)
        XCTAssertEqual(scene.viewports.last?.height, host.pixelSize.height)
        XCTAssertGreaterThan(ImageDiff.litFraction(host.readPixels()), 0.01)
        let generation = host.generation
        host.recreateContext()
        for _ in 0..<5 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        XCTAssertEqual(scene.enginesCreated, 2)
        XCTAssertEqual(scene.engineGeneration, generation + 1)
        XCTAssertNil(scene.lastError, "preset reloaded on the new context")
        XCTAssertGreaterThan(ImageDiff.litFraction(host.readPixels()), 0.01)
        host.destroy()
        XCTAssertFalse(scene.hasEngine, "released on teardown")
        XCTAssertEqual(host.resources.stats.leaked, 0)
    }

    func testFailedPresetKeepsThePreviousOne() throws {
        // AC4 (reference FR-045)
        let scene = ProjectMScene(presetPath: HarnessSupport.preset("100-square.milk"))
        let host = try HarnessSupport.host(scene)
        for _ in 0..<5 { _ = host.renderOneFrame(present: false) }
        XCTAssertFalse(scene.loadPreset(path: HarnessSupport.preset("missing.milk")))
        XCTAssertEqual((scene.lastError as NSError?)?.code, PMEngineError.presetLoadFailed.rawValue)
        XCTAssertTrue(scene.presetPath.hasSuffix("100-square.milk"))
        for _ in 0..<5 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        XCTAssertGreaterThan(ImageDiff.litFraction(host.readPixels()), 0.01, "previous preset keeps rendering")
        XCTAssertTrue(scene.loadPreset(path: HarnessSupport.preset("200-wave.milk")), "a valid preset still loads (no texture search paths set)")
        for _ in 0..<5 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        host.destroy()
    }

    func testZeroSizeLayoutMakesNoEngineCall() throws {
        let scene = ProjectMScene(presetPath: HarnessSupport.preset("100-square.milk"))
        let host = try HarnessSupport.host(scene, width: 0, height: 0)
        _ = host.renderOneFrame(present: false)
        XCTAssertEqual(scene.frames, 0)
        XCTAssertTrue(scene.viewports.allSatisfy { $0.width > 0 && $0.height > 0 })
        host.destroy()
    }

    func testEngineCreationFailureIsReportedAndTheHostSurvives() throws {
        let scene = ProjectMScene(presetPath: HarnessSupport.preset("100-square.milk"))
        scene.loader = { _, _ in nil }   // resolves no GL entry point
        let host = try HarnessSupport.host(scene)
        XCTAssertFalse(scene.hasEngine)
        XCTAssertNotNil(scene.lastError)
        XCTAssertEqual(scene.enginesCreated, 0)
        _ = host.renderOneFrame(present: false)
        XCTAssertNotEqual(host.state, .destroyed)
        host.destroy()
    }
}
