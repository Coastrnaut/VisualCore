// AccessibilityApplyTests — feature 016 T-A01-505 (FR-A01-501, FR-A01-502; SC-A01-501, SC-A01-502; analyze C1).
import CVisualCoreGL
import XCTest
import GenerativeArtStudioCore
import VisualCoreEffects
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation
import VisualCoreUI
@testable import GenerativeArtStudioExperience

/// An ArtScene that clears to black on even frames and white on odd ones (a worst-case flash).
@MainActor
private final class FlashArtScene: ArtScene {
    var errorMessage: String? { nil }
    var fixedTime: Double?
    var timeScale: Double = 1
    var displayScale: Double = 1
    private var frames = 0
    func setup(_ context: RenderContext) throws {}
    func resize(_ context: RenderContext) {}
    func teardown(_ context: RenderContext) {}
    func render(_ context: RenderContext, frame: FrameInfo) throws {
        let v: Float = frames % 2 == 0 ? 0 : 1
        if frame.delta > 0 { frames += 1 }   // offscreen exports (delta 0) do not advance the alternation
        vcglClearColor(v, v, v, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
    }
}

@MainActor
final class AccessibilityApplyTests: XCTestCase {
    private func meanLuma(_ p: [UInt8]) -> Double {
        var sum = 0.0
        for i in stride(from: 0, to: p.count, by: 4) { sum += 0.2126 * Double(p[i]) + 0.7152 * Double(p[i + 1]) + 0.0722 * Double(p[i + 2]) }
        return sum / Double(p.count / 4) / 255
    }

    /// The app's wiring (`SceneModel`) around a flashing scene, by substituting the inner scene through the factory seam:
    /// SceneModel wraps whatever ArtScene it gets in ClockedArtScene and EffectScene exactly as for real families.
    private func flashingModel() throws -> SceneModel {
        let family = FamilyCatalog.family(.gradientNoise)
        let m = SceneModel(family: family, reduceMotion: false, editor: CompositionEditor(family: family),
                           sceneOverride: FlashArtScene())
        let host = try XCTUnwrap(m.host)
        host.view.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        host.view.layoutIfNeeded()
        return m
    }

    func testRateFollowsApplyWithinOneFrame() throws {
        let family = FamilyCatalog.family(.gradientNoise)
        let m = SceneModel(family: family, reduceMotion: false, editor: CompositionEditor(family: family))
        defer { m.close() }
        let host = try XCTUnwrap(m.host)
        host.view.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        host.view.layoutIfNeeded()
        var t0 = m.clocked.clock.time
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(m.clocked.clock.time - t0, 1.0 / 60, accuracy: 1e-9, "normal rate")
        m.apply(AccessibilityPreferences(reduceMotion: .on).resolve(SystemAccessibility()))
        t0 = m.clocked.clock.time
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(m.clocked.clock.time - t0, 0.5 / 60, accuracy: 1e-9, "reduced rate on the next frame")
        m.apply(AccessibilityPreferences().resolve(SystemAccessibility(reduceMotion: false)))
        t0 = m.clocked.clock.time
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(m.clocked.clock.time - t0, 1.0 / 60, accuracy: 1e-9, "normal rate restored")
    }

    func testFlashLimitedOnlyWhenEffectiveAndExportUnlimited() throws {
        let m = try flashingModel()
        defer { m.close() }
        let host = try XCTUnwrap(m.host)
        // Without Reduce Flashing: the full alternation.
        var lumas: [Double] = []
        for _ in 0..<4 { XCTAssertTrue(host.renderOneFrame(present: false)); lumas.append(meanLuma(host.readPixels())) }
        let unlimited = zip(lumas, lumas.dropFirst()).map { abs($1 - $0) }.max() ?? 0
        XCTAssertGreaterThan(unlimited, 0.99)
        XCTAssertTrue(m.effect.bypassEffects)

        // System Dim Flashing Lights on, choice System: limited from the next frame.
        m.apply(AccessibilityPreferences().resolve(SystemAccessibility(dimFlashingLights: true)))
        XCTAssertFalse(m.effect.bypassEffects)
        lumas = [lumas.last!]
        for _ in 0..<12 { XCTAssertTrue(host.renderOneFrame(present: false)); lumas.append(meanLuma(host.readPixels())) }
        let bound = 0.3 / 60 + 1.0 / 255 + 1e-9
        let limited = zip(lumas, lumas.dropFirst()).map { abs($1 - $0) }
        // The limiter starts from the frame shown when the setting turns on (it seeds on that frame, so that one
        // transition is the content's own); every later frame is limited, and the limiter adds no jump of its own.
        XCTAssertLessThanOrEqual(limited[0], unlimited + 1e-9, "the toggle frame is the content's own transition")
        XCTAssertTrue(limited.dropFirst().allSatisfy { $0 <= bound }, "per-frame change \(limited.dropFirst().max() ?? 0) ≤ \(bound)")
        print("SC-A01-502 per-frame Δ: \(limited.map { String(format: "%.4f", $0) })")
        print("SC-A01-502 unlimited max Δ=\(unlimited) limited max Δ after start=\(limited.dropFirst().max() ?? 0) bound=\(bound)")

        // An export meanwhile is the unlimited content, and the limiter keeps its renderer.
        let renderer = try XCTUnwrap(m.effect.renderer)
        let still = try ExportRunner.render(m, size: ExportSize(width: 32, height: 32))
        let value = Int(still.pixel(x: 16, y: 16).x)
        XCTAssertTrue(value == 0 || value == 255, "export is unlimited: \(value)")
        XCTAssertTrue(m.effect.renderer === renderer)
        XCTAssertFalse(m.effect.bypassEffects, "limiter restored after the export")
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertLessThanOrEqual(abs(meanLuma(host.readPixels()) - lumas.last!), 2 * bound, "no jump after the export")

        // Choice Off overrides the system.
        m.apply(AccessibilityPreferences(reduceFlashing: .off).resolve(SystemAccessibility(dimFlashingLights: true)))
        XCTAssertTrue(m.effect.bypassEffects)
    }

    // Analyze C1: a system change delivered while backgrounded applies on the first frame after foreground.
    func testChangeWhileBackgroundedAppliesOnReturn() throws {
        let family = FamilyCatalog.family(.gradientNoise)
        let m = SceneModel(family: family, reduceMotion: false, editor: CompositionEditor(family: family))
        defer { m.close() }
        let host = try XCTUnwrap(m.host)
        host.view.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        host.view.layoutIfNeeded()
        var system = SystemAccessibility()
        let observer = SystemAccessibilityObserver(source: { system })
        let prefs = AccessibilityPreferences()
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertFalse(host.renderOneFrame(present: false), "suspended while backgrounded")
        system = SystemAccessibility(reduceMotion: true, dimFlashingLights: true)
        NotificationCenter.default.post(name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        m.apply(prefs.resolve(observer.current))   // what SceneScreen's onChange does
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        let t0 = m.clocked.clock.time
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(m.clocked.clock.time - t0, 0.5 / 60, accuracy: 1e-9)
        XCTAssertFalse(m.effect.bypassEffects)
        XCTAssertTrue(m.accessibility.reduceFlashing)
    }
}
