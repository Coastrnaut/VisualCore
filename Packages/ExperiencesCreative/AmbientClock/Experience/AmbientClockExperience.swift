// AmbientClockExperience — feature 132 T-A18-203 (FR-A18-201, FR-A18-206, FR-A18-207; G-OVERLAY/G-BUDGETS). The
// public face of the framework `AmbientClockExperience`: the experience's id and the factory the one app's registry
// calls (the same parameter list as Infinite Geometry's and Interactive Anatomy's, so the registry entry mirrors
// them). In the app the presenter reads the system clock (`SystemClock`), the current locale and zone and the default
// notification centre; Reduce Motion stills the background and makes a theme change a cut; nothing flashes, so Reduce
// Flashing changes nothing. The format and theme travel in the host's saved session state (snapshot schema 2).
//
// Feature 133 (A18-P03) T-A18-306 (FR-A18-305; G-FAVOURITES): `storage` now holds the favourites
// (`AmbientFavourites`, the file `favourites.json`, creation times from the same clock as the presenter).
//
// Feature 134 (A18-P04) T-A18-404/406 (FR-A18-407; G-AWAKE): the presenter's keep-awake writes the application's idle
// timer (`ApplicationIdleTimer`); the test factory takes any `IdleTimerPort`.
import Foundation
import VisualCoreExperience
import VisualCoreExperienceHost

/// Builds Ambient Clock as an experience of the one app.
public enum AmbientClockExperience {
    /// The catalog id `a18.ambient-clock`; nil only if the id text were malformed.
    public static let id = ExperienceID(rawValue: AmbientCore.experienceID)

    /// The experience registered as `id`: the system clock, locale, zone and notification centre; `reduceMotion`
    /// stills the background and cuts theme changes; `storage` keeps the favourites; `reduceFlashing` changes nothing
    /// (nothing flashes).
    @MainActor
    public static func make(id: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool,
                            reduceFlashing: Bool) -> any Experience {
        let clock = SystemClock()
        return make(id: id, clock: clock, reduceMotion: reduceMotion,
                    favourites: AmbientFavourites(storage: storage, clock: clock))
    }

    /// The experience's shell with its presenter exposed (tests): the presenter gets `clock`, `environment`,
    /// `center`, `reduceMotion`, `favourites` (none by default), `idleTimer` (the application's idle timer by default)
    /// and the shell's port.
    @MainActor
    static func make(id: ExperienceID, clock: any ClockSource = SystemClock(),
                     environment: @escaping AmbientPresenter.Environment = AmbientPresenter.systemEnvironment,
                     center: NotificationCenter = .default,
                     reduceMotion: Bool = false,
                     favourites: AmbientFavourites? = nil,
                     idleTimer: any IdleTimerPort = ApplicationIdleTimer()) -> ExperienceShell<AmbientPresenter> {
        let presenter = AmbientPresenter(clock: clock, environment: environment, center: center,
                                         reduceMotion: reduceMotion, idleTimer: idleTimer)
        presenter.favourites = favourites
        let shell = ExperienceShell(id: id, presenter: presenter)
        presenter.port = shell.port
        return shell
    }
}
