// FractalExperience — feature 193 (UA-F07) T-U07-024 (FR-U07-010, FR-U07-021; research R1, R6). The public face of the
// framework `FractalExplorerExperience`: the experience's id and the factory the one app's registry calls.
import UIKit
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Fractal Explorer as an experience of the one app.
public enum FractalExperience {
    /// The catalog id `a03.fractal-explorer`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: FractalCore.experienceID)

    /// The experience registered as `id`, with its own storage (the bookmarks) and the person's Reduce Motion choice
    /// as it is in effect now (tours then jump between stops).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool) -> any Experience {
        let scale = UITraitCollection.current.displayScale
        return ExperienceShell(id: id, presenter: FractalPresenter(experienceID: id, storage: storage,
                                                                   reduceMotion: reduceMotion,
                                                                   displayScale: scale > 0 ? scale : 2))
    }
}
