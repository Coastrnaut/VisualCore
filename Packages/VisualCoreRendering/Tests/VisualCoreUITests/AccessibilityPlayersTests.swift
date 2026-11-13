// AccessibilityPlayersTests — feature 226, R02-F26, T-R02F26-010 and T-R02F26-013 (FR-R02F26-021, FR-R02F26-041).
import VisualCoreSimulation
import XCTest
@testable import VisualCoreUI

@MainActor
final class AccessibilityPlayersTests: XCTestCase {
    private let allKinds: [HapticKind] = [.selection, .success, .warning, .error, .impactLight, .impactMedium, .impactHeavy]

    func testRecordingHapticSinkRecordsKindsInOrder() {
        let sink = RecordingHapticSink()
        let player: any HapticSink = sink
        for kind in allKinds { player.play(kind) }
        player.play(.selection)
        XCTAssertEqual(sink.played, allKinds + [.selection])
        sink.reset()
        XCTAssertTrue(sink.played.isEmpty)
    }

    func testRecordingAnnouncementSinkRecordsTextsInOrder() {
        let sink = RecordingAnnouncementSink()
        let poster: any AnnouncementSink = sink
        poster.announce("Level 2")
        poster.announce("Move not allowed")
        poster.announce("Solved")
        XCTAssertEqual(sink.announced, ["Level 2", "Move not allowed", "Solved"])
        sink.reset()
        XCTAssertTrue(sink.announced.isEmpty)
    }

    func testSystemHapticSinkPlaysEveryKind() {
        let sink = SystemHapticSink()
        sink.prepare()
        for kind in allKinds { sink.play(kind) }
        for kind in allKinds.reversed() { sink.play(kind) }
    }

    func testSystemAnnouncementSinkPosts() {
        let sink = SystemAnnouncementSink()
        sink.announce("Level 1")
        sink.announce("")
    }
}
