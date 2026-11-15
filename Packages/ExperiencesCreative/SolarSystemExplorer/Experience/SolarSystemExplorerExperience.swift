// SolarSystemExplorerExperience — feature 103 (A14-P01) T-A14-103 (FR-A14-120…122; clarifications Q4, Q5), with Reduce
// Motion by feature 105 (A14-P03) T-A14-308 (FR-A14-320), with the saved view by feature 106 (A14-P04) T-A14-408
// (FR-A14-421; clarification Q5). The public face of the framework `SolarSystemExplorerExperience`: the experience's id
// and the factory the one app's registry calls (the same parameter list as Light Maze's, so the registry entry mirrors
// it). The session (selection, date, camera, clock, tour) travels in the host's saved session state; the experience's
// storage holds one file of its own, the saved view `view.json` written by Save view and read by Restore view. The
// only motion is the eased focus flight, which Reduce Motion cuts to a single frame, and the bodies moving while
// simulated time plays; nothing flashes.
import Foundation
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreUI

/// Builds Solar System Explorer as an experience of the one app.
public enum SolarSystemExplorerExperience {
    /// The catalog id `a14.solar-system-explorer`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: SolarCore.experienceID)

    /// The experience registered as `id`. `storage` holds the saved view (`view.json`; the session itself travels in
    /// the host's saved session state); `reduceMotion` cuts the focus flight to a single frame; `reduceFlashing`
    /// changes nothing (nothing flashes).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, storage: storage)
    }

    /// The experience with its presenter exposed (tests): `reduceMotion` cuts the focus flight; `announcementSink`
    /// replaces the system's VoiceOver announcements (nil: the system's); `storage` holds the saved view (nil: kept in
    /// memory); `now` is the clock "Now" reads; `announcementClock` is the wall clock of the announcement limit (nil:
    /// `now`); `displayScale` turns pixels into points until the overlay reports its size (nil: the system's).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false,
                     announcementSink: (any AnnouncementSink)? = nil, storage: ExperienceStorage? = nil,
                     now: @escaping () -> Date = Date.init, announcementClock: (() -> Date)? = nil,
                     displayScale: Double? = nil) -> ExperienceShell<SolarPresenter> {
        ExperienceShell(id: id, presenter: SolarPresenter(experienceID: id, reduceMotion: reduceMotion,
                                                          announcementSink: announcementSink,
                                                          viewStore: ViewStore(storage: storage), now: now,
                                                          announcementClock: announcementClock,
                                                          displayScale: displayScale))
    }
}
