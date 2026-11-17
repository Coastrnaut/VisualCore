// AmbientClockExperience — feature 132 T-A18-203 (FR-A18-201, FR-A18-206, FR-A18-207; G-OVERLAY/G-BUDGETS). The
// public face of the framework `AmbientClockExperience`: the experience's id and the factory the one app's registry
// calls (the same parameter list as Infinite Geometry's and Interactive Anatomy's, so the registry entry mirrors
// them). In the app the presenter reads the system clock (`SystemClock`), the current locale and zone and the default
// notification centre; Reduce Motion stills the background; nothing flashes, so Reduce Flashing changes nothing. The
// experience keeps no file of its own in this phase: its format and theme travel in the host's saved session state
// (snapshot schema 1), so `storage` is not used.
import Foundation
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Ambient Clock as an experience of the one app.
public enum AmbientClockExperience {
    /// The catalog id `a18.ambient-clock`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: AmbientCore.experienceID)

    /// The experience registered as `id`: the system clock, locale, zone and notification centre; `reduceMotion`
    /// stills the background; `storage` and `reduceFlashing` change nothing (no file is kept, nothing flashes).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        make(id: id, reduceMotion: reduceMotion)
    }

    /// The experience's shell with its presenter exposed (tests): the presenter gets `clock`, `environment`,
    /// `center`, `reduceMotion` and the shell's port.
    @MainActor
    static func make(id: ExperienceID, clock: any ClockSource = SystemClock(),
                     environment: @escaping AmbientPresenter.Environment = AmbientPresenter.systemEnvironment,
                     center: NotificationCenter = .default,
                     reduceMotion: Bool = false) -> ExperienceShell<AmbientPresenter> {
        let presenter = AmbientPresenter(clock: clock, environment: environment, center: center,
                                         reduceMotion: reduceMotion)
        let shell = ExperienceShell(id: id, presenter: presenter)
        presenter.port = shell.port
        return shell
    }
}
