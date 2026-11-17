// AuroraExperience — feature 153 (A21-P02) T-A21-203 (FR-A21-201, FR-A21-206; clarifications Q4, Q5); feature 154
// (A21-P03) T-A21-305 (FR-A21-303, FR-A21-304). The public face of the framework `AuroraExperience`: the experience's
// id and the factory the one app's registry calls (the same parameter list as Digital Zen Garden's). Reduce Motion
// holds the sky still and makes every change between skies immediate; Reduce Flashing (feature 155, FR-A21-402) turns
// the reduced-flash mode on: no twinkle, and a change between skies takes 4.0 s. The sky travels in the host's saved
// session state (snapshot schema 1: the scene, the hue shift and the limit); `storage` keeps the person's choices as
// the experience value `prefs.v1` (`SkyPreferences`), read by the presenter before the first frame.
import Foundation
import AuroraCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Aurora as an experience of the one app.
public enum AuroraExperience {
    /// The catalog id `a21.aurora`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: SkyCore.experienceID)

    /// The experience registered as `id`; `reduceMotion` holds the sky still and makes changes immediate; `storage`
    /// keeps the saved choices (`prefs.v1`); `reduceFlashing` turns the reduced-flash mode on (no twinkle, 4.0 s
    /// changes).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, storage: storage, reduceFlashing: reduceFlashing)
    }

    /// The experience's shell with its presenter exposed (tests): the presenter gets `reduceMotion`, `storage` (none:
    /// nothing is read or saved), `reduceFlashing`, the shell's port and the shell's core.
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false, storage: ExperienceStorage? = nil,
                     reduceFlashing: Bool = false) -> ExperienceShell<AuroraPresenter> {
        let presenter = AuroraPresenter(reduceMotion: reduceMotion, storage: storage, reduceFlashing: reduceFlashing)
        let shell = ExperienceShell(id: id, presenter: presenter)
        presenter.port = shell.port
        presenter.coreSource = { [weak shell] in shell?.engine.core }
        return shell
    }
}
