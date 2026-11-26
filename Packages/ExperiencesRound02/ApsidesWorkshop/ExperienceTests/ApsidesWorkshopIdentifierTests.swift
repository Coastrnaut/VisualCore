// ApsidesWorkshopIdentifierTests — feature 479 (R02-G18-09) T-R02G1809-003 (FR-R02G1809-001; clarification Q1),
// modelled on feature 469 (`CelestialEclipseLabIdentifierTests.swift`). The control panel's accessibility identifiers:
// `ApsidesWorkshopControls.identifierNames` holds exactly the 46 names of the clarification, each once (the set is
// compared, and every name is counted); the panel's source gives each name through `port.identifier("<name>")`
// exactly once and no other name (the failure explanation is `explanation`, the failure line `failure`); and for a
// session opened through the one app's session host, the shell's port turns every name into
// `experience.r02-g18.apsides-workshop.<name>`, and the 46 identifiers are unique. The `.accessibilityIdentifier`
// modifiers in the view body are not inspectable from a unit test (SwiftUI's accessibility tree), so the source is
// read (`#filePath`, as the Core's shader source test does); the UI tests of the gate find the identifiers on screen.
// Synthetic data, explicit types, plain loops, no sleep, no wall-clock assertion; each test well under 10 s. iOS only,
// as the target.
#if os(iOS)
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import ApsidesWorkshopExperience
import ApsidesWorkshopCore

@MainActor
@Suite(.serialized) struct ApsidesWorkshopIdentifierTests {
    /// The identifier names of the clarification, in the order the clarification lists them.
    static let expectedNames: [String] = ["eccentricity", "eccentricity-minus", "eccentricity-plus", "direction",
                                          "direction-minus", "direction-plus", "size", "size-minus", "size-plus",
                                          "orbit-detail", "set-periapsis", "set-size", "reset-view",
                                          "pending-reason", "tick", "tick-minus", "tick-plus", "tick-detail", "play",
                                          "undo", "redo", "next-level", "dismiss-tutorial", "hint", "campaign",
                                          "daily", "practice", "level-picker", "play-level", "replay", "replay-step",
                                          "replay-stop", "sound", "actions", "status", "failure", "explanation",
                                          "progress", "summary", "message", "tutorial", "hint-text", "band", "stars",
                                          "goal", "replay-position"]

    /// The identifier prefix of the experience `r02-g18.apsides-workshop`.
    static let prefix: String = "experience.r02-g18.apsides-workshop."

    /// The panel's source text (`Experience/ApsidesWorkshopControls.swift`, beside this test's folder).
    static func panelSource() throws -> String {
        let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let file: URL = tests.deletingLastPathComponent().appendingPathComponent("Experience")
            .appendingPathComponent("ApsidesWorkshopControls.swift")
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

    /// `identifierNames` is exactly the 46 names of the clarification, each used once, in the clarified order.
    @Test func theNamesAreTheClarifiedFortySix() {
        let names: [String] = ApsidesWorkshopControls.identifierNames
        #expect(Self.expectedNames.count == 46)
        #expect(Set(Self.expectedNames).count == 46, "the clarified names are unique")
        #expect(names.count == 46)
        #expect(Set(names).count == names.count, "every name is unique")
        #expect(Set(names) == Set(Self.expectedNames))
        #expect(names == Self.expectedNames, "the clarified order")
        for name in Self.expectedNames {
            var count: Int = 0
            for candidate in names where candidate == name { count += 1 }
            #expect(count == 1, "\(name)")
        }
    }

    /// The failure explanation has its own identifier `explanation`, apart from the failure line's `failure`.
    @Test func theExplanationHasItsOwnName() {
        let names: [String] = ApsidesWorkshopControls.identifierNames
        #expect(names.contains("explanation"))
        #expect(names.contains("failure"))
    }

    /// Every name is a non-empty, lower-case, hyphenated token, so the identifier stays a plain dotted path.
    @Test func theNamesAreLowerCaseTokens() {
        let allowed: Set<Character> = Set("abcdefghijklmnopqrstuvwxyz-")
        for name in ApsidesWorkshopControls.identifierNames {
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
        for name in ApsidesWorkshopControls.identifierNames {
            let call: String = "port.identifier(\"\(name)\")"
            #expect(Self.occurrences(of: call, in: source) == 1, "\(name)")
        }
        #expect(Self.occurrences(of: "port.identifier(\"", in: source)
                    == ApsidesWorkshopControls.identifierNames.count,
                "every identifier the panel gives is listed")
    }

    /// For an opened session, the shell's port gives `experience.r02-g18.apsides-workshop.<name>` for every name, and
    /// the 46 identifiers are unique.
    @Test func thePortPrefixesEveryName() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: ApsidesWorkshopTest.Shell = try await ApsidesWorkshopTest.open(session, seed: 0)
        var identifiers: [String] = []
        for name in ApsidesWorkshopControls.identifierNames {
            let identifier: String = shell.port.identifier(name)
            #expect(identifier.hasPrefix(Self.prefix), "\(identifier)")
            #expect(identifier == Self.prefix + name, "\(name)")
            identifiers.append(identifier)
        }
        #expect(identifiers.count == 46)
        #expect(Set(identifiers).count == identifiers.count, "every identifier is unique")
    }
}
#endif
