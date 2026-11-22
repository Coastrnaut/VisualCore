// ChronoConstellatorIdentifierTests — feature 359 (R02-G06-09) T-R02G0609-003 (FR-R02G0609-001; clarification Q1).
// The control panel's accessibility identifiers: `ChronoConstellatorControls.identifierNames` holds exactly the 28
// names of clarification Q1, each once (the set is compared, and every name is counted); and for a session opened
// through the one app's session host, the shell's port turns every name into
// `experience.r02-g06.chrono-constellator.<name>`, and the 28 identifiers are unique. The `.accessibilityIdentifier`
// modifiers in the view body are not inspectable from a unit test (SwiftUI's accessibility tree); the UI tests of the
// gate find them. Synthetic data, explicit types, plain loops, no sleep, no wall-clock assertion; each test well
// under 10 s.
#if os(iOS)
import ChronoConstellatorCore
import Testing
@testable import ChronoConstellatorExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct ChronoConstellatorIdentifierTests {
    /// The identifier names of clarification Q1, in the order the clarification lists them.
    static let expectedNames: [String] = ["phase-down", "phase-up", "add-hold", "remove-hold", "step-1", "step-10",
                                          "run", "rewind", "undo", "redo", "next-level", "reset-view", "hint",
                                          "dismiss-tutorial", "failure-undo", "failure-rewind", "retry", "campaign",
                                          "daily", "practice", "play-level", "replay", "replay-step", "replay-stop",
                                          "star-picker", "level-picker", "sound", "summary"]

    /// The identifier prefix of the experience `r02-g06.chrono-constellator`.
    static let prefix: String = "experience.r02-g06.chrono-constellator."

    /// `identifierNames` is exactly the 28 names of clarification Q1, each used once.
    @Test func theNamesAreTheClarifiedTwentyEight() {
        let names: [String] = ChronoConstellatorControls.identifierNames
        #expect(Self.expectedNames.count == 28)
        #expect(names.count == 28)
        #expect(Set(names).count == names.count, "every name is unique")
        #expect(Set(names) == Set(Self.expectedNames))
        for name in Self.expectedNames {
            var count: Int = 0
            for candidate in names where candidate == name { count += 1 }
            #expect(count == 1, "\(name)")
        }
    }

    /// Every name is a non-empty, lower-case, hyphenated token, so the identifier stays a plain dotted path.
    @Test func theNamesAreLowerCaseTokens() {
        let allowed: Set<Character> = Set("abcdefghijklmnopqrstuvwxyz0123456789-")
        for name in ChronoConstellatorControls.identifierNames {
            #expect(!name.isEmpty)
            var plain: Bool = true
            for character in name where !allowed.contains(character) { plain = false }
            #expect(plain, "\(name)")
            #expect(!name.hasPrefix("-") && !name.hasSuffix("-"), "\(name)")
        }
    }

    /// For an opened session, the shell's port gives `experience.r02-g06.chrono-constellator.<name>` for every name,
    /// and the 28 identifiers are unique.
    @Test func thePortPrefixesEveryName() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: ChronoConstellatorTest.Shell = try await ChronoConstellatorTest.open(session, seed: 0)
        var identifiers: [String] = []
        for name in ChronoConstellatorControls.identifierNames {
            let identifier: String = shell.port.identifier(name)
            #expect(identifier.hasPrefix(Self.prefix), "\(identifier)")
            #expect(identifier == Self.prefix + name, "\(name)")
            identifiers.append(identifier)
        }
        #expect(identifiers.count == 28)
        #expect(Set(identifiers).count == identifiers.count, "every identifier is unique")
    }
}
#endif
