// AquariumRenderTests — feature 068 (A09-P01) T-A09-103 (FR-A09-120; story 1 scenarios 1 and 3; SC-A09-101,
// SC-A09-105). Digital Aquarium rendered inside the one app's session host on the simulator, short runs only (each
// test under 10 s, no wall-clock assertion): the Reef draws a non-blank, non-black frame with its declared water probe
// holding; the Kelp draws a different frame (by pixel hash and in a visible number of pixels); swimming fish change the
// frame while a paused aquarium draws the same frame; the lighting changes the frame; a failed draw reaches the session
// as a failure; and the experience's sources never create a graphics context of their own.
import Foundation
import XCTest
@testable import DigitalAquariumExperience
import DigitalAquariumCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

@MainActor
final class AquariumRenderTests: XCTestCase {
    private let size = CGSize(width: 160, height: 90)

    private func assertDrawn(_ shell: ExperienceShell<AquariumPresenter>,
                             _ frame: (rgba: [UInt8], width: Int, height: Int), _ name: String) {
        XCTAssertGreaterThan(frame.width, 0)
        XCTAssertTrue(FrameChecks.isNonBlank(frame.rgba, width: frame.width, height: frame.height), "\(name) not blank")
        XCTAssertFalse(FrameChecks.isBlack(frame.rgba, width: frame.width, height: frame.height), "\(name) not black")
        for probe in shell.frameProbes {
            XCTAssertEqual(FrameChecks.probe(probe, rgba: frame.rgba, width: frame.width, height: frame.height)?.rawValue,
                           probe.expected, "\(name) \(probe.name)")
        }
    }

    func testTheTwoHabitatsDrawNonBlankFramesThatDiffer() async throws {
        let session = ExperienceSession()
        let shell = try await AquariumTest.open(session, size: size)
        try AquariumTest.frames(session, 2)
        let reef = try AquariumTest.picture(session)
        XCTAssertFalse(shell.frameProbes.isEmpty, "the soft Reef water has a clear colour class")
        assertDrawn(shell, reef, "reef")

        XCTAssertTrue(shell.handle(control: "habitat.select", values: [1]).isAccepted)
        try AquariumTest.frames(session, 2)
        let kelp = try AquariumTest.picture(session)
        assertDrawn(shell, kelp, "kelp")
        XCTAssertNotEqual(StableHash.sha256Hex(reef.rgba), StableHash.sha256Hex(kelp.rgba))
        let differing = AquariumTest.differingPixels(reef.rgba, kelp.rgba)
        XCTAssertGreaterThan(differing, reef.width * reef.height / 10, "the water colour and the scene change visibly")
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testSwimmingChangesTheFrameAndPauseHoldsIt() async throws {
        let session = ExperienceSession()
        let shell = try await AquariumTest.open(session, size: size)
        let start = try AquariumTest.picture(session)
        try AquariumTest.frames(session, 30)
        let later = try AquariumTest.picture(session)
        XCTAssertNotEqual(StableHash.sha256Hex(start.rgba), StableHash.sha256Hex(later.rgba), "the fish swim")

        XCTAssertTrue(shell.handle(control: "motion.pause", values: [1]).isAccepted)
        let held = try AquariumTest.picture(session)
        try AquariumTest.frames(session, 10)
        let stillHeld = try AquariumTest.picture(session)
        XCTAssertEqual(StableHash.sha256Hex(held.rgba), StableHash.sha256Hex(stillHeld.rgba), "a paused frame holds")
        session.close()
    }

    func testTheLightingChangesTheFrame() async throws {
        let session = ExperienceSession()
        let shell = try await AquariumTest.open(session, size: size)
        XCTAssertTrue(shell.handle(control: "motion.pause", values: [1]).isAccepted)
        let soft = try AquariumTest.picture(session)
        XCTAssertTrue(shell.handle(control: "lighting.level", values: [2]).isAccepted)
        let bright = try AquariumTest.picture(session)
        assertDrawn(shell, bright, "bright")
        XCTAssertGreaterThan(AquariumTest.differingPixels(soft.rgba, bright.rgba), soft.width * soft.height / 2,
                             "the whole aquarium is lit brighter")
        session.close()
    }

    func testAFailedDrawReachesTheSession() async throws {
        let session = ExperienceSession()
        let shell = try await AquariumTest.open(session, size: size)
        try AquariumTest.frames(session, 1)
        shell.presenter.failNextDraw = true
        _ = session.renderHost?.renderOneFrame(present: false)
        XCTAssertEqual(session.state, .failed, "a drawing failure fails the session")
        XCTAssertNotNil(session.failure)
        XCTAssertFalse(shell.presenter.failNextDraw, "the seam clears itself")
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }

    /// The experience draws only through the `RenderContext` the host hands it: none of its sources creates a
    /// context, a display, a device or a render host, or calls GL directly.
    func testTheExperienceNeverCreatesAGraphicsContextOfItsOwn() throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Experience")
        let files = try XCTUnwrap(FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        XCTAssertGreaterThanOrEqual(files.count, 4)
        // Split so the repository's own source scanners do not read this list as a use.
        let forbidden = ["egl" + "CreateContext", "egl" + "GetDisplay", "egl" + "GetPlatformDisplay", "EAGL" + "Context",
                         "MTL" + "CreateSystemDefaultDevice", "RenderHost" + "(", "CVisualCore" + "GL", "vc" + "gl",
                         "AV" + "AudioEngine", "AV" + "AudioPlayer"]
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for word in forbidden {
                XCTAssertFalse(text.contains(word), "\(file.lastPathComponent) mentions \(word)")
            }
        }
    }
}
