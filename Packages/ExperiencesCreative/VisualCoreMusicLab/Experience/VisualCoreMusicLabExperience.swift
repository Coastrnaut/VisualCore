// VisualCoreMusicLabExperience — feature 047 (A06-P01) T-A06-104 (FR-A06-120, FR-A06-121). The public face of the
// framework `VisualCoreMusicLabExperience`: the experience's id and the factory the one app's registry calls.
import VisualCoreAudio
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds VisualCore Music Lab as an experience of the one app.
public enum VisualCoreMusicLabExperience {
    /// The catalog id `a06.visualcore-music-lab`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: MusicLabCore.experienceID)

    /// The experience registered as `id`, with the system microphone permission and the VisualCoreAudio sources.
    /// It stores nothing (no audio is written; the source choice travels in the host's saved session state), and it
    /// draws a waveform without flashes or automatic motion of its own, so Reduce Motion and Reduce Flashing change
    /// nothing; the parameters keep the registry's one factory signature.
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, permission: SystemMicrophonePermission(), factory: .system)
    }

    /// The experience with an injected permission and source factory (tests use doubles for both); the presenter
    /// gets the shell's port for the file and microphone choices.
    @MainActor
    static func make(id: ExperienceID, permission: any MicrophonePermission,
                     factory: MusicLabSourceFactory = .system) -> ExperienceShell<MusicLabPresenter> {
        let presenter = MusicLabPresenter(experienceID: id, permission: permission, factory: factory)
        let shell = ExperienceShell(id: id, presenter: presenter)
        presenter.port = shell.port
        return shell
    }
}
