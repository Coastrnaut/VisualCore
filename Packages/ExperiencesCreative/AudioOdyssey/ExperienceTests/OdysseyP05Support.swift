// OdysseyP05Support — feature 058 (A07-P05) T-A07-504 (FR-A07-502, FR-A07-511, FR-A07-520, FR-A07-530). Shared test
// doubles and helpers of the phase-05 experience tests: a recording announcement sink, a switchable VoiceOver state, a
// granted microphone permission and silent sources (the microphone is never started), a schema-3 snapshot of any
// journey state, and opening the experience in the one app's session host at a small size (64 × 64 points by default).
import Foundation
import XCTest
@testable import AudioOdysseyExperience
import AudioOdysseyCore
import VisualCoreAudioDSP
import VisualCoreAudio
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreUI

/// Records every announcement it receives, oldest first.
@MainActor
final class P05RecordingSink: AnnouncementSink {
    /// The announced texts, oldest first.
    private(set) var announced: [String] = []

    /// Records `text`.
    func announce(_ text: String) { announced.append(text) }
}

/// A VoiceOver state a test can switch while the experience runs.
@MainActor
final class P05VoiceOver {
    /// Whether VoiceOver counts as running.
    var running: Bool

    /// A state that starts as `running`.
    init(_ running: Bool) { self.running = running }
}

/// A microphone permission that is granted and never asks.
@MainActor
final class P05GrantedPermission: MicrophonePermission {
    var state: MicrophonePermissionState { .granted }
    func request() async -> MicrophonePermissionState { .granted }
}

/// A silent source double.
@MainActor
final class P05QuietSource: AudioSource {
    var sampleRate: Double { 48_000 }
    private(set) var state: AudioSourceState = .idle

    func start(into buffer: SampleRingBuffer) throws { state = .running }
    func stop() { state = .idle }
}

@MainActor
enum P05 {
    /// The experience id `a07.audio-odyssey`.
    static var id: ExperienceID { AudioOdysseyExperience.id ?? ExperienceID(rawValue: "a07.unknown")! }

    /// Silent sources for the demo, a file and the microphone.
    static var quietSources: OdysseySourceFactory {
        OdysseySourceFactory(demo: { _ in P05QuietSource() }, file: { _ in P05QuietSource() },
                             microphone: { _ in P05QuietSource() })
    }

    /// A schema-3 snapshot of `state` (seed 7) with the digest the engine computes for it.
    static func snapshot(_ state: JourneyState) throws -> ExperienceSnapshot {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let payload = try encoder.encode(state)
        var builder = DigestBuilder(domain: id.rawValue)
        builder.add(state.digestText)
        return try ExperienceSnapshot(experience: id, schemaVersion: 3, seed: 7, stepIndex: 0,
                                      digest: builder.finish(), payload: payload)
    }

    /// Opens Audio Odyssey in `session` (seed 7, optional `snapshot`, which must be accepted) with silent sources, a
    /// granted microphone, `storage`, `sink` and `voiceOver`, lays the view out at `size` points and draws no frame.
    static func open(_ session: ExperienceSession, snapshot: ExperienceSnapshot? = nil,
                     storage: ExperienceStorage? = nil, sink: P05RecordingSink? = nil,
                     voiceOver: P05VoiceOver? = nil,
                     size: CGSize = CGSize(width: 64, height: 64)) async throws -> ExperienceShell<OdysseyPresenter> {
        let id = self.id
        let sources = quietSources
        let sink = sink ?? P05RecordingSink()
        var made: ExperienceShell<OdysseyPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 7, snapshot: snapshot,
                                            refusedSnapshotFails: snapshot != nil) {
            let shell = AudioOdysseyExperience.make(id: id, permission: P05GrantedPermission(), factory: sources,
                                                    storage: storage, announcementSink: sink,
                                                    voiceOverRunning: { voiceOver?.running ?? false })
            made = shell
            return shell
        }
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(origin: .zero, size: size)
            view.layoutIfNeeded()
        }
        return try XCTUnwrap(made)
    }

    /// Draws `count` frames back to back (1/60 s of flight each, no waiting).
    static func frames(_ session: ExperienceSession, _ count: Int) throws {
        let host = try XCTUnwrap(session.renderHost)
        for _ in 0..<count { XCTAssertTrue(host.renderOneFrame(present: false)) }
    }
}
