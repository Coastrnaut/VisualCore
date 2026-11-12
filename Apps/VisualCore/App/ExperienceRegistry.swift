// ExperienceRegistry — feature 190 T-U04-011 (FR-U04-010, FR-U04-011; research R2). The one explicit list of the
// experiences the app can open: for each an id and a factory. It is empty in this feature, because no experience
// is integrated yet; an integration adds its line here and nowhere else.
import VisualCoreExperience
import VisualCoreExperienceHost

/// What the shell hands to an experience when it opens it (US5, acceptance scenario 1): the person's stored
/// accessibility choices. `.system` means "follow the device setting"; the experience combines the choice with
/// the system value. A change in the settings reaches an experience the next time it opens: the settings route
/// closes an open experience, so no open experience holds an old value.
struct ExperienceLaunch: Sendable, Equatable {
    /// The stored reduce-motion choice.
    var reduceMotion: AccessibilityChoice = .system
    /// The stored reduce-flashing choice.
    var reduceFlashing: AccessibilityChoice = .system
}

/// One registered experience: its id and the factory the session calls on the main actor.
struct ExperienceRegistration: Sendable {
    /// The id of the experience, as the catalog writes it.
    let id: ExperienceID
    /// Builds the experience with what the shell hands over. Called once per open.
    let make: @MainActor (ExperienceLaunch) -> any Experience
}

/// The explicit list of registered experiences.
enum ExperienceRegistry {
    /// Every registered experience, in catalog order. Empty until the first integration.
    static let all: [ExperienceRegistration] = []
}
