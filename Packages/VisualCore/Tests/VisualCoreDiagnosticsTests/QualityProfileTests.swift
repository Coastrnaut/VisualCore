// QualityProfileTests — feature 192 T-U06-003 (UA-F06; FR-U06-001 to FR-U06-004, FR-U06-006; SC-U06-002).
import Testing
@testable import VisualCoreDiagnostics

/// The error with which `QualityProfile.init(levels:)` refuses `levels`, or nil when it accepts them.
private func qualityProfileRefusal(_ levels: [QualityLevel]) -> QualityProfileError? {
    do {
        _ = try QualityProfile(levels: levels)
        return nil
    } catch {
        return error
    }
}

/// A valid profile of three levels used by several tests.
private func threeLevelProfile() throws -> QualityProfile {
    try QualityProfile(levels: [
        QualityLevel(name: "high", resolutionShare: 1, elementShare: 1, iterationShare: 1, effectPasses: 3),
        QualityLevel(name: "medium", resolutionShare: 0.75, elementShare: 0.6, iterationShare: 0.5, effectPasses: 1),
        QualityLevel(name: "low", resolutionShare: 0.5, elementShare: 0.25, iterationShare: 0.5, effectPasses: 0),
    ])
}

@Test func qualityProfileOfThreeLevelsGivesNamesAndBudgets() throws {
    let profile = try threeLevelProfile()
    #expect(profile.count == 3)
    #expect(profile.names == ["high", "medium", "low"])
    #expect(profile.levels.map(\.name) == ["high", "medium", "low"])
    #expect(profile.levels.map(\.resolutionShare) == [1, 0.75, 0.5])
    #expect(profile.levels.map(\.elementShare) == [1, 0.6, 0.25])
    #expect(profile.levels.map(\.iterationShare) == [1, 0.5, 0.5])
    #expect(profile.levels.map(\.effectPasses) == [3, 1, 0])
    #expect(profile.level(1) == QualityLevel(name: "medium", resolutionShare: 0.75, elementShare: 0.6,
                                             iterationShare: 0.5, effectPasses: 1))
    let plain = QualityLevel(name: "plain")
    #expect(plain.resolutionShare == 1 && plain.elementShare == 1 && plain.iterationShare == 1)
    #expect(plain.effectPasses == 0)
    #expect(QualityProfile.maxLevels == 8 && QualityProfile.maxNameLength == 40)
    #expect(QualityProfile.maxEffectPasses == 64)
    #expect(QualityBudget.allCases == [.resolutionShare, .elementShare, .iterationShare, .effectPasses])
}

@Test func qualityProfileRefusesTheTwelveInvalidProfiles() {
    let good = QualityLevel(name: "good")
    let table: [(what: String, levels: [QualityLevel], error: QualityProfileError)] = [
        ("no level", [], .noLevel),
        ("nine levels", (0..<9).map { QualityLevel(name: "l\($0)") }, .tooManyLevels(9)),
        ("empty name", [good, QualityLevel(name: "")], .invalidName(level: 1)),
        ("41-character name", [QualityLevel(name: String(repeating: "n", count: 41))], .invalidName(level: 0)),
        ("duplicate name", [good, QualityLevel(name: "other"), QualityLevel(name: "good")],
         .duplicateName(level: 2)),
        ("resolution share 0", [QualityLevel(name: "a", resolutionShare: 0)],
         .outOfRange(level: 0, budget: .resolutionShare)),
        ("resolution share 1.5", [QualityLevel(name: "a", resolutionShare: 1.5)],
         .outOfRange(level: 0, budget: .resolutionShare)),
        ("element share -0.1", [good, QualityLevel(name: "b", elementShare: -0.1)],
         .outOfRange(level: 1, budget: .elementShare)),
        ("iteration share 1.2", [QualityLevel(name: "a", iterationShare: 1.2)],
         .outOfRange(level: 0, budget: .iterationShare)),
        ("effect passes -1", [QualityLevel(name: "a", effectPasses: -1)],
         .outOfRange(level: 0, budget: .effectPasses)),
        ("a rising share", [QualityLevel(name: "a", elementShare: 0.5), QualityLevel(name: "b", elementShare: 0.6)],
         .rising(level: 1, budget: .elementShare)),
        ("rising effect passes", [QualityLevel(name: "a", effectPasses: 1), QualityLevel(name: "b", effectPasses: 2)],
         .rising(level: 1, budget: .effectPasses)),
    ]
    #expect(table.count == 12)
    for row in table {
        let refusal = qualityProfileRefusal(row.levels)
        #expect(refusal == row.error, "\(row.what)")
    }
}

@Test func qualityProfileRefusesFurtherEdgeValues() {
    #expect(qualityProfileRefusal([QualityLevel(name: "a", iterationShare: .nan)])
            == .outOfRange(level: 0, budget: .iterationShare))
    #expect(qualityProfileRefusal([QualityLevel(name: "a", resolutionShare: .infinity)])
            == .outOfRange(level: 0, budget: .resolutionShare))
    #expect(qualityProfileRefusal([QualityLevel(name: "a", effectPasses: 65)])
            == .outOfRange(level: 0, budget: .effectPasses))
    #expect(qualityProfileRefusal([QualityLevel(name: "a", resolutionShare: 0.5),
                                   QualityLevel(name: "b", resolutionShare: 0.75)])
            == .rising(level: 1, budget: .resolutionShare))
    #expect(qualityProfileRefusal([QualityLevel(name: "a", iterationShare: 0.5),
                                   QualityLevel(name: "b", iterationShare: 0.75)])
            == .rising(level: 1, budget: .iterationShare))
    // The limits themselves are accepted.
    #expect(qualityProfileRefusal([QualityLevel(name: String(repeating: "n", count: 40), effectPasses: 64),
                                   QualityLevel(name: "b", elementShare: 0, iterationShare: 0)]) == nil)
    #expect(qualityProfileRefusal((0..<8).map { QualityLevel(name: "l\($0)") }) == nil)
}

