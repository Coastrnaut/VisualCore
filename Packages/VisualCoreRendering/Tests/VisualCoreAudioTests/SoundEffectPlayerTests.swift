// SoundEffectPlayerTests — feature 077 (A10-P03) T-A10-302 (FR-A10-301, FR-A10-302; SC-A10-302, SC-A10-303; research
// D2): the sound-effect player uses the ambient session and needs no microphone permission, a disabled player plays
// nothing, a fifth simultaneous request is dropped, `stopAll()` leaves no active voice, an interruption or a move to
// the background stops playback, invalid effects and engine failures are refused, and buffers are rendered once per
// id. Voice bookkeeping runs against an output double and a private notification center; one test drives the real
// engine without asserting on audible output. Each test runs well under 2 s.
import AVFAudio
import Foundation
import UIKit
import XCTest
import VisualCoreAudioDSP
@testable import VisualCoreAudio

private struct OutputDoubleError: Error {}

/// An output double: counts starts, records scheduled buffers and keeps their completions for the test to fire.
@MainActor
private final class OutputDouble: SoundEffectOutput {
    var failNextStart = false
    var startCalls = 0
    var stopAllCalls = 0
    var resetCalls = 0
    var scheduled: [(id: String, voice: Int, samples: [Float])] = []
    var completions: [Int: @Sendable () -> Void] = [:]

    func start() throws {
        startCalls += 1
        if failNextStart {
            failNextStart = false
            throw OutputDoubleError()
        }
    }

    func schedule(_ samples: [Float], id: String, voice: Int, completion: @escaping @Sendable () -> Void) -> Bool {
        scheduled.append((id, voice, samples))
        completions[voice] = completion
        return true
    }

    func stopAll() { stopAllCalls += 1 }

    func reset() { resetCalls += 1 }

    /// Fires the stored completion of `voice` as the audio thread would.
    func finish(voice: Int) { completions.removeValue(forKey: voice)?() }
}

private let blip = SoundEffect(waveform: .square, startFrequency: 880, endFrequency: 440, duration: 0.1)

