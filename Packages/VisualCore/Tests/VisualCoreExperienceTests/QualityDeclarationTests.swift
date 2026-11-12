// QualityDeclarationTests — feature 192 T-U06-014 (UA-F06; FR-U06-004, FR-U06-005; SC-U06-001): an experience's
// quality profile. A core that declares none gets uniform levels for its tiers; the sample core declares three
// named levels with falling budgets; the conformance run checks that the profile and the tier count agree.
import Foundation
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreTestSupport

/// A core that declares two tiers and no profile.
private struct PlainCore: ExperienceCore, Codable, Equatable {
    var value = 0
    static var migrations: MigrationChain { MigrationChain(currentVersion: 1) }
    static var controls: [ExperienceControl] { [] }
    static var qualityTiers: Int { 2 }
    static func prepare(seed: UInt64) async throws -> PlainCore { PlainCore(value: Int(seed % 7)) }
    mutating func update(step: Int) { value = (value + 1) % 1_000 }
    mutating func apply(_ action: ExperienceAction) -> ActionResult { .rejected(.unknownControl(action.control)) }
    mutating func reset() { value = 0 }
    func writeDigest(into builder: inout DigestBuilder) throws(DigestError) { builder.add(value) }
}

@Suite struct QualityDeclarationTests {
    @Test func aCoreWithoutAProfileHasUniformLevelsForItsTiers() {
        let profile = PlainCore.qualityProfile
        #expect(profile == QualityProfile.uniform(levels: 2))
        #expect(profile.names == ["level-0", "level-1"])
        #expect(profile.levels.allSatisfy { $0.resolutionShare == 1 && $0.elementShare == 1 && $0.iterationShare == 1 })
        #expect(QualityDeclaration.problems(profile: profile, tierCount: PlainCore.qualityTiers, catalogNames: nil).isEmpty)
    }

    @Test func theSampleCoreDeclaresThreeNamedLevelsWithFallingBudgets() {
        let profile = SampleExperienceCore<NoFault>.qualityProfile
        #expect(profile.count == SampleExperienceCore<NoFault>.qualityTiers)
        #expect(profile.names == ["full", "reduced", "minimal"])
        for index in 1..<profile.count {
            let above = profile.level(index - 1)
            let level = profile.level(index)
            #expect(level.resolutionShare <= above.resolutionShare)
            #expect(level.elementShare <= above.elementShare)
            #expect(level.iterationShare <= above.iterationShare)
            #expect(level.effectPasses <= above.effectPasses)
        }
        #expect(profile.elements(requested: 4_000, level: 2) == 1_400)
    }

    @Test func theCatalogNamesMustEqualTheProfileNames() {
        let profile = SampleExperienceCore<NoFault>.qualityProfile
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["full", "reduced", "minimal"]).isEmpty)
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3, catalogNames: []).count == 1)
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3, catalogNames: ["low", "high"]).count == 1)
    }

    @Test func theFaultySampleHasFewerLevelsThanTiers() {
        #expect(SampleExperienceCore<WrongProfileCount>.qualityProfile.count == 2)
        #expect(SampleExperienceCore<WrongProfileCount>.qualityTiers == 3)
    }
}
