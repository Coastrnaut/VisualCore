// MicroscopicAuroraIdentifierTests — feature 489 (R02-G19-09) T-R02G1909-003 (FR-R02G1909-001; clarification Q1),
// modelled on feature 479 (`ApsidesWorkshopIdentifierTests.swift`). The control panel's accessibility identifiers:
// `MicroscopicAuroraControls.identifierNames` holds exactly the 48 names of the clarification (the 47 names the panel
// gave plus `explanation`), each once (the set is compared, and every name is counted); the panel's source gives each
// name through `port.identifier("<name>")` exactly once and no other name (the failure explanation is `explanation`,
// the short failure line `failure`); and for a session opened through the one app's session host, the shell's port
// turns every name into `experience.r02-g19.microscopic-aurora.<name>`, and the 48 identifiers are unique. The
// `.accessibilityIdentifier` modifiers in the view body are not inspectable from a unit test (SwiftUI's accessibility
// tree), so the source is read (`#filePath`, as the accessibility tests do); the UI tests of the gate find the
// identifiers on screen. Synthetic data, explicit types, plain loops, no sleep, no wall-clock assertion; each test well
// under 10 s. iOS only, as the target.
#if os(iOS)
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import MicroscopicAuroraExperience
import MicroscopicAuroraCore

@MainActor
@Suite(.serialized) struct MicroscopicAuroraIdentifierTests {
    /// The identifier names of the clarification, in the order the clarification lists them, with `explanation` after
    /// `failure`.
    static let expectedNames: [String] = ["slot", "slot-minus", "slot-plus", "selection", "wells-detail", "site",
                                          "site-minus", "site-plus", "strength", "strength-minus", "strength-plus",
                                          "sense", "place", "remove", "freeze", "reset-view", "tick", "tick-minus",
                                          "tick-plus", "tick-detail", "play", "undo", "redo", "next-level",
                                          "dismiss-tutorial", "hint", "campaign", "daily", "practice", "level-picker",
                                          "play-level", "replay", "replay-step", "replay-stop", "sound", "actions",
                                          "status", "failure", "explanation", "progress", "summary", "message",
                                          "tutorial", "hint-text", "band", "stars", "goal", "replay-position"]

    /// The identifier prefix of the experience `r02-g19.microscopic-aurora`.
    static let prefix: String = "experience.r02-g19.microscopic-aurora."

    /// The panel's source text (`Experience/MicroscopicAuroraControls.swift`, beside this test's folder).
    static func panelSource() throws -> String {
        let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let file: URL = tests.deletingLastPathComponent().appendingPathComponent("Experience")
            .appendingPathComponent("MicroscopicAuroraControls.swift")
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

    /// `identifierNames` is exactly the 48 names of the clarification, each used once, in the clarified order.
    @Test func theNamesAreTheClarifiedFortyEight() {
        let names: [String] = MicroscopicAuroraControls.identifierNames
        #expect(Self.expectedNames.count == 48)
        #expect(Set(Self.expectedNames).count == 48, "the clarified names are unique")
        #expect(names.count == 48)
        #expect(Set(names).count == names.count, "every name is unique")
        #expect(Set(names) == Set(Self.expectedNames))
        #expect(names == Self.expectedNames, "the clarified order")
        for name in Self.expectedNames {
            var count: Int = 0
            for candidate in names where candidate == name { count += 1 }
            #expect(count == 1, "\(name)")
        }
    }

    /// The failure explanation has its own identifier `explanation`, apart from the failure line's `failure`, and the
    /// panel's source gives each of the two exactly once.
    @Test func theExplanationHasItsOwnName() throws {
        let names: [String] = MicroscopicAuroraControls.identifierNames
        #expect(names.contains("explanation"))
        #expect(names.contains("failure"))
        let source: String = try Self.panelSource()
        #expect(Self.occurrences(of: "port.identifier(\"failure\")", in: source) == 1, "the failure line only")
        #expect(Self.occurrences(of: "port.identifier(\"explanation\")", in: source) == 1, "the explanation")
    }

    /// Every name is a non-empty, lower-case, hyphenated token, so the identifier stays a plain dotted path.
    @Test func theNamesAreLowerCaseTokens() {
        let allowed: Set<Character> = Set("abcdefghijklmnopqrstuvwxyz-")
        for name in MicroscopicAuroraControls.identifierNames {
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
        for name in MicroscopicAuroraControls.identifierNames {
            let call: String = "port.identifier(\"\(name)\")"
            #expect(Self.occurrences(of: call, in: source) == 1, "\(name)")
        }
        #expect(Self.occurrences(of: "port.identifier(\"", in: source)
                    == MicroscopicAuroraControls.identifierNames.count,
                "every identifier the panel gives is listed")
    }

    /// For an opened session, the shell's port gives `experience.r02-g19.microscopic-aurora.<name>` for every name,
    /// and the 48 identifiers are unique.
    @Test func thePortPrefixesEveryName() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: MicroscopicAuroraTest.Shell = try await MicroscopicAuroraTest.open(session, seed: 0)
        var identifiers: [String] = []
        for name in MicroscopicAuroraControls.identifierNames {
            let identifier: String = shell.port.identifier(name)
            #expect(identifier.hasPrefix(Self.prefix), "\(identifier)")
            #expect(identifier == Self.prefix + name, "\(name)")
            identifiers.append(identifier)
        }
        #expect(identifiers.count == 48)
        #expect(Set(identifiers).count == identifiers.count, "every identifier is unique")
    }
}
#endif