@MainActor
final class SoundEffectPlayerTests: XCTestCase {
    private func pump(until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(1)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    private func makePlayer(center: NotificationCenter = NotificationCenter()) -> (SoundEffectPlayer, OutputDouble) {
        let output = OutputDouble()
        return (SoundEffectPlayer(voices: 4, sampleRate: 48_000, output: output, center: center), output)
    }

    private func interruption(_ type: AVAudioSession.InterruptionType) -> [AnyHashable: Any] {
        [AVAudioSessionInterruptionTypeKey: type.rawValue]
    }

    func testPlayingUsesTheAmbientSessionAndNeedsNoMicrophonePermission() {
        XCTAssertEqual(SoundEffectPlayer.sessionCategory, .ambient)
        let permissionBefore = AVAudioApplication.shared.recordPermission
        let player = SoundEffectPlayer()
        _ = player.play(blip, id: "blip")
        // The ambient category has no input: the engine's input node is never created, so no permission is asked.
        XCTAssertEqual(AVAudioSession.sharedInstance().category, .ambient)
        XCTAssertEqual(AVAudioApplication.shared.recordPermission, permissionBefore)
        player.stopAll()
        XCTAssertEqual(player.activeVoices, 0)
    }

    func testRealEngineAcceptsAtMostFourOverlappingEffects() throws {
        let player = SoundEffectPlayer()
        let long = SoundEffect(waveform: .sine, startFrequency: 300, endFrequency: 300, duration: 1, gain: 0.01)
        guard player.play(long, id: "long") else {
            throw XCTSkip("the simulator's audio engine did not start; covered by the output double")
        }
        let results = (0..<4).map { _ in player.play(long, id: "long") }
        XCTAssertEqual(results, [true, true, true, false])
        XCTAssertEqual(player.activeVoices, 4)
        player.stopAll()
        XCTAssertEqual(player.activeVoices, 0)
    }

    func testDisabledPlayerPlaysNothing() {
        let (player, output) = makePlayer()
        player.isEnabled = false
        XCTAssertFalse(player.play(blip, id: "blip"))
        XCTAssertEqual(output.startCalls, 0, "a disabled player does not even start the engine")
        XCTAssertTrue(output.scheduled.isEmpty)
        XCTAssertEqual(player.activeVoices, 0)

        player.isEnabled = true
        XCTAssertTrue(player.play(blip, id: "blip"))
        XCTAssertEqual(player.activeVoices, 1)
        player.isEnabled = false
        XCTAssertEqual(player.activeVoices, 0, "disabling stops what is playing")
        XCTAssertEqual(output.stopAllCalls, 2, "every switch to disabled stops the output (the first found nothing playing)")
    }

    func testFifthSimultaneousRequestIsDropped() {
        let (player, output) = makePlayer()
        let results = (0..<5).map { _ in player.play(blip, id: "blip") }
        XCTAssertEqual(results, [true, true, true, true, false])
        XCTAssertEqual(player.activeVoices, 4)
        XCTAssertEqual(output.scheduled.map(\.voice), [0, 1, 2, 3])
        XCTAssertEqual(output.startCalls, 4, "the engine is started lazily, only when a voice is free")

        output.finish(voice: 2)
        pump { player.activeVoices == 3 }
        XCTAssertEqual(player.activeVoices, 3)
        XCTAssertTrue(player.play(blip, id: "blip"))
        XCTAssertEqual(output.scheduled.last?.voice, 2, "the finished voice is reused")
    }

    func testStopAllLeavesNoActiveVoicesAndIgnoresStaleCompletions() {
        let (player, output) = makePlayer()
        for _ in 0..<3 { player.play(blip, id: "blip") }
        let stale = output.completions[0]
        player.stopAll()
        XCTAssertEqual(player.activeVoices, 0)
        XCTAssertEqual(output.stopAllCalls, 1)

        XCTAssertTrue(player.play(blip, id: "blip"))
        stale?()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(player.activeVoices, 1, "a completion from before stopAll does not free the new voice")
    }

    func testInterruptionStopsPlayback() {
        let center = NotificationCenter()
        let (player, output) = makePlayer(center: center)
        for _ in 0..<2 { player.play(blip, id: "blip") }
        center.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: interruption(.ended))
        pump { player.activeVoices == 0 }
        XCTAssertEqual(player.activeVoices, 2, "an interruption ending does not stop anything")

        center.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: interruption(.began))
        pump { player.activeVoices == 0 }
        XCTAssertEqual(player.activeVoices, 0)
        XCTAssertEqual(output.stopAllCalls, 1)

        center.post(name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
        pump { output.resetCalls == 1 }
        XCTAssertEqual(output.resetCalls, 1, "a media-services reset rebuilds the engine on the next play")
    }

    func testMovingToTheBackgroundStopsPlayback() {
        let center = NotificationCenter()
        let (player, output) = makePlayer(center: center)
        for _ in 0..<4 { player.play(blip, id: "blip") }
        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        pump { player.activeVoices == 0 }
        XCTAssertEqual(player.activeVoices, 0)
        XCTAssertEqual(output.stopAllCalls, 1)
    }

    func testInvalidEffectsAndEngineFailuresAreRefused() {
        let (player, output) = makePlayer()
        var invalid = blip
        invalid.gain = 2
        XCTAssertFalse(player.play(invalid, id: "loud"))
        XCTAssertEqual(output.startCalls, 0)

        output.failNextStart = true
        XCTAssertFalse(player.play(blip, id: "blip"))
        XCTAssertEqual(player.activeVoices, 0)
        XCTAssertTrue(output.scheduled.isEmpty)

        XCTAssertTrue(player.play(blip, id: "blip"), "the engine is retried on the next play")
        XCTAssertEqual(player.activeVoices, 1)
    }

    func testBuffersAreRenderedOncePerID() {
        let (player, output) = makePlayer()
        player.play(blip, id: "blip")
        player.play(blip, id: "blip")
        let other = SoundEffect(waveform: .triangle, startFrequency: 200, endFrequency: 600, duration: 0.05)
        player.play(other, id: "rise")
        XCTAssertEqual(player.cachedEffectCount, 2)
        XCTAssertEqual(output.scheduled[0].samples, SoundEffectSynth.render(blip))
        XCTAssertEqual(output.scheduled[1].samples, output.scheduled[0].samples)
        XCTAssertEqual(output.scheduled[2].samples, SoundEffectSynth.render(other))
    }
}
