// TinyWorldsExperience — feature 089 (A12-P01) T-A12-104 (FR-A12-120, FR-A12-121, FR-A12-122); feature 090 (A12-P02)
// T-A12-205 (FR-A12-212). The public face of the framework `TinyWorldsExperience`: the experience's id and the factory
// the one app's registry calls (the same parameter list as Physics Playground's, so the registry entry mirrors it). The
// world travels in the host's saved session state; the experience keeps no files of its own. `reduceMotion` makes the
// drawn view move directly instead of easing (the presenter also reads the system setting every frame); nothing
// flashes, so `reduceFlashing` changes nothing.
//
// Feature 091 (A12-P03) T-A12-303 (FR-A12-321; research D4): the experience now keeps files of its own — the four
// saved worlds `world-0.json` … `world-3.json` with their thumbnails `world-<slot>.png` of `WorldStore`, built from the
// launch's storage — and the factory hands the presenter its shell, through which an opened slot is restored. Without
// storage (tests) the saved worlds are kept in memory.
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreUI

/// Builds Tiny Worlds as an experience of the one app.
public enum TinyWorldsExperience {
    /// The catalog id `a12.tiny-worlds`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: WorldsCore.experienceID)

    /// The experience registered as `id`. `storage` holds the saved worlds (feature 091; the world itself travels in
    /// the host's saved session state); `reduceMotion` makes view changes direct; `reduceFlashing` changes nothing
    /// (nothing flashes).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion, store: WorldStore(storage: storage))
    }

    /// The experience with its presenter exposed (tests): `systemReduceMotion`, `voiceOverRunning` and
    /// `announcementSink` replace the system's answers when given; `store` keeps the saved worlds (in memory when
    /// nil); `lowPowerMode` tells whether Low Power Mode is on (nil: the system's state; feature 093). The presenter is
    /// handed the shell, through which an opened slot is restored.
    @MainActor
    static func make(id: ExperienceID, reduceMotion: Bool = false, systemReduceMotion: (@MainActor () -> Bool)? = nil,
                     voiceOverRunning: (@MainActor () -> Bool)? = nil,
                     announcementSink: (any AnnouncementSink)? = nil,
                     store: WorldStore? = nil,
                     lowPowerMode: (@MainActor () -> Bool)? = nil) -> ExperienceShell<WorldsPresenter> {
        let presenter = WorldsPresenter(experienceID: id, reduceMotion: reduceMotion,
                                        systemReduceMotion: systemReduceMotion, voiceOverRunning: voiceOverRunning,
                                        announcementSink: announcementSink, store: store ?? WorldStore(storage: nil),
                                        lowPowerMode: lowPowerMode)
        let shell = ExperienceShell(id: id, presenter: presenter)
        presenter.shell = shell
        return shell
    }
}
