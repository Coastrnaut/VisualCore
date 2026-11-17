// AuroraExperience — feature 153 (A21-P02) T-A21-203 (FR-A21-201, FR-A21-206; clarifications Q4, Q5). The public face
// of the framework `AuroraExperience`: the experience's id and the factory the one app's registry calls (the same
// parameter list as Digital Zen Garden's). Reduce Motion holds the sky still and makes every change between skies
// immediate; nothing flashes, so Reduce Flashing changes nothing. The sky travels in the host's saved session state
// (snapshot schema 1: the scene, the hue shift and the limit); `storage` is not used in this phase (saved preferences
// come in A21-P03).
import Foundation
import AuroraCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Aurora as an experience of the one app.
public enum AuroraExperience {
    /// The catalog id `a21.aurora`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: SkyCore.experienceID)

    /// The experience registered as `id`; `reduceMotion` holds the sky still and makes changes immediate;
    /// `storage` and `reduceFlashing` change nothing in this phase (nothing flashes).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion)
    }

    /// The experience's shell with its presenter exposed (tests): the presenter gets `reduceMotion` and the shell's
    /// port.
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false) -> ExperienceShell<AuroraPresenter> {
        let presenter = AuroraPresenter(reduceMotion: reduceMotion)
        let shell = ExperienceShell(id: id, presenter: presenter)
        presenter.port = shell.port
        return shell
    }
}
