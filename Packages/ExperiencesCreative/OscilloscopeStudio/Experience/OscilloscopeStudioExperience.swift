// OscilloscopeStudioExperience — feature 061 (A08-P01) T-A08-105 (FR-A08-110, FR-A08-120, FR-A08-121). The public face
// of the framework `OscilloscopeStudioExperience`: the experience's id and the factory the one app's registry calls.
// The factory hands the presenter the system microphone permission and the VisualCoreAudio sources (tests inject a
// permission and a source factory), the shell's port for the source choices and the shell's lifecycle state, so the
// presenter stops its source while the experience is suspended. The scope state travels in the host's saved session
// state; no audio is ever stored, and the static trace has nothing that Reduce Motion or Reduce Flashing would change.
// Feature 064 (A08-P04) T-A08-404 (FR-A08-410): the factory hands the presenter the experience's storage, where its
// `ScopePresetStore` keeps the user presets (one small settings file each, `scope-<uuid>.json`; never audio).
import VisualCoreAudio
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreUI

/// Builds Oscilloscope Studio as an experience of the one app.
public enum OscilloscopeStudioExperience {
    /// The catalog id `a08.oscilloscope-studio`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: ScopeCore.experienceID)

    /// The experience registered as `id`, with the system microphone permission and the VisualCoreAudio sources.
    /// `storage` holds the user presets (feature 064); `reduceMotion` and `reduceFlashing` change nothing in the static
    /// trace.
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, permission: SystemMicrophonePermission(), factory: .system, storage: storage,
             reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The experience with its presenter exposed (tests) and an injected permission and source factory (nil
    /// permission: the system's); the presenter gets the shell's port and lifecycle state. With `storage` the presenter
    /// keeps the user presets there; without it (nil, some tests) only the built-in presets are listed. Tests inject an
    /// announcement sink and the VoiceOver state (feature 065); nil means the system's.
    @MainActor
    static func make(id: ExperienceID, permission: (any MicrophonePermission)? = nil,
                     factory: ScopeSourceFactory = .system, storage: ExperienceStorage? = nil,
                     reduceMotion: Bool = false, reduceFlashing: Bool = false,
                     announcementSink: (any AnnouncementSink)? = nil,
                     voiceOverRunning: (@MainActor () -> Bool)? = nil) -> ExperienceShell<ScopePresenter> {
        let presenter = ScopePresenter(experienceID: id, permission: permission ?? SystemMicrophonePermission(),
                                       factory: factory, storage: storage, announcementSink: announcementSink,
                                       voiceOverRunning: voiceOverRunning)
        let shell = ExperienceShell(id: id, presenter: presenter)
        presenter.port = shell.port
        presenter.lifecycle = { [weak shell] in shell?.state }
        return shell
    }
}
