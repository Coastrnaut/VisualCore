// ScopeRenderTests — feature 061 (A08-P01) T-A08-105 (FR-A08-110, FR-A08-121; SC-A08-105). Oscilloscope Studio
// rendered inside the one app's session host on the simulator, short runs only (each test under 10 s, no wall-clock
// assertion): the triggered sine draws a non-blank frame on the dark background with its declared probe holding; the
// square draws a different frame (by pixel hash and in a visible number of pixels); a failed draw reaches the session as
// a failure; and the experience's sources never create a graphics context of their own.
// Feature 062 (A08-P02) T-A08-206 (FR-A08-210, FR-A08-211): the XY view of the stereo test signal draws a non-blank
// frame that differs from the waveform frame (pixel hash and a visible number of pixels).
import Foundation
import XCTest
@testable import OscilloscopeStudioExperience
import OscilloscopeStudioCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

@MainActor
final class ScopeRenderTests: XCTestCase {
    private let size = CGSize(width: 160, height: 120)

    func testFramesAreNonBlankAndTheSineAndTheSquareDiffer() async throws {
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session, size: size)
        try ScopeTest.frames(session, 3)
        XCTAssertTrue(try XCTUnwrap(shell.presenter.lastWindow).triggered)
        let sine = try ScopeTest.picture(session)
        XCTAssertGreaterThan(sine.width, 0)
        XCTAssertTrue(FrameChecks.isNonBlank(sine.rgba, width: sine.width, height: sine.height), "the sine is not blank")
        XCTAssertFalse(FrameChecks.isBlack(sine.rgba, width: sine.width, height: sine.height), "the sine is not black")
        XCTAssertFalse(shell.frameProbes.isEmpty)
        for probe in shell.frameProbes {
            XCTAssertEqual(FrameChecks.probe(probe, rgba: sine.rgba, width: sine.width, height: sine.height)?.rawValue,
                           probe.expected, "sine \(probe.name)")
        }

        XCTAssertTrue(shell.handle(control: "signal.waveform", values: [1]).isAccepted)
        try ScopeTest.frames(session, 3)
        XCTAssertTrue(try XCTUnwrap(shell.presenter.lastWindow).triggered)
        let square = try ScopeTest.picture(session)
        XCTAssertTrue(FrameChecks.isNonBlank(square.rgba, width: square.width, height: square.height),
                      "the square is not blank")
        XCTAssertNotEqual(StableHash.sha256Hex(sine.rgba), StableHash.sha256Hex(square.rgba))
        let differing = ScopeTest.differingPixels(sine.rgba, square.rgba)
        XCTAssertGreaterThan(differing, sine.width * sine.height / 100, "the traces differ visibly")
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testTheXYFrameIsNonBlankAndDiffersFromTheWaveformFrame() async throws {
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session, size: size)
        try ScopeTest.frames(session, 3)
        let waveform = try ScopeTest.picture(session)
        XCTAssertTrue(FrameChecks.isNonBlank(waveform.rgba, width: waveform.width, height: waveform.height),
                      "the waveform is not blank")
        XCTAssertFalse(shell.presenter.lastShowsXY)

        XCTAssertTrue(shell.handle(control: "display.select", values: [1]).isAccepted)
        try ScopeTest.frames(session, 3)
        let xy = try ScopeTest.picture(session)
        XCTAssertTrue(shell.presenter.lastShowsXY)
        XCTAssertTrue(FrameChecks.isNonBlank(xy.rgba, width: xy.width, height: xy.height), "the XY view is not blank")
        XCTAssertFalse(FrameChecks.isBlack(xy.rgba, width: xy.width, height: xy.height), "the XY view is not black")
        for probe in shell.frameProbes {
            XCTAssertEqual(FrameChecks.probe(probe, rgba: xy.rgba, width: xy.width, height: xy.height)?.rawValue,
                           probe.expected, "XY \(probe.name)")
        }
        XCTAssertNotEqual(StableHash.sha256Hex(waveform.rgba), StableHash.sha256Hex(xy.rgba))
        let differing = ScopeTest.differingPixels(waveform.rgba, xy.rgba)
        XCTAssertGreaterThan(differing, xy.width * xy.height / 100, "the views differ visibly")
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testAFailedDrawReachesTheSession() async throws {
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session, size: size)
        try ScopeTest.frames(session, 1)
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
                         "MTL" + "CreateSystemDefaultDevice", "RenderHost" + "(", "CVisualCore" + "GL", "vc" + "gl"]
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for word in forbidden {
                XCTAssertFalse(text.contains(word), "\(file.lastPathComponent) mentions \(word)")
            }
        }
    }
}
