// HueCompassIdentifierTests — feature 339 (R02-G04-09) T-R02G0409-003 (FR-R02G0409-001; clarification Q1).
// The control panel's accessibility identifiers: `HueCompassControls.identifierNames` holds exactly the 23 names of
// clarification Q1, each once (clarification Q1 groups them by control kind, so the set is compared, not the order);
// `turnNames` names the four turn buttons in `HueCompassControls.turns` order and leads `identifierNames`; and for a
// session opened through the one app's session host, the shell's port turns every name into
// `experience.r02-g04.hue-compass.<name>`. The `.accessibilityIdentifier` modifiers in the view body are not
// inspectable from a unit test (SwiftUI's accessibility tree); the UI tests of the gate find them. Synthetic data,
// explicit types, plain loops, no sleep, no wall-clock assertion; each test well under 10 s.
#if os(iOS)
import Testing
import HueCompassCore
@testable import HueCompassExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct HueCompassIdentifierTests {
    /// The identifier names of clarification Q1, in the order the clarification lists them.
    static let expectedNames: [String] = ["turn-minus-4", "turn-minus-1", "turn-plus-1", "turn-plus-4", "probe",
                                          "select", "undo", "redo", "next-level", "reset-view", "hint",
                                          "dismiss-tutorial", "retry", "campaign", "daily", "practice", "replay",
                                          "replay-step", "replay-stop", "band-picker", "level-picker", "sound",
                                          "summary"]

    /// The identifier prefix of the experience `r02-g04.hue-compass`.
    static let prefix: String = "experience.r02-g04.hue-compass."

    /// `identifierNames` is exactly the 23 names of clarification Q1, each used once.
    @Test func theNamesAreTheClarifiedTwentyThree() {
        let names: [String] = HueCompassControls.identifierNames
        #expect(Self.expectedNames.count == 23)
        #expect(names.count == 23)
        #expect(Set(names).count == names.count, "every name is unique")
        #expect(Set(names) == Set(Self.expectedNames))
        for name in Self.expectedNames {
            var count: Int = 0
            for candidate in names where candidate == name { count += 1 }
            #expect(count == 1, "\(name)")
        }
    }

    /// The four turn buttons, in `HueCompassControls.turns` order (−4, −1, +1, +4), map to the four turn names, which
    /// lead `identifierNames`.
    @Test func theTurnsMapToTheFourTurnNames() {
        let turns: [Int] = HueCompassControls.turns
        #expect(turns == [-4, -1, 1, 4])
        #expect(HueCompassControls.turnNames.count == turns.count)
        #expect(HueCompassControls.turnNames == Array(Self.expectedNames[0...3]))
        for index in 0..<turns.count {
            let steps: Int = turns[index]
            let sign: String = steps < 0 ? "minus" : "plus"
            #expect(HueCompassControls.turnNames[index] == "turn-\(sign)-\(abs(steps))", "\(steps)")
        }
        #expect(Array(HueCompassControls.identifierNames.prefix(4)) == HueCompassControls.turnNames)
    }

    /// For an opened session, the shell's port gives `experience.r02-g04.hue-compass.<name>` for every name.
    @Test func thePortPrefixesEveryName() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: HueCompassTest.Shell = try await HueCompassTest.open(session, seed: 0)
        for name in HueCompassControls.identifierNames {
            let identifier: String = shell.port.identifier(name)
            #expect(identifier == Self.prefix + name, "\(name)")
        }
    }
}
#endif
