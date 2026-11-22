// ColorfallCanyonsIdentifierTests — feature 349 (R02-G05-09) T-R02G0509-003 (FR-R02G0509-001; clarification Q1).
// The control panel's accessibility identifiers: `ColorfallCanyonsControls.identifierNames` holds exactly the 26 names
// of clarification Q1, each once (the set is compared, and every name is counted); `valveNames` names the three valve
// buttons, index 0 … 2 through `valveName(_:)`, and a level never has more springs than valve names (the generator's
// band profiles 1 … 5 have at most three springs); and for a session opened through the one app's session host, the
// shell's port turns every name into `experience.r02-g05.colorfall-canyons.<name>`. The `.accessibilityIdentifier`
// modifiers in the view body are not inspectable from a unit test (SwiftUI's accessibility tree); the UI tests of the
// gate find them. Synthetic data, explicit types, plain loops, no sleep, no wall-clock assertion; each test well
// under 10 s.
#if os(iOS)
import ColorfallCanyonsCore
import Testing
@testable import ColorfallCanyonsExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct ColorfallCanyonsIdentifierTests {
    /// The identifier names of clarification Q1, in the order the clarification lists them.
    static let expectedNames: [String] = ["carve", "valve-0", "valve-1", "valve-2", "step-1", "step-10", "run",
                                          "undo", "redo", "next-level", "reset-view", "hint", "dismiss-tutorial",
                                          "failure-undo", "retry", "campaign", "daily", "practice", "play-level",
                                          "replay", "replay-step", "replay-stop", "cell-picker", "level-picker",
                                          "sound", "summary"]

    /// The identifier prefix of the experience `r02-g05.colorfall-canyons`.
    static let prefix: String = "experience.r02-g05.colorfall-canyons."

    /// `identifierNames` is exactly the 26 names of clarification Q1, each used once.
    @Test func theNamesAreTheClarifiedTwentySix() {
        let names: [String] = ColorfallCanyonsControls.identifierNames
        #expect(Self.expectedNames.count == 26)
        #expect(names.count == 26)
        #expect(Set(names).count == names.count, "every name is unique")
        #expect(Set(names) == Set(Self.expectedNames))
        for name in Self.expectedNames {
            var count: Int = 0
            for candidate in names where candidate == name { count += 1 }
            #expect(count == 1, "\(name)")
        }
    }

    /// The valve names map spring index 0 … 2 to `valveName(index)`, all appear in `identifierNames`, and no band's
    /// levels have more springs than there are valve names.
    @Test func theValveNamesCoverEverySpring() {
        let valves: [String] = ColorfallCanyonsControls.valveNames
        #expect(valves == ["valve-0", "valve-1", "valve-2"])
        for index in 0..<valves.count {
            #expect(ColorfallCanyonsControls.valveName(index) == valves[index], "\(index)")
            #expect(ColorfallCanyonsControls.identifierNames.contains(valves[index]), "\(valves[index])")
        }
        var most: Int = 0
        for band in 1...5 {
            let springs: Int = ColorfallCanyonsBandProfile.of(band: band).springs
            #expect(springs >= 1, "band \(band)")
            #expect(springs <= 3, "band \(band) has \(springs) springs")
            if springs > most { most = springs }
        }
        #expect(most <= valves.count)
    }

    /// For an opened session, the shell's port gives `experience.r02-g05.colorfall-canyons.<name>` for every name.
    @Test func thePortPrefixesEveryName() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: ColorfallCanyonsTest.Shell = try await ColorfallCanyonsTest.open(session, seed: 0)
        for name in ColorfallCanyonsControls.identifierNames {
            let identifier: String = shell.port.identifier(name)
            #expect(identifier == Self.prefix + name, "\(name)")
        }
    }
}
#endif
