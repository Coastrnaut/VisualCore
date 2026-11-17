// LivingWallpapersExperience — feature 139 (A19-P02) T-A19-207 (FR-A19-203–207). The public face of the framework
// `LivingWallpapersExperience`: the experience's id and the factory the one app's registry calls (the same parameter
// list as Ambient Clock's, so the registry entry mirrors it). Reduce Motion stills the preview at the chosen
// animation time; nothing flashes, so Reduce Flashing changes nothing. The state travels in the host's saved session
// state (snapshot schema 1; schema 2 since feature 140, A19-P03, with the edited colours); nothing is stored in
// `storage` yet (exports go to a temporary folder only; saving and the history come in A19-P04).
import Foundation
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Living Wallpapers as an experience of the one app.
public enum LivingWallpapersExperience {
    /// The catalog id `a19.living-wallpapers`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: WallpaperCore.experienceID)

    /// The experience registered as `id`: `reduceMotion` stills the preview at the chosen animation time;
    /// `storage` and `reduceFlashing` change nothing in this phase.
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion)
    }

    /// The experience's shell with its presenter exposed (tests): the presenter gets `reduceMotion` and the export
    /// attempt `stillExport` (by default over `LivingWallpapers-Export`).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     stillExport: StillExport = StillExport()) -> ExperienceShell<WallpaperPresenter> {
        let presenter = WallpaperPresenter(reduceMotion: reduceMotion, stillExport: stillExport)
        return ExperienceShell(id: id, presenter: presenter)
    }
}