@Test func qualityProfileLevelClamps() throws {
    let profile = try threeLevelProfile()
    #expect(profile.level(-1).name == "high")
    #expect(profile.level(0).name == "high")
    #expect(profile.level(2).name == "low")
    #expect(profile.level(3).name == "low")
    #expect(profile.level(.max).name == "low" && profile.level(.min).name == "high")
}

@Test func qualityProfileElementsFollowTheShare() throws {
    let profile = try threeLevelProfile()
    #expect(profile.elements(requested: 0, level: 0) == 0)
    #expect(profile.elements(requested: -5, level: 1, minimum: 100) == 0)
    #expect(profile.elements(requested: 4_000, level: 0) == 4_000)
    #expect(profile.elements(requested: 4_000, level: 1) == 2_400)
    #expect(profile.elements(requested: 999, level: 2) == 249, "0.25 × 999 = 249.75 is rounded down")
    #expect(profile.elements(requested: 3, level: 2) == 0, "the default minimum is 0")
    #expect(profile.elements(requested: 300, level: 2, minimum: 100) == 100, "75 is raised to the minimum")
    #expect(profile.elements(requested: 50, level: 2, minimum: 100) == 50, "never above the request")
    #expect(profile.elements(requested: 10, level: 2, minimum: -4) == 2, "a negative minimum counts as 0")
    #expect(profile.elements(requested: 4_000, level: 9) == 1_000, "the level is clamped to the last")
    #expect(profile.elements(requested: 4_000, level: -3) == 4_000, "the level is clamped to the first")
}

@Test func qualityProfileIterationsFollowTheShare() throws {
    let profile = try threeLevelProfile()
    #expect(profile.iterations(requested: 0, level: 0) == 0)
    #expect(profile.iterations(requested: -1, level: 2) == 0)
    #expect(profile.iterations(requested: 8, level: 0) == 8)
    #expect(profile.iterations(requested: 7, level: 1) == 3, "0.5 × 7 = 3.5 is rounded down")
    #expect(profile.iterations(requested: 1, level: 2) == 1, "the default minimum is 1")
    #expect(profile.iterations(requested: 7, level: 1, minimum: 5) == 5)
    #expect(profile.iterations(requested: 4, level: 1, minimum: 5) == 4, "never above the request")
    #expect(profile.iterations(requested: 1, level: 1, minimum: 0) == 0)
    #expect(profile.iterations(requested: 64, level: 7) == 32, "the level is clamped to the last")
    for requested in 1...200 {
        for level in -1...3 {
            let elements = profile.elements(requested: requested, level: level, minimum: 10)
            let iterations = profile.iterations(requested: requested, level: level)
            #expect(elements <= requested && elements >= min(requested, 10))
            #expect(iterations <= requested && iterations >= 1)
        }
    }
}

@Test func qualityProfileUniformClampsAndNames() {
    #expect(QualityProfile.uniform(levels: 0).count == 1)
    #expect(QualityProfile.uniform(levels: -7).count == 1)
    #expect(QualityProfile.uniform(levels: 20).count == 8)
    let three = QualityProfile.uniform(levels: 3)
    #expect(three.names == ["level-0", "level-1", "level-2"])
    #expect(three.levels.allSatisfy {
        $0.resolutionShare == 1 && $0.elementShare == 1 && $0.iterationShare == 1 && $0.effectPasses == 0
    })
    #expect(QualityProfile.uniform(levels: 8).names.last == "level-7")
    #expect(qualityProfileRefusal(QualityProfile.uniform(levels: 8).levels) == nil, "a uniform profile is valid")
    #expect(QualityProfile.single.count == 1)
    #expect(QualityProfile.single == QualityProfile.uniform(levels: 1))
    #expect(QualityProfile.single.names == ["level-0"])
}

@Test func qualityDeclarationReportsDifferences() throws {
    let profile = try threeLevelProfile()
    #expect(QualityDeclaration.problems(profile: profile, tierCount: 3, catalogNames: ["high", "medium", "low"])
            .isEmpty)
    #expect(QualityDeclaration.problems(profile: profile, tierCount: 3, catalogNames: nil).isEmpty)
    #expect(QualityDeclaration.problems(profile: profile, tierCount: 4, catalogNames: nil)
            == ["the profile has 3 levels and the experience declares 4 tiers"])
    #expect(QualityDeclaration.problems(profile: profile, tierCount: 3, catalogNames: ["high", "low", "medium"])
            == ["the profile names [\"high\", \"medium\", \"low\"] differ from the catalog names "
                + "[\"high\", \"low\", \"medium\"]"])
    #expect(QualityDeclaration.problems(profile: profile, tierCount: 2, catalogNames: ["high", "low"]).count == 2)
    #expect(QualityDeclaration.problems(profile: .single, tierCount: 0, catalogNames: nil).isEmpty,
            "a tier count below 1 counts as one level")
    #expect(QualityDeclaration.problems(profile: .single, tierCount: 1, catalogNames: []).count == 1)
}
