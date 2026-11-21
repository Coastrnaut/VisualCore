// WaveKnotKeeperIdentifierTests — feature 329 (R02-G03-09) T-R02G0309-003 (FR-R02G0309-001; clarification Q1).
// The control panel's accessibility identifiers: `WaveKnotKeeperControls.identifierNames` is exactly the 23 names of
// clarification Q1, in order and unique; `directionNames` names the six direction buttons in
// `WaveKnotKeeperDirection.allCases` order and is the slice after `point-picker`; and for a session opened through the
// one app's session host, the shell's port turns every name into `experience.r02-g03.wave-knot-keeper.<name>`. The
// `.accessibilityIdentifier` modifiers in the view body are not inspectable from a unit test (SwiftUI's accessibility
// tree); the UI tests of the gate find them. Synthetic data, explicit types, plain loops, no sleep, no wall-clock
// assertion; each test well under 10 s.
#if os(iOS)
import Testing
import WaveKnotKeeperCore
@testable import WaveKnotKeeperExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct WaveKnotKeeperIdentifierTests {
    typealias Access = WaveKnotKeeperAccess

    /// The identifier names of clarification Q1, in order.
    static let expectedNames: [String] = ["point-picker", "move-plus-x", "move-minus-x", "move-plus-y", "move-minus-y",
                                          "move-over", "move-under", "undo", "redo", "next-level", "reset-view",
                                          "hint", "dismiss-tutorial", "failure-undo", "retry", "campaign", "daily",
                                          "practice", "replay", "replay-step", "replay-stop", "level-picker", "sound"]

    /// The identifier prefix of the experience `r02-g03.wave-knot-keeper`.
    static let prefix: String = "experience.r02-g03.wave-knot-keeper."

    /// `identifierNames` is exactly the 23 names of clarification Q1, in order, each used once.
    @Test func theNamesAreTheClarifiedTwentyThree() {
        let names: [String] = WaveKnotKeeperControls.identifierNames
        #expect(names.count == 23)
        #expect(names == Self.expectedNames)
        #expect(Set(names).count == names.count, "every name is unique")
        for name in Self.expectedNames {
            var count: Int = 0
            for candidate in names where candidate == name { count += 1 }
            #expect(count == 1, "\(name)")
        }
    }

    /// The six direction buttons, in `WaveKnotKeeperDirection.allCases` order, map to the names after `point-picker`.
    @Test func theDirectionsMapToTheSixMoveNames() {
        let directions: [WaveKnotKeeperDirection] = WaveKnotKeeperDirection.allCases
        #expect(directions.count == 6)
        #expect(WaveKnotKeeperControls.directionNames.count == directions.count)
        #expect(WaveKnotKeeperControls.directionNames == Array(Self.expectedNames[1...6]))
    }

    /// For an opened session, the shell's port gives `experience.r02-g03.wave-knot-keeper.<name>` for every name.
    @Test func thePortPrefixesEveryName() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        for name in WaveKnotKeeperControls.identifierNames {
            let identifier: String = shell.port.identifier(name)
            #expect(identifier == Self.prefix + name, "\(name)")
        }
    }
}
#endif
