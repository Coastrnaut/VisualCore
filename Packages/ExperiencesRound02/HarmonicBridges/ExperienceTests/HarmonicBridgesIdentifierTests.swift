// HarmonicBridgesIdentifierTests — feature 419 (R02-G12-09) T-R02G1209-003 (FR-R02G1209-001; clarification Q1),
// ported from Echo Cartographer's (`EchoCartographerIdentifierTests.swift`, feature 409). The control panel's
// accessibility identifiers: `HarmonicBridgesControls.identifierNames` holds exactly the 30 names of clarification Q1,
// each once (the set is compared, and every name is counted); the panel's source gives each name through
// `port.identifier("<name>")` exactly once and no other name; and for a session opened through the one app's session
// host, the shell's port turns every name into `experience.r02-g12.harmonic-bridges.<name>`, and the 30 identifiers are
// unique. The `.accessibilityIdentifier` modifiers in the view body are not inspectable from a unit test (SwiftUI's
// accessibility tree), so the source is read (`#filePath`, as the Core's shader source test does); the UI tests of
// the gate find the identifiers on screen. Synthetic data, explicit types, plain loops, no sleep, no wall-clock
// assertion; each test well under 10 s. iOS only, as the target.
#if os(iOS)
import Foundation
import HarmonicBridgesCore
import Testing
@testable import HarmonicBridgesExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct HarmonicBridgesIdentifierTests {
    /// The identifier names of clarification Q1, in the order the clarification lists them.
    static let expectedNames: [String] = ["string", "peg", "tune", "test", "undo", "redo", "next-level", "reset-view",
                                          "dismiss-tutorial", "hint", "failure-undo", "retry", "campaign", "daily",
                                          "practice", "level-picker", "play-level", "replay", "replay-step",
                                          "replay-stop", "sound", "summary", "status", "actions", "message",
                                          "failure", "instruction", "hint-text", "goal", "replay-position"]

    /// The identifier prefix of the experience `r02-g12.harmonic-bridges`.
    static let prefix: String = "experience.r02-g12.harmonic-bridges."

    /// The panel's source text (`Experience/HarmonicBridgesControls.swift`, beside this test's folder).
    static func panelSource() throws -> String {
        let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let file: URL = tests.deletingLastPathComponent().appendingPathComponent("Experience")
            .appendingPathComponent("HarmonicBridgesControls.swift")
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

    /// `identifierNames` is exactly the 30 names of clarification Q1, each used once.
    @Test func theNamesAreTheClarifiedThirty() {
        let names: [String] = HarmonicBridgesControls.identifierNames
        #expect(Self.expectedNames.count == 30)
        #expect(Set(Self.expectedNames).count == 30, "the clarified names are unique")
        #expect(names.count == 30)
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
        let allowed: Set<Character> = Set("abcdefghijklmnopqrstuvwxyz-")
        for name in HarmonicBridgesControls.identifierNames {
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
        for name in HarmonicBridgesControls.identifierNames {
            let call: String = "port.identifier(\"" + name + "\")"
            #expect(Self.occurrences(of: call, in: source) == 1, "\(name)")
        }
        #expect(Self.occurrences(of: "port.identifier(\"", in: source) == HarmonicBridgesControls.identifierNames.count,
                "every identifier the panel gives is listed")
    }

    /// For an opened session, the shell's port gives `experience.r02-g12.harmonic-bridges.<name>` for every name,
    /// and the 30 identifiers are unique.
    @Test func thePortPrefixesEveryName() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: HarmonicBridgesTest.Shell = try await HarmonicBridgesTest.open(session, seed: 0)
        var identifiers: [String] = []
        for name in HarmonicBridgesControls.identifierNames {
            let identifier: String = shell.port.identifier(name)
            #expect(identifier.hasPrefix(Self.prefix), "\(identifier)")
            #expect(identifier == Self.prefix + name, "\(name)")
            identifiers.append(identifier)
        }
        #expect(identifiers.count == 30)
        #expect(Set(identifiers).count == identifiers.count, "every identifier is unique")
    }
}
#endif
