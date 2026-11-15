// DigitalAquariumExperience — feature 068 (A09-P01) T-A09-103 (FR-A09-120, FR-A09-121, FR-A09-123). The public face
// of the framework `DigitalAquariumExperience`: the experience's id and the factory the one app's registry calls. The
// aquarium's state travels in the host's saved session state; the experience keeps no files of its own in this phase.
// Reduce Motion halves the plant sway, the body wave, the tail sweep and the turn bend (presentation only); there is
// nothing that flashes. Feature 071 (A09-P04): the bubbles and motes slow down and the caustics hold still under
// Reduce Motion; changes are announced through the system's VoiceOver announcements (tests inject a sink).
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreUI

/// Builds Digital Aquarium as an experience of the one app.
public enum DigitalAquariumExperience {
    /// The catalog id `a09.digital-aquarium`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: AquariumCore.experienceID)

    /// The experience registered as `id`. `storage` is unused in this phase (the state travels in the host's saved
    /// session state); `reduceMotion` halves the plant sway, the body wave, the tail sweep and the turn bend;
    /// `reduceFlashing` changes nothing (no element flashes).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion)
    }

    /// The experience with its presenter exposed (tests): `announcementSink` and `voiceOverRunning` replace the
    /// system's VoiceOver announcements and state (nil: the system's), and `causticsFragment` replaces the caustics
    /// shader (a broken source proves the fallback; nil: the real shader).
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false, announcementSink: (any AnnouncementSink)? = nil,
                     voiceOverRunning: (@MainActor () -> Bool)? = nil,
                     causticsFragment: String? = nil) -> ExperienceShell<AquariumPresenter> {
        ExperienceShell(id: id, presenter: AquariumPresenter(experienceID: id, reduceMotion: reduceMotion,
                                                             announcementSink: announcementSink,
                                                             voiceOverRunning: voiceOverRunning,
                                                             causticsFragmentOverride: causticsFragment))
    }
}
