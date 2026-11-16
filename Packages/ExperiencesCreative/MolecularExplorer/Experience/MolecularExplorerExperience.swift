// MolecularExplorerExperience — feature 110 (A15-P01) T-A15-106 (FR-A15-131, FR-A15-132; clarification Q5). The
// public face of the framework `MolecularExplorerExperience`: the experience's id and the factory the one app's
// registry calls (the same parameter list as Solar System Explorer's, so the registry entry mirrors it). The selection
// travels in the host's saved session state. Since feature 113 (A15-P04) T-A15-404 the experience's storage holds two
// files of its own, the recent-molecules list `recent.json` (``RecentStore``) and the settings `settings.json`
// (``SettingsStore``), both loaded once when the presenter is made and kept outside the engine state. There is no
// motion, so Reduce Motion changes nothing, and nothing flashes.
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreUI

/// Builds Molecular Explorer as an experience of the one app.
public enum MolecularExplorerExperience {
    /// The catalog id `a15.molecular-explorer`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: MoleculeCore.experienceID)

    /// The experience registered as `id`. `storage` holds the recent-molecules list and the settings (`recent.json`,
    /// `settings.json`; the selection itself travels in the host's saved session state); `reduceMotion` and
    /// `reduceFlashing` change nothing (no motion, nothing flashes).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, storage: storage)
    }

    /// The experience with its presenter exposed (tests): `storage` holds the recent list and the settings (nil: kept
    /// in memory); `announcementSink` replaces the system's VoiceOver announcements (nil: the system's);
    /// `displayScale` turns pixels into points until the overlay reports its size (nil: the system's).
    @MainActor
    static func make(id: ExperienceID, storage: ExperienceStorage? = nil,
                     announcementSink: (any AnnouncementSink)? = nil,
                     displayScale: Double? = nil) -> ExperienceShell<MoleculePresenter> {
        ExperienceShell(id: id, presenter: MoleculePresenter(experienceID: id, announcementSink: announcementSink,
                                                             displayScale: displayScale,
                                                             recentStore: RecentStore(storage: storage),
                                                             settingsStore: SettingsStore(storage: storage)))
    }
}
