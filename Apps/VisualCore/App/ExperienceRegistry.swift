// ExperienceRegistry — feature 190 T-U04-011 (FR-U04-010, FR-U04-011; research R2). The one explicit list of the
// experiences the app can open: for each an id and a factory. It is empty in this feature, because no experience
// is integrated yet; an integration adds its line here and nowhere else.
import VisualCoreExperience
import VisualCoreExperienceHost

/// One registered experience: its id and the factory the session calls on the main actor.
struct ExperienceRegistration: Sendable {
    /// The id of the experience, as the catalog writes it.
    let id: ExperienceID
    /// Builds the experience. Called once per open.
    let make: @MainActor () -> any Experience
}

/// The explicit list of registered experiences.
enum ExperienceRegistry {
    /// Every registered experience, in catalog order. Empty until the first integration.
    static let all: [ExperienceRegistration] = []
}
