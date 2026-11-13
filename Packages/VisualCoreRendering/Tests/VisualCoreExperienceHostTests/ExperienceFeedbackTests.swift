// ExperienceFeedbackTests — feature 226 (R02-F26) T-R02F26-014 (FR-R02F26-020, 021, 040 to 042; SC-R02F26-005): the
// route plays planned haptics and announcements through its sinks, honours the switch and VoiceOver's state, applies
// the rate limits, and never touches an experience's state.
import XCTest
import VisualCoreSimulation
import VisualCoreUI
@testable import VisualCoreExperienceHost

@MainActor
final class ExperienceFeedbackTests: XCTestCase {
    private var now = 0.0
    private var voiceOver = true

    private func route(_ haptics: RecordingHapticSink, _ announcements: RecordingAnnouncementSink) -> ExperienceFeedback {
        ExperienceFeedback(hapticSink: haptics, announcementSink: announcements,
                           clock: { [unowned self] in self.now }, voiceOverRunning: { [unowned self] in self.voiceOver })
    }

    func testHapticsPlayWhenOnRespectTheRateLimitAndStopWhenOff() {
        let sink = RecordingHapticSink()
        let feedback = route(sink, RecordingAnnouncementSink())
        feedback.haptic(.selection)
        now = 0.01
        feedback.haptic(.success)          // inside 0.05 s: dropped
        now = 0.1
        feedback.haptic(.error)
        feedback.hapticsEnabled = false
        now = 1
        feedback.haptic(.impactHeavy)
        XCTAssertEqual(sink.played, [.selection, .error])
    }

    func testAnnouncementsReachVoiceOverMergeBurstsAndNeedVoiceOver() {
        let sink = RecordingAnnouncementSink()
        let feedback = route(RecordingHapticSink(), sink)
        feedback.announce("Move rejected", kind: .rejection)
        now = 0.1
        feedback.announce("Level 2", kind: .level)
        now = 0.2
        feedback.announce("Level 3", kind: .level)   // merges with the pending one
        now = 0.6
        feedback.flush()
        voiceOver = false
        now = 2
        feedback.announce("Won", kind: .outcome)
        XCTAssertEqual(sink.announced, ["Move rejected", "Level 3"])
    }

    func testThePortRoutesWithoutChangingTheState() {
        let haptics = RecordingHapticSink()
        let feedback = route(haptics, RecordingAnnouncementSink())
        var handled = 0
        let port = ExperienceActionPort(accessibilityPrefix: "x") { _, _ in handled += 1; return .accepted }
        let revision = port.revision
        port.haptic(.success, route: feedback)
        XCTAssertEqual(haptics.played, [.success])
        XCTAssertEqual(handled, 0, "feedback never sends an action")
        XCTAssertEqual(port.revision, revision, "feedback never changes the state")
    }

    /// T-R02F26-022: the session flushes a held announcement on a drawn frame once the interval passed.
    func testTheSessionPostsAHeldAnnouncementOnAFrame() async throws {
        let sink = RecordingAnnouncementSink()
        let feedback = route(RecordingHapticSink(), sink)
        let session = ExperienceSession()
        session.feedback = feedback
        defer { session.close() }
        let (request, _) = sampleRequest()
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        layOut(session)
        let host = try XCTUnwrap(session.renderHost)
        feedback.announce("First", kind: .state)
        now = 0.1
        feedback.announce("Held", kind: .state)       // inside 0.5 s: held
        XCTAssertEqual(sink.announced, ["First"])
        now = 0.7
        _ = host.renderOneFrame(present: false)
        XCTAssertEqual(sink.announced, ["First", "Held"], "the frame posted the held announcement")
    }
}
