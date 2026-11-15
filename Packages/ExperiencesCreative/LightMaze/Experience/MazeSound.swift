// MazeSound — feature 099 (A13-P04) T-A13-407 (FR-A13-420, FR-A13-421; clarification Q3; research D4; contract
// "Success cue"). Where Light Maze's one sound goes: the success sweep, played once per solve. The presenter talks to a
// `MazeSoundSink`; the default `MazeSoundPlayer` hands the sweep to VisualCore's `SoundEffectPlayer` (ambient session,
// so the silent switch mutes it and other audio keeps playing), created on the first play; tests pass a recording sink.
// The sweep is made in code from `SuccessCue`'s constants (sine 660 → 990 Hz, 0.25 s, attack 0.01 s, release 0.1 s,
// gain 0.3, no noise); there are no sound files.
import LightMazeCore
import VisualCoreAudio
import VisualCoreAudioDSP

/// Where the presenter's sounds go.
@MainActor
protocol MazeSoundSink: AnyObject {
    /// Plays the success sweep now.
    func playSuccess()
    /// Stops every sound that is playing (suspension).
    func stopAll()
}

/// The default sink: VisualCore's `SoundEffectPlayer`, created on the first play.
@MainActor
final class MazeSoundPlayer: MazeSoundSink {
    /// The id the success sweep is played under.
    nonisolated static let successID = "a13.success"

    private var player: SoundEffectPlayer?

    /// The success sweep as a VisualCore sound effect (sine 660 → 990 Hz, 0.25 s, gain 0.3).
    nonisolated static var successEffect: SoundEffect {
        SoundEffect(waveform: .sine, startFrequency: SuccessCue.soundStartFrequency,
                    endFrequency: SuccessCue.soundEndFrequency, duration: SuccessCue.soundDuration,
                    attack: SuccessCue.soundAttack, release: SuccessCue.soundRelease, noise: 0,
                    gain: SuccessCue.soundGain)
    }

    func playSuccess() {
        let player = self.player ?? SoundEffectPlayer()
        self.player = player
        _ = player.play(Self.successEffect, id: Self.successID)
    }

    func stopAll() {
        player?.stopAll()
    }
}
