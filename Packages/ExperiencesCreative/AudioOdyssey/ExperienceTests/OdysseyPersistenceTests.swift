// OdysseyPersistenceTests — feature 058 (A07-P05) T-A07-504 (FR-A07-530; SC-A07-505; story 4, scenario 1;
// clarification 5; the phase MVP gate). Saved journeys and the journey under way survive closing the experience, short
// runs only (frames of 1/60 s drawn back to back, each test well under 10 s): a journey saved through the presenter's
// store in a temporary storage, and the session snapshot taken (encoded and decoded as the host keeps it), come back
// when a new session opens with the same storage and that snapshot: the journey list holds the saved journey with its
// fields, and the world, distance (within 1e-9), speed target, mappings and source are restored, the source playing.
import Foundation
import XCTest
@testable import AudioOdysseyExperience
import AudioOdysseyCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
final class OdysseyPersistenceTests: XCTestCase {
    private var root: URL!
    private var defaults: UserDefaults!
    private var suite = ""

    override func setUpWithError() throws {
        suite = "dev.visualcore.a07-p05.persistence.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suite)
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    private var storage: ExperienceStorage {
        ExperienceStorage(id: P05.id, root: root, defaults: defaults)
    }

    func testSavedJourneysAndTheJourneyUnderWayAreRestoredAfterClosingAndReopening() async throws {
        // First session: a journey of its own, saved, and flown a little further.
        let first = ExperienceSession()
        let shell = try await P05.open(first, storage: storage)
        try P05.frames(first, 1)
        XCTAssertTrue(shell.handle(control: "world.select", values: [2]).isAccepted)
        XCTAssertTrue(shell.handle(control: "speed.set", values: [5.5]).isAccepted)
        XCTAssertTrue(shell.handle(control: "mapping.set",
                                   values: [0, Double(EnvelopeChannel.high.rawValue),
                                            Double(Sensitivity.high.rawValue)]).isAccepted)
        XCTAssertTrue(shell.handle(control: "source.microphone").isAccepted)
        try P05.frames(first, 60)
        let saved = try XCTUnwrap(shell.presenter.saveCurrentPreset(named: "Evening run"))
        XCTAssertEqual(saved.world, .starCorridor)
        try P05.frames(first, 30)
        let snapshot = try ExperienceSnapshot(data: try shell.snapshot().encoded())
        let before = try XCTUnwrap(shell.engine.core).state
        XCTAssertGreaterThan(before.distance, 0, "the journey flew")
        XCTAssertEqual(before.source, .microphone)
        first.close()

        // Second session with the same storage and the snapshot.
        let second = ExperienceSession()
        let reopened = try await P05.open(second, snapshot: snapshot, storage: storage)
        let restored = try XCTUnwrap(reopened.engine.core).state
        XCTAssertEqual(restored.world, before.world)
        XCTAssertEqual(restored.distance, before.distance, accuracy: 1e-9)
        XCTAssertEqual(restored.speedTarget, before.speedTarget)
        XCTAssertEqual(restored.speedTarget, 5.5)
        XCTAssertEqual(restored.mappings, before.mappings)
        XCTAssertEqual(restored.mapping(for: .starCorridor).primary,
                       ChannelMapping(channel: .high, sensitivity: .high))
        XCTAssertEqual(restored.source, .microphone)
        XCTAssertEqual(restored, before, "the whole journey")
        XCTAssertEqual(try reopened.engine.digest(), snapshot.digest)

        try P05.frames(second, 1)
        let presenter = reopened.presenter
        let entry = try XCTUnwrap(presenter.presetEntries.first { $0.id == saved.id }, "the saved journey is listed")
        XCTAssertEqual(entry.name, "Evening run")
        XCTAssertFalse(entry.isBuiltIn)
        XCTAssertEqual(entry.world, saved.world)
        XCTAssertEqual(entry.mappings, saved.mappings)
        XCTAssertEqual(entry.speedTarget, saved.speedTarget)
        XCTAssertEqual(entry.easing, saved.easing)
        XCTAssertEqual(entry.calmMotion, saved.calmMotion)
        XCTAssertEqual(presenter.presetEntries.count, JourneyPreset.builtIns.count + 1)
        XCTAssertEqual(presenter.mirror.sourceName, "Microphone")
        XCTAssertTrue(presenter.activeSource is P05QuietSource, "the restored source plays")
        XCTAssertEqual(presenter.lastWorld, .starCorridor)

        // The restored journey applies the saved one again and continues.
        XCTAssertEqual(presenter.apply(entry), .accepted)
        try P05.frames(second, 10)
        XCTAssertGreaterThan(try XCTUnwrap(reopened.engine.core).state.distance, before.distance)
        second.close()
    }
}
