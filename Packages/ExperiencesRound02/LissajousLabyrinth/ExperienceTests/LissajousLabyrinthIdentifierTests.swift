// LissajousLabyrinthIdentifierTests — feature 319 (R02-G02-09) T-R02G0209-003 (FR-R02G0209-001; clarification Q1).
// The control panel's accessibility identifiers: `LissajousLabyrinthControls.identifierNames` is exactly the 22 names of
// clarification Q1, in order and unique; `identifierName(_:)` maps the four dials, in `LissajousLabyrinthDial.allCases`
// order, to the first four names; and for a session opened through the one app's session host, the shell's port turns
// every name into `experience.r02-g02.lissajous-labyrinth.<name>`. The `.accessibilityIdentifier` modifiers in the view
// body are not inspectable from a unit test (SwiftUI's accessibility tree); the UI tests of the gate find them. Synthetic
// data, explicit types, plain loops, no sleep, no wall-clock assertion; each test well under 10 s.
#if os(iOS)
import Testing
import LissajousLabyrinthCore
@testable import LissajousLabyrinthExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct LissajousLabyrinthIdentifierTests {
    typealias Access = LissajousLabyrinthAccess

    /// The identifier names of clarification Q1, in order.
    static let expectedNames: [String] = ["frequency-a", "frequency-b", "phase-a", "phase-c", "apply", "clear", "undo",
                                          "redo", "next-level", "reset-view", "hint", "dismiss-tutorial",
                                          "failure-undo", "retry", "campaign", "daily", "practice", "replay",
                                          "replay-step", "replay-stop", "level-picker", "sound"]

    /// The identifier prefix of the experience `r02-g02.lissajous-labyrinth`.
    static let prefix: String = "experience.r02-g02.lissajous-labyrinth."

    /// `identifierNames` is exactly the 22 names of clarification Q1, in order, each used once.
    @Test func theNamesAreTheClarifiedTwentyTwo() {
        let names: [String] = LissajousLabyrinthControls.identifierNames
        #expect(names.count == 22)
        #expect(names == Self.expectedNames)
        #expect(Set(names).count == names.count, "every name is unique")
    }

    /// The four dials, in `LissajousLabyrinthDial.allCases` order, map to the first four names.
    @Test func theDialsMapToTheFirstFourNames() {
        let dials: [LissajousLabyrinthDial] = LissajousLabyrinthDial.allCases
        #expect(dials == [.frequencyA, .frequencyB, .phaseA, .phaseC])
        var mapped: [String] = []
        for dial in dials { mapped.append(LissajousLabyrinthControls.identifierName(dial)) }
        #expect(mapped == Array(Self.expectedNames.prefix(4)))
    }

    /// For an opened session, the shell's port gives `experience.r02-g02.lissajous-labyrinth.<name>` for every name.
    @Test func thePortPrefixesEveryName() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        for name in LissajousLabyrinthControls.identifierNames {
            let identifier: String = shell.port.identifier(name)
            #expect(identifier == Self.prefix + name, "\(name)")
        }
    }
}
#endif
