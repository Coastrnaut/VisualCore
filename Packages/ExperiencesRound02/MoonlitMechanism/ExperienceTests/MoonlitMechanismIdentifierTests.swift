// MoonlitMechanismIdentifierTests — feature 439 (R02-G14-09) T-R02G1409-003 (clarification Q1), modelled on feature 429
// (`AcousticConstellatorIdentifierTests.swift`). The control panel's accessibility identifiers:
// `MoonlitMechanismControls.identifierNames` holds exactly the 44 names of clarification Q1, each once (the set is
// compared, and every name is counted); the panel's source gives each name through `port.identifier("<name>")` exactly
// once and no other name; and for a session opened through the one app's session host, the shell's port turns every
// name into `experience.r02-g14.moonlit-mechanism.<name>`, and the 44 identifiers are unique. The
// `.accessibilityIdentifier` modifiers in the view body are not inspectable from a unit test (SwiftUI's accessibility
// tree), so the source is read (`#filePath`, as the Core's shader source test does); the UI tests of the gate find the
// identifiers on screen. Synthetic data, explicit types, plain loops, no sleep, no wall-clock assertion; each test well
// under 10 s. iOS only, as the target.
#if os(iOS)
import Foundation
import MoonlitMechanismCore
import Testing
@testable import MoonlitMechanismExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct MoonlitMechanismIdentifierTests {
    /// The identifier names of clarification Q1, in the order the clarification lists them.
    static let expectedNames: [String] = ["gear", "gear-minus", "gear-plus", "gear-detail", "turn-minus", "turn-plus",
                                          "reseat-minus", "reseat-plus", "lamp", "lamp-minus", "lamp-plus", "frame",
                                          "frame-minus", "frame-plus", "run", "undo", "redo", "next-level",
                                          "reset-view", "dismiss-tutorial", "hint", "failure-undo", "retry",
                                          "campaign", "daily", "practice", "level-picker", "play-level", "replay",
                                          "replay-step", "replay-stop", "sound", "summary", "status", "actions",
                                          "pending", "progress", "message", "failure", "explanation", "instruction",
                                          "hint-text", "goal", "replay-position"]

    /// The identifier prefix of the experience `r02-g14.moonlit-mechanism`.
    static let prefix: String = "experience.r02-g14.moonlit-mechanism."

    /// The panel's source text (`Experience/MoonlitMechanismControls.swift`, beside this test's folder).
    static func panelSource() throws -> String {
        let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let file: URL = tests.deletingLastPathComponent().appendingPathComponent("Experience")
            .appendingPathComponent("MoonlitMechanismControls.swift")
        return try String(contentsOf: file, encoding: .utf8)
    }

    /// The number of times `needle` occurs in `text` (non-overlapping).
    static func occurrences(of needle: String, in text: String) -> Int {
        var count: Int = 0
        var rest: Substring = Substring(text)
        while let range = rest.range(of: needle) {
            count += 1
            rest = rest[range.upperBound...]
        }
        return count
    }

    /// `identifierNames` is exactly the 44 names of clarification Q1, each used once, in the clarified order.
    @Test func theNamesAreTheClarifiedFortyFour() {
        let names: [String] = MoonlitMechanismControls.identifierNames
        #expect(Self.expectedNames.count == 44)
        #expect(Set(Self.expectedNames).count == 44, "the clarified names are unique")
        #expect(names.count == 44)
        #expect(Set(names).count == names.count, "every name is unique")
        #expect(Set(names) == Set(Self.expectedNames))
        #expect(names == Self.expectedNames, "the clarified order")
        for name in Self.expectedNames {
            var count: Int = 0
            for candidate in names where candidate == name { count += 1 }
            #expect(count == 1, "\(name)")
        }
    }

    /// Every name is a non-empty, lower-case, hyphenated token, so the identifier stays a plain dotted path.
    @Test func theNamesAreLowerCaseTokens() {
        let allowed: Set<Character> = Set("abcdefghijklmnopqrstuvwxyz-")
        for name in MoonlitMechanismControls.identifierNames {
            #expect(!name.isEmpty)
            var plain: Bool = true
            for character in name where !allowed.contains(character) { plain = false }
            #expect(plain, "\(name)")
            #expect(!name.hasPrefix("-") && !name.hasSuffix("-"), "\(name)")
            #expect(!name.contains("--"), "\(name)")
        }
    }

    /// The panel's source gives every listed name through `port.identifier("<name>")` exactly once, and gives no
    /// identifier that is not listed.
    @Test func thePanelUsesEveryNameOnce() throws {
        let source: String = try Self.panelSource()
        for name in MoonlitMechanismControls.identifierNames {
            let call: String = "port.identifier(\"\(name)\")"
            #expect(Self.occurrences(of: call, in: source) == 1, "\(name)")
        }
        #expect(Self.occurrences(of: "port.identifier(\"", in: source)
                    == MoonlitMechanismControls.identifierNames.count,
                "every identifier the panel gives is listed")
    }

    /// For an opened session, the shell's port gives `experience.r02-g14.moonlit-mechanism.<name>` for every name, and
    /// the 44 identifiers are unique.
    @Test func thePortPrefixesEveryName() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: MoonlitMechanismTest.Shell = try await MoonlitMechanismTest.open(session, seed: 0)
        var identifiers: [String] = []
        for name in MoonlitMechanismControls.identifierNames {
            let identifier: String = shell.port.identifier(name)
            #expect(identifier.hasPrefix(Self.prefix), "\(identifier)")
            #expect(identifier == Self.prefix + name, "\(name)")
            identifiers.append(identifier)
        }
        #expect(identifiers.count == 44)
        #expect(Set(identifiers).count == identifiers.count, "every identifier is unique")
    }
}
#endif
