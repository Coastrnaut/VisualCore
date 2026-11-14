// AudioOdysseyExperience — feature 054 (A07-P01) T-A07-104 (FR-A07-120, FR-A07-121). The public face of the framework
// `AudioOdysseyExperience`: the experience's id and the factory the one app's registry calls.
// Feature 055 (A07-P02) T-A07-205 (FR-A07-211, FR-A07-220): the factory hands the presenter the system microphone
// permission, the VisualCoreAudio sources and Reduce Flashing; tests inject a permission and a source factory.
// Feature 057 (A07-P04) T-A07-403 (FR-A07-401): the factory hands the presenter the experience's storage, where the
// user journeys are kept (one small file each; tests may pass none, and then only the built-ins are offered).
// Feature 058 (A07-P05) T-A07-504 (FR-A07-520): the test factory passes an announcement sink and a VoiceOver state
// (nil: the system's VoiceOver announcements and `UIAccessibility.isVoiceOverRunning`).
import VisualCoreAudio
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreUI

/// Builds Audio Odyssey as an experience of the one app.
public enum AudioOdysseyExperience {
    /// The catalog id `a07.audio-odyssey`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: OdysseyCore.experienceID)

    /// The experience registered as `id`, with the system microphone permission and the VisualCoreAudio sources. It
    /// stores only the user journeys in `storage` (feature 057: one small file each, never any audio; the current
    /// journey and the chosen source travel in the host's saved session state). Reduce Motion selects the reduced
    /// comfort limits (lower speed, no sway) and halves the tunnel's breathing; Reduce Flashing halves the range and
    /// the step of its brightness.
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, permission: SystemMicrophonePermission(), factory: .system, reduceMotion: reduceMotion,
             reduceFlashing: reduceFlashing, storage: storage)
    }

    /// The experience with its presenter exposed (tests) and an injected permission and source factory (nil
    /// permission: the system's); the presenter gets the shell's port for the Reduce Motion mirror and the file and
    /// microphone choices. With `storage` the presenter keeps the user journeys there; without it (nil, some tests)
    /// only the built-in journeys are offered. `announcementSink` and `voiceOverRunning` (feature 058) receive and
    /// gate the journey announcements; nil uses the system's VoiceOver announcements and VoiceOver state.
    @MainActor
    static func make(id: ExperienceID, permission: (any MicrophonePermission)? = nil,
                     factory: OdysseySourceFactory = .system, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false, storage: ExperienceStorage? = nil,
                     announcementSink: (any AnnouncementSink)? = nil,
                     voiceOverRunning: (@MainActor () -> Bool)? = nil) -> ExperienceShell<OdysseyPresenter> {
        let presenter = OdysseyPresenter(experienceID: id, permission: permission ?? SystemMicrophonePermission(),
                                         factory: factory, reduceMotion: reduceMotion,
                                         reduceFlashing: reduceFlashing, storage: storage,
                                         announcementSink: announcementSink, voiceOverRunning: voiceOverRunning)
        let shell = ExperienceShell(id: id, presenter: presenter)
        presenter.port = shell.port
        return shell
    }
}
