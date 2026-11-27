// BinaryGardensIdentifierTests — feature 509 (R02-G21-09) T-R02G2109-003 (FR-R02G2109-001; clarification Q1),
// modelled on feature 499 (`MushroomWeatherIdentifierTests.swift`). The control panel's accessibility identifiers:
// `BinaryGardensControls.identifierNames` holds exactly the 56 names the panel gives, as built by features 503 … 507
// (the failure explanation as `explanation`, the short failure line as `failure`), each once (the set is compared, and
// every name is counted); the panel's source gives each name through `port.identifier("<name>")` exactly once and no
// other name (the level line carries none); and for a session opened through the one app's session host, the shell's
// port turns every name into `experience.r02-g21.binary-gardens.<name>`, and the 56 identifiers are unique. The
// `.accessibilityIdentifier` modifiers in the view body are not inspectable from a unit test (SwiftUI's accessibility
// tree), so the source is read (`#filePath`, as the accessibility tests do); the UI tests of the gate find the
// identifiers on screen. Synthetic data, explicit types, plain loops, no sleep, no wall-clock assertion; each test well
// under 10 s. iOS only, as the target.
#if os(iOS)
import BinaryGardensCore
import Foundation
import Testing
@testable import BinaryGardensExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct BinaryGardensIdentifierTests {
    /// The identifier names as built, in the contract's order (features 503 and 504's, then 505 … 507's), with
    /// `explanation` and `mode` among feature 505's.
    static let expectedNames: [String] = ["actions", "status", "tutorial", "failure", "progress", "message",
                                          "preview-refusal", "star", "star-detail", "ring-minus", "ring", "ring-plus",
                                          "phase-minus", "phase", "phase-plus", "luminosity-minus", "luminosity",
                                          "luminosity-plus", "tilt-minus", "tilt", "tilt-plus", "tick-minus", "tick",
                                          "tick-plus", "run", "tick-detail", "undo", "redo", "next-level",
                                          "ring-choice", "luminosity-choice", "phase-target", "set-phase",
                                          "tilt-choice", "inspect", "inspect-detail", "reset-view",
                                          "dismiss-tutorial", "hint", "hint-text", "stars", "goal", "band",
                                          "explanation", "mode", "campaign", "daily", "practice", "level-picker",
                                          "play-level", "summary", "sound", "replay", "replay-step", "replay-stop",
                                          "replay-position"]

    /// The number of names.
    static let count: Int = 56

    /// The identifier prefix of the experience `r02-g21.binary-gardens`.
    static let prefix: String = "experience.r02-g21.binary-gardens."

    /// The panel's source text (`Experience/BinaryGardensControls.swift`, beside this test's folder).
    static func panelSource() throws -> String {
        let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let file: URL = tests.deletingLastPathComponent().appendingPathComponent("Experience")
            .appendingPathComponent("BinaryGardensControls.swift")
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

    /// `identifierNames` is exactly the 56 names as built, each listed once, in the contract's order.
    @Test func theNamesAreTheBuiltFiftySix() {
        let names: [String] = BinaryGardensControls.identifierNames
        #expect(Self.expectedNames.count == Self.count)
        #expect(Set(Self.expectedNames).count == Self.count, "the expected names are unique")
        #expect(names.count == Self.count)
        #expect(Set(names).count == names.count, "every name is unique")
        #expect(Set(names) == Set(Self.expectedNames))
        #expect(names == Self.expectedNames, "the contract's order")
        for name in Self.expectedNames {
            var count: Int = 0
            for candidate in names where candidate == name { count += 1 }
            #expect(count == 1, "\(name)")
        }
    }

    /// The failure explanation has its own identifier `explanation`, apart from the failure line's `failure`, and the
    /// panel's source gives each of the two exactly once.
    @Test func theExplanationHasItsOwnName() throws {
        let names: [String] = BinaryGardensControls.identifierNames
        #expect(names.contains("explanation"))
        #expect(names.contains("failure"))
        let source: String = try Self.panelSource()
        #expect(Self.occurrences(of: "port.identifier(\"failure\")", in: source) == 1, "the failure line only")
        #expect(Self.occurrences(of: "port.identifier(\"explanation\")", in: source) == 1, "the explanation")
    }

    /// Every name is a non-empty, lower-case, hyphenated token without digits, so the identifier stays a plain dotted
    /// path.
    @Test func theNamesAreLowerCaseTokens() {
        let allowed: Set<Character> = Set("abcdefghijklmnopqrstuvwxyz-")
        for name in BinaryGardensControls.identifierNames {
            #expect(!name.isEmpty)
            var plain: Bool = true
            for character in name where !allowed.contains(character) { plain = false }
            #expect(plain, "\(name)")
            #expect(!name.hasPrefix("-") && !name.hasSuffix("-"), "\(name)")
            #expect(!name.contains("--"), "\(name)")
        }
    }

    /// The panel's source gives every listed name through `port.identifier("<name>")` exactly once, and no identifier
    /// that is not listed (every identifier call is a literal name).
    @Test func thePanelUsesEveryNameOnce() throws {
        let source: String = try Self.panelSource()
        let names: [String] = BinaryGardensControls.identifierNames
        for name in names {
            let call: String = "port.identifier(\"\(name)\")"
            #expect(Self.occurrences(of: call, in: source) == 1, "\(name)")
        }
        #expect(Self.occurrences(of: "port.identifier(\"", in: source) == names.count,
                "every identifier the panel gives is listed")
        #expect(Self.occurrences(of: "port.identifier(", in: source) == names.count,
                "every identifier call gives a literal name")
    }

    /// For an opened session, the shell's port gives `experience.r02-g21.binary-gardens.<name>` for every name, and
    /// the 56 identifiers are unique.
    @Test func thePortPrefixesEveryName() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: BinaryGardensTest.Shell = try await BinaryGardensTest.open(session, seed: 0)
        var identifiers: [String] = []
        for name in BinaryGardensControls.identifierNames {
            let identifier: String = shell.port.identifier(name)
            #expect(identifier.hasPrefix(Self.prefix), "\(identifier)")
            #expect(identifier == Self.prefix + name, "\(name)")
            identifiers.append(identifier)
        }
        #expect(identifiers.count == Self.count)
        #expect(Set(identifiers).count == identifiers.count, "every identifier is unique")
    }
}
#endif
