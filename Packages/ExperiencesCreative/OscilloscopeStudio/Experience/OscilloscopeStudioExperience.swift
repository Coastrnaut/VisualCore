// OscilloscopeStudioExperience — feature 061 (A08-P01) T-A08-105 (FR-A08-110, FR-A08-120, FR-A08-121). The public face
// of the framework `OscilloscopeStudioExperience`: the experience's id and the factory the one app's registry calls.
// The factory hands the presenter the system microphone permission and the VisualCoreAudio sources (tests inject a
// permission and a source factory), the shell's port for the source choices and the shell's lifecycle state, so the
// presenter stops its source while the experience is suspended. Oscilloscope Studio stores nothing of its own in this
// phase (the scope state travels in the host's saved session state; no audio is ever stored), and its static trace has
// nothing that Reduce Motion or Reduce Flashing would change.
import VisualCoreAudio
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreUI

/// Builds Oscilloscope Studio as an experience of the one app.
public enum OscilloscopeStudioExperience {
    /// The catalog id `a08.oscilloscope-studio`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: ScopeCore.experienceID)

    /// The experience registered as `id`, with the system microphone permission and the VisualCoreAudio sources.
    /// `storage` is unused in this phase (nothing is stored); `reduceMotion` and `reduceFlashing` change nothing in the
    /// static trace.
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, permission: SystemMicrophonePermission(), factory: .system, storage: storage,
             reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience with its presenter exposed (tests) and an injected permission and source factory (nil
    /// permission: the system's); the presenter gets the shell's port and lifecycle state.
    @MainActor
    static func make(id: ExperienceID, permission: (any MicrophonePermission)? = nil,
                     factory: ScopeSourceFactory = .system, storage: ExperienceStorage? = nil,
                     reduceMotion: Bool = false, reduceFlashing: Bool = false) -> ExperienceShell<ScopePresenter> {
        let presenter = ScopePresenter(experienceID: id, permission: permission ?? SystemMicrophonePermission(),
                                       factory: factory)
        let shell = ExperienceShell(id: id, presenter: presenter)
        presenter.port = shell.port
        presenter.lifecycle = { [weak shell] in shell?.state }
        return shell
    }
}
