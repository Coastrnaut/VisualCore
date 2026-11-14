// AudioOdysseyExperience — feature 054 (A07-P01) T-A07-104 (FR-A07-120, FR-A07-121). The public face of the framework
// `AudioOdysseyExperience`: the experience's id and the factory the one app's registry calls.
// Feature 055 (A07-P02) T-A07-205 (FR-A07-211, FR-A07-220): the factory hands the presenter the system microphone
// permission, the VisualCoreAudio sources and Reduce Flashing; tests inject a permission and a source factory.
import VisualCoreAudio
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Audio Odyssey as an experience of the one app.
public enum AudioOdysseyExperience {
    /// The catalog id `a07.audio-odyssey`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: OdysseyCore.experienceID)

    /// The experience registered as `id`, with the system microphone permission and the VisualCoreAudio sources. It
    /// stores nothing of its own (the journey and the chosen source travel in the host's saved session state; no audio
    /// is ever stored), so `storage` is unused. Reduce Motion selects the reduced comfort limits (lower speed, no
    /// sway) and halves the tunnel's breathing; Reduce Flashing halves the range and the step of its brightness.
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, permission: SystemMicrophonePermission(), factory: .system, reduceMotion: reduceMotion,
             reduceFlashing: reduceFlashing)
    }

    /// The experience with its presenter exposed (tests) and an injected permission and source factory (nil
    /// permission: the system's); the presenter gets the shell's port for the Reduce Motion mirror and the file and
    /// microphone choices.
    @MainActor
    static func make(id: ExperienceID, permission: (any MicrophonePermission)? = nil,
                     factory: OdysseySourceFactory = .system, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) -> ExperienceShell<OdysseyPresenter> {
        let presenter = OdysseyPresenter(experienceID: id, permission: permission ?? SystemMicrophonePermission(),
                                         factory: factory, reduceMotion: reduceMotion,
                                         reduceFlashing: reduceFlashing)
        let shell = ExperienceShell(id: id, presenter: presenter)
        presenter.port = shell.port
        return shell
    }
}
