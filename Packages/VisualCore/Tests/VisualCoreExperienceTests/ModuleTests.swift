// ModuleTests — feature 187 T-U01-002: the module links and reports its version.
import Testing
import VisualCoreExperience

@Test func experienceModuleReportsItsVersion() {
    #expect(ExperienceInfo.version == "1.0.0-rc.1")
}
