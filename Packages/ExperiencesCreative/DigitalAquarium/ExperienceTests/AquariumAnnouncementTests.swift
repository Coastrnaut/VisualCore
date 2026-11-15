// AquariumAnnouncementTests — feature 071 (A09-P04) T-A09-405 (FR-A09-421; story 3 scenarios 2–4; SC-A09-405). The
// presenter's announcements inside the one app's session host, with a recording sink and an injected VoiceOver state
// (VoiceOver itself is never driven): a feed announces "Food dropped" once while VoiceOver runs; nothing is announced
// with VoiceOver off; the first frame after opening only sets the reference; two changes inside the 3 s interval give
// one announcement, and the later change follows once the interval has passed. Frames advance the host by 1/60 s, so
// the interval is measured in frames, not wall-clock time.
import Foundation
import XCTest
@testable import DigitalAquariumExperience
import DigitalAquariumCore
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
final class AquariumAnnouncementTests: XCTestCase {
    /// Opens the aquarium with `sink` and VoiceOver reported as `voiceOver`.
    private func open(_ session: ExperienceSession, sink: AquariumRecordingSink,
                      voiceOver: Bool) async throws -> ExperienceShell<AquariumPresenter> {
        try await AquariumTest.open(session, announcementSink: sink, voiceOverRunning: { voiceOver })
    }

    func testTheFirstFrameAnnouncesNothing() async throws {
        let session = ExperienceSession()
        let sink = AquariumRecordingSink()
        let shell = try await open(session, sink: sink, voiceOver: true)
        try AquariumTest.frames(session, 5)
        XCTAssertEqual(sink.texts, [], "opening sets the reference state only")
        XCTAssertNotNil(shell.presenter.announcedState)
        session.close()
    }

    func testFeedingAnnouncesFoodDroppedOnceWithVoiceOver() async throws {
        let session = ExperienceSession()
        let sink = AquariumRecordingSink()
        let shell = try await open(session, sink: sink, voiceOver: true)
        XCTAssertTrue(shell.handle(control: "food.drop", values: [0.5, 0.8]).isAccepted)
        try AquariumTest.frames(session, 1)
        XCTAssertEqual(sink.texts, ["Food dropped"])
        try AquariumTest.frames(session, 30)
        XCTAssertEqual(sink.texts, ["Food dropped"], "one feed, one announcement (sinking pellets are silent)")
        session.close()
    }

    func testNothingIsAnnouncedWithVoiceOverOff() async throws {
        let session = ExperienceSession()
        let sink = AquariumRecordingSink()
        let shell = try await open(session, sink: sink, voiceOver: false)
        XCTAssertTrue(shell.handle(control: "food.drop", values: [0.5, 0.8]).isAccepted)
        try AquariumTest.frames(session, 2)
        XCTAssertTrue(shell.handle(control: "habitat.select", values: [1]).isAccepted)
        try AquariumTest.frames(session, 200)
        XCTAssertEqual(sink.texts, [])
        session.close()
    }

    func testTwoChangesWithinTheIntervalGiveOneAnnouncementThenTheLatest() async throws {
        let session = ExperienceSession()
        let sink = AquariumRecordingSink()
        let shell = try await open(session, sink: sink, voiceOver: true)
        XCTAssertTrue(shell.handle(control: "food.drop", values: [0.5, 0.8]).isAccepted)
        try AquariumTest.frames(session, 1)
        XCTAssertTrue(shell.handle(control: "decor.remove", values: [0]).isAccepted)
        try AquariumTest.frames(session, 1)
        XCTAssertTrue(shell.handle(control: "motion.pause", values: [1]).isAccepted)
        try AquariumTest.frames(session, 60)
        XCTAssertEqual(sink.texts, ["Food dropped"], "at most one announcement inside the 3 s interval")
        // 3 s at 60 frames per second (plus a margin for the summed frame deltas): the latest change follows.
        try AquariumTest.frames(session, 130)
        XCTAssertEqual(sink.texts, ["Food dropped", "Paused"], "the latest held change wins after the interval")
        try AquariumTest.frames(session, 200)
        XCTAssertEqual(sink.texts.count, 2, "nothing more without a change")
        session.close()
    }
}
