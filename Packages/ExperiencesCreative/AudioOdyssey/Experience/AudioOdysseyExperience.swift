// AudioOdysseyExperience — feature 054 (A07-P01) T-A07-104 (FR-A07-120, FR-A07-121). The public face of the framework
// `AudioOdysseyExperience`: the experience's id and the factory the one app's registry calls.
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Audio Odyssey as an experience of the one app.
public enum AudioOdysseyExperience {
    /// The catalog id `a07.audio-odyssey`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: OdysseyCore.experienceID)

    /// The experience registered as `id`. It stores nothing of its own (the journey travels in the host's saved
    /// session state), so `storage` is unused. Reduce Motion selects the reduced comfort limits (lower speed, no sway);
    /// nothing flashes, so Reduce Flashing changes nothing.
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion)
    }

    /// The experience with its presenter exposed (tests); the presenter gets the shell's port for the Reduce Motion
    /// mirror.
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false) -> ExperienceShell<OdysseyPresenter> {
        let presenter = OdysseyPresenter(experienceID: id, reduceMotion: reduceMotion)
        let shell = ExperienceShell(id: id, presenter: presenter)
        presenter.port = shell.port
        return shell
    }
}
