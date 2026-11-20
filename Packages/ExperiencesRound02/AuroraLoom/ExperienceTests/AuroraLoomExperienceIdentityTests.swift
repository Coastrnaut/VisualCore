// AuroraLoomExperienceIdentityTests — feature 303 (R02-G01-03) T-R02G0103-008 (FR-R02G0103-008). The experience's id is
// the catalog id, and the factory builds a shell around the presenter. iOS only, as the target.
#if os(iOS)
import AuroraLoomCore
@testable import AuroraLoomExperience
import Testing
import VisualCoreExperience

@MainActor
@Suite struct AuroraLoomExperienceIdentityTests {
    @Test func theIdIsTheCatalogId() {
        #expect(AuroraLoomExperience.id?.rawValue == "r02-g01.aurora-loom")
        #expect(AuroraLoomExperienceCore.experienceID == "r02-g01.aurora-loom")
    }
}
#endif
