// ReducedMotionFrameTests — feature 152 (A21-P01) T-A21-108 (FR-A21-106; SC-A21-103; regression fixture of manual §9
// Phase 01). Under Reduce Motion, or at speed 0, two drawings at different frame times are byte-identical; phase 0
// and phase 1 give the same picture, so the 600 s loop has no seam.
import XCTest
import AuroraCore
import VisualCoreRendering

@MainActor
final class ReducedMotionFrameTests: XCTestCase {
    private func drawStill(_ clock: inout SkyClock, sky: SkyScene) throws -> (first: [UInt8], second: [UInt8]) {
        let scene = AuroraOffscreen.makeScene()
        let host = try AuroraOffscreen.makeHost(scene)
        defer { host.destroy() }
        let first = try AuroraOffscreen.draw(host, scene, SkyUniforms(scene: sky, phase: clock.phase, level: 0), time: 1)
        for _ in 0..<30 { clock.advance(by: 1.0 / 60) }
        XCTAssertTrue(host.renderOneFrame(present: false))
        let second = try AuroraOffscreen.draw(host, scene, SkyUniforms(scene: sky, phase: clock.phase, level: 0),
                                              time: 7.5)
        return (first, second)
    }

    func testReducedMotionFramesAreByteIdentical() throws {
        let sky = SkyPresets.polarNight.scene
        var clock = SkyClock(scene: sky, reducedMotion: true)
        clock.scrub(to: 123)
        let frames = try drawStill(&clock, sky: sky)
        XCTAssertEqual(clock.time, 123)
        XCTAssertFalse(frames.first.isEmpty)
        XCTAssertEqual(frames.first, frames.second)
    }

    func testSpeedZeroFramesAreByteIdentical() throws {
        var sky = SkyPresets.violetVeil.scene
        sky.setSpeed(0)
        var clock = SkyClock(scene: sky)
        let frames = try drawStill(&clock, sky: sky)
        XCTAssertEqual(clock.time, 0)
        XCTAssertEqual(frames.first, frames.second)
    }

    func testMovingClockChangesThePicture() throws {
        let sky = SkyPresets.polarNight.scene
        var clock = SkyClock(scene: sky)
        let frames = try drawStill(&clock, sky: sky)
        XCTAssertGreaterThan(clock.time, 0)
        XCTAssertGreaterThan(AuroraOffscreen.difference(frames.first, frames.second).max, 0, "time reaches the sky")
    }

    func testPhaseZeroAndOneGiveTheSamePicture() throws {
        let scene = AuroraOffscreen.makeScene()
        let host = try AuroraOffscreen.makeHost(scene)
        defer { host.destroy() }
        for preset in SkyPresets.all {
            let start = SkyUniforms(scene: preset.scene, phase: 0, level: 0)
            let end = SkyUniforms(scene: preset.scene, phase: 1, level: 0)
            XCTAssertEqual(try AuroraOffscreen.draw(host, scene, start), try AuroraOffscreen.draw(host, scene, end),
                           preset.id)
            XCTAssertEqual(SkyReference.render(start, width: 64, height: 48),
                           SkyReference.render(end, width: 64, height: 48), preset.id)
        }
    }
}
