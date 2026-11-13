// GenerativeArtExperience — feature 193 (UA-F07) T-U07-009, T-U07-010 (FR-U07-010, FR-U07-021; research R1, R6). The
// public face of the framework `GenerativeArtStudioExperience`: the experience's id and the factory the one app's
// registry calls. Everything else in the framework is internal.
import GenerativeArtStudioAdapterCore
import UIKit
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Generative Art Studio as an experience of the one app.
public enum GenerativeArtExperience {
    /// The catalog id `a01.generative-art-studio`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: GenerativeArtCore.experienceID)

    /// The experience registered as `id`, with its own storage and the person's accessibility choices as they are
    /// in effect now.
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        let scale = UITraitCollection.current.displayScale
        let presenter = GenerativeArtPresenter(experienceID: id, storage: storage, reduceMotion: reduceMotion,
                                               reduceFlashing: reduceFlashing, displayScale: scale > 0 ? scale : 2)
        return ExperienceShell(id: id, presenter: presenter)
    }
}
