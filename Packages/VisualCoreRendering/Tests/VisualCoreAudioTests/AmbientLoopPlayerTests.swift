// AmbientLoopPlayerTests — feature 155 (A21-P04) T-A21-403 (FR-A21-405; gap G-LOOP): the ambient loop player uses the
// ambient session and needs no microphone permission, clamps its volume and ignores non-finite values, plays and
// stops, renders the recipe once, stops on an interruption, a media-services reset and a move to the background,
// stops when disabled, and refuses invalid recipes and engine failures. State is checked against an output double
// and a private notification center; one test drives the real engine without asserting on audible output. Each test
// runs well under 2 s.
import AVFAudio
import Foundation
import UIKit
import XCTest
import VisualCoreAudioDSP
@testable import VisualCoreAudio

private struct LoopOutputDoubleError: Error {}

/// An output double: counts starts and stops and records the scheduled loops and volumes.
@MainActor
private final class LoopOutputDouble: AmbientLoopOutput {
    var failNextStart = false
    var startCalls = 0
    var stopCalls = 0
    var resetCalls = 0
    var played: [(samples: [Float], volume: Float)] = []
    var volumes: [Float] = []

    func start() throws {
        startCalls += 1
        if failNextStart {
            failNextStart = false
            throw LoopOutputDoubleError()
        }
    }

    func playLooped(_ samples: [Float], volume: Float) -> Bool {
        played.append((samples, volume))
        return true
    }

    func setVolume(_ volume: Float) { volumes.append(volume) }

    func stop() { stopCalls += 1 }

    func reset() { resetCalls += 1 }
}

@MainActor
final class AmbientLoopPlayerTests: XCTestCase {
    private func pump(until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(1)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    private func makePlayer(recipe: AmbientLoopRecipe = .gentle,
                            center: NotificationCenter = NotificationCenter()) -> (AmbientLoopPlayer, LoopOutputDouble) {
        let output = LoopOutputDouble()
        return (AmbientLoopPlayer(recipe: recipe, output: output, center: center), output)
    }

    private func interruption(_ type: AVAudioSession.InterruptionType) -> [AnyHashable: Any] {
        [AVAudioSessionInterruptionTypeKey: type.rawValue]
    }

    func testPlayingUsesTheAmbientSessionAndNeedsNoMicrophonePermission() throws {
        XCTAssertEqual(AmbientLoopPlayer.sessionCategory, .ambient)
        let permissionBefore = AVAudioApplication.shared.recordPermission
        let player = AmbientLoopPlayer()
        player.volume = 0.01
        guard player.play() else {
            throw XCTSkip("the simulator's audio engine did not start; covered by the output double")
        }
        // The ambient category has no input: the engine's input node is never created, so no permission is asked.
        XCTAssertTrue(player.isPlaying)
        XCTAssertEqual(AVAudioSession.sharedInstance().category, .ambient)
        XCTAssertEqual(AVAudioApplication.shared.recordPermission, permissionBefore)
        player.stop()
        XCTAssertFalse(player.isPlaying)
    }

    func testVolumeIsClampedAndNonFiniteValuesAreIgnored() {
        let (player, output) = makePlayer()
        XCTAssertEqual(player.volume, 1)
        player.volume = 0.5
        XCTAssertEqual(player.volume, 0.5)
        player.volume = 2
        XCTAssertEqual(player.volume, 1)
        player.volume = -1
        XCTAssertEqual(player.volume, 0)
        player.volume = 0.25
        for value in [Float.nan, .infinity, -.infinity] {
            player.volume = value
            XCTAssertEqual(player.volume, 0.25, "a non-finite volume is ignored")
        }
        XCTAssertEqual(output.volumes, [0.5, 1, 0, 0.25], "only accepted volumes reach the node")
        XCTAssertTrue(player.play())
        XCTAssertEqual(output.played.last?.volume, 0.25, "the loop starts at the current volume")
        player.volume = 0.75
        XCTAssertEqual(output.volumes.last, 0.75, "a change while playing applies at once")
        XCTAssertEqual(output.played.count, 1, "a volume change never reschedules")
        XCTAssertEqual(player.renderCount, 1, "a volume change never re-renders")
    }

    func testPlayAndStopTrackTheStateAndRenderOnce() {
        let (player, output) = makePlayer()
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.renderCount, 0, "nothing is rendered before the first play")
        XCTAssertTrue(player.play())
        XCTAssertTrue(player.isPlaying)
        XCTAssertTrue(player.play(), "playing while playing is a no-op")
        XCTAssertEqual(output.played.count, 1)
        XCTAssertEqual(output.played[0].samples, AmbientLoopSynth.render(.gentle))
        player.stop()
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(output.stopCalls, 1)
        XCTAssertTrue(player.play())
        XCTAssertEqual(output.played.count, 2)
        XCTAssertEqual(player.renderCount, 1, "the recipe is rendered once and kept")
        XCTAssertEqual(output.played[1].samples, output.played[0].samples)
    }

    func testInterruptionStopsTheLoop() {
        let center = NotificationCenter()
        let (player, output) = makePlayer(center: center)
        player.play()
        center.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: interruption(.ended))
        pump { !player.isPlaying }
        XCTAssertTrue(player.isPlaying, "an interruption ending does not stop anything")
        center.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: interruption(.began))
        pump { !player.isPlaying }
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(output.stopCalls, 1)
        XCTAssertEqual(output.resetCalls, 0)
    }

    func testMediaServicesResetStopsTheLoopAndRebuildsTheEngine() {
        let center = NotificationCenter()
        let (player, output) = makePlayer(center: center)
        player.play()
        center.post(name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
        pump { output.resetCalls == 1 }
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(output.stopCalls, 1)
        XCTAssertEqual(output.resetCalls, 1, "a media-services reset rebuilds the engine on the next play")
        XCTAssertTrue(player.play())
        XCTAssertEqual(output.startCalls, 2)
    }

    func testMovingToTheBackgroundStopsTheLoop() {
        let center = NotificationCenter()
        let (player, output) = makePlayer(center: center)
        player.play()
        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        pump { !player.isPlaying }
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(output.stopCalls, 1)
    }

    func testDisablingStopsTheLoopAndDisabledPlayerPlaysNothing() {
        let (player, output) = makePlayer()
        XCTAssertTrue(player.play())
        player.isEnabled = false
        XCTAssertFalse(player.isPlaying, "disabling stops what is playing")
        XCTAssertEqual(output.stopCalls, 1)
        XCTAssertFalse(player.play())
        XCTAssertEqual(output.startCalls, 1, "a disabled player does not start the engine")
        player.isEnabled = true
        XCTAssertTrue(player.play())
        XCTAssertTrue(player.isPlaying)
    }

    func testInvalidRecipesAndEngineFailuresAreRefused() {
        var invalid = AmbientLoopRecipe.gentle
        invalid.gain = 0.5
        let (refused, refusedOutput) = makePlayer(recipe: invalid)
        XCTAssertFalse(refused.play())
        XCTAssertFalse(refused.isPlaying)
        XCTAssertEqual(refusedOutput.startCalls, 0)

        let (player, output) = makePlayer()
        output.failNextStart = true
        XCTAssertFalse(player.play())
        XCTAssertFalse(player.isPlaying)
        XCTAssertTrue(output.played.isEmpty)
        XCTAssertTrue(player.play(), "the engine is retried on the next play")
        XCTAssertTrue(player.isPlaying)
    }
}
