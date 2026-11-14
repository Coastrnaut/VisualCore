// OdysseyAnnouncementTests — feature 058 (A07-P05) T-A07-504 (FR-A07-520; SC-A07-504; story 3, scenarios 1 and 2;
// clarification 4; edge case "VoiceOver toggled during a flight"). The presenter's journey announcements through an
// injected recording sink, short runs only (frames of 1/60 s drawn back to back, so the announcement clock — the sum of
// the frame deltas — advances 1/60 s per frame with no waiting; each test well under 10 s): with VoiceOver running each
// change of world, source, applied journey and pause is announced once with its exact words; rapid changes inside the
// 1.5 s interval give at most one announcement per interval and the last state is announced when the interval passes;
// with VoiceOver off nothing is announced, and switching it on announces the next change at once. The spoken
// description keeps naming the speed, calm motion, the source and the response strength.
import Foundation
import XCTest
@testable import AudioOdysseyExperience
import AudioOdysseyCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
final class OdysseyAnnouncementTests: XCTestCase {
    /// Frames that span more than the 1.5 s interval at 1/60 s each.
    private let pastInterval = 95

    /// Opens the experience with `sink` and `voiceOver` and draws the first frame (the reference state).
    private func open(_ session: ExperienceSession, sink: P05RecordingSink,
                      voiceOver: P05VoiceOver) async throws -> ExperienceShell<OdysseyPresenter> {
        let shell = try await P05.open(session, sink: sink, voiceOver: voiceOver)
        try P05.frames(session, 1)
        XCTAssertEqual(sink.announced, [], "opening announces nothing")
        return shell
    }

    func testEachChangeIsAnnouncedOnceWithItsWordsWhileVoiceOverRuns() async throws {
        let session = ExperienceSession()
        let sink = P05RecordingSink()
        let shell = try await open(session, sink: sink, voiceOver: P05VoiceOver(true))
        var expected: [String] = []

        /// Makes a change, draws the next frame and checks that exactly `text` was announced, then lets the interval pass
        /// with no further announcement.
        func change(_ text: String, _ act: () async throws -> Void) async throws {
            try await act()
            try P05.frames(session, 1)
            expected.append(text)
            XCTAssertEqual(sink.announced, expected, "after \(text)")
            try P05.frames(session, pastInterval)
            XCTAssertEqual(sink.announced, expected, "\(text) is announced once")
        }

        try await change("Landscape") { XCTAssertTrue(shell.handle(control: "world.select", values: [1]).isAccepted) }
        try await change("Star corridor") {
            XCTAssertTrue(shell.handle(control: "world.select", values: [2]).isAccepted)
        }
        try await change("Microphone") { XCTAssertTrue(shell.handle(control: "source.microphone").isAccepted) }
        try await change("Demo signal") { XCTAssertTrue(shell.handle(control: "source.demo").isAccepted) }
        let deep = JourneyPreset.builtIns[0]
        XCTAssertEqual(deep.world, .tunnel)
        try await change("Journey: \(deep.name)") { XCTAssertEqual(shell.presenter.apply(deep), .accepted) }
        try await change("Paused") { XCTAssertTrue(shell.handle(control: "flight.pause").isAccepted) }
        try await change("Flying") { XCTAssertTrue(shell.handle(control: "flight.resume").isAccepted) }
        XCTAssertEqual(sink.announced, ["Landscape", "Star corridor", "Microphone", "Demo signal",
                                        "Journey: \(deep.name)", "Paused", "Flying"])

        // A change that is not announced (the speed): nothing new.
        XCTAssertTrue(shell.handle(control: "speed.set", values: [5]).isAccepted)
        try P05.frames(session, pastInterval)
        XCTAssertEqual(sink.announced.count, 7)

        // The description keeps the speed, calm motion, the source and the response strength.
        XCTAssertTrue(shell.handle(control: "comfort.calm", values: [1]).isAccepted)
        try P05.frames(session, 1)
        XCTAssertEqual(sink.announced.count, 7, "calm motion is described, not announced")
        let summary = shell.accessibilitySummary
        XCTAssertTrue(summary.hasPrefix("Audio Odyssey: Tunnel, 5 units per second, "), summary)
        XCTAssertTrue(summary.contains("calm motion, flying, demo signal, sound response "), summary)
        session.close()
    }

    func testRapidChangesGiveAtMostOneAnnouncementPerIntervalAndEndWithTheLastState() async throws {
        let session = ExperienceSession()
        let sink = P05RecordingSink()
        let shell = try await open(session, sink: sink, voiceOver: P05VoiceOver(true))
        var announcedAt: [Int] = []
        var frame = 0
        /// Draws one frame and records the frame number of every new announcement.
        func step() throws {
            let before = sink.announced.count
            try P05.frames(session, 1)
            frame += 1
            for _ in before..<sink.announced.count { announcedAt.append(frame) }
        }
        for world in [1, 2, 0, 2, 0] {
            XCTAssertTrue(shell.handle(control: "world.select", values: [Double(world)]).isAccepted)
            try step()
        }
        XCTAssertTrue(shell.handle(control: "flight.pause").isAccepted)
        try step()
        XCTAssertTrue(shell.handle(control: "flight.resume").isAccepted)
        try step()
        XCTAssertTrue(shell.handle(control: "world.select", values: [2]).isAccepted)
        try step()
        XCTAssertEqual(sink.announced, ["Landscape"], "the first change at once, the rest held")
        for _ in 0..<(2 * pastInterval) { try step() }
        XCTAssertEqual(sink.announced, ["Landscape", "Star corridor"], "the last state, once, after the interval")
        XCTAssertEqual(announcedAt.count, 2)
        // At least 1.5 s of frame clock (90 frames of 1/60 s) between the two.
        XCTAssertGreaterThanOrEqual(announcedAt[1] - announcedAt[0], 90)
        XCTAssertLessThanOrEqual(announcedAt[1] - announcedAt[0], 92, "announced as soon as the interval passed")
        session.close()
    }

    func testNothingIsAnnouncedWhileVoiceOverIsOffAndTheNextChangeIsOnceItRuns() async throws {
        let session = ExperienceSession()
        let sink = P05RecordingSink()
        let voiceOver = P05VoiceOver(false)
        let shell = try await open(session, sink: sink, voiceOver: voiceOver)
        XCTAssertTrue(shell.handle(control: "world.select", values: [1]).isAccepted)
        try P05.frames(session, pastInterval)
        XCTAssertTrue(shell.handle(control: "source.microphone").isAccepted)
        try P05.frames(session, pastInterval)
        XCTAssertEqual(shell.presenter.apply(JourneyPreset.builtIns[0]), .accepted)
        try P05.frames(session, pastInterval)
        XCTAssertTrue(shell.handle(control: "flight.pause").isAccepted)
        try P05.frames(session, pastInterval)
        XCTAssertEqual(sink.announced, [], "VoiceOver off: no announcement")

        voiceOver.running = true
        XCTAssertTrue(shell.handle(control: "flight.resume").isAccepted)
        try P05.frames(session, 1)
        XCTAssertEqual(sink.announced, ["Flying"], "announcements start at once with VoiceOver")
        voiceOver.running = false
        try P05.frames(session, pastInterval)
        XCTAssertTrue(shell.handle(control: "world.select", values: [2]).isAccepted)
        try P05.frames(session, pastInterval)
        XCTAssertEqual(sink.announced, ["Flying"], "and stop at once without it")
        session.close()
    }
}
