// MushroomWeatherIdentifierTests — feature 499 (R02-G20-09) T-R02G2009-003 (FR-R02G2009-001; clarification Q1),
// modelled on feature 489 (`MicroscopicAuroraIdentifierTests.swift`). The control panel's accessibility identifiers:
// `MushroomWeatherControls.identifierNames` holds exactly the 53 names of the clarification (the 52 names the panel
// gave, the vent toggles counted as `vent-0` … `vent-5`, plus `explanation`), each once (the set is compared, and every
// name is counted); the panel's source gives each fixed name through `port.identifier("<name>")` exactly once, the vent
// toggles' names through the one `port.identifier("vent-\(index)")` for vent index 0 … 5 (at most six vents, as
// `MushroomWeatherLevel.ventCounts` allows), and no other name (the failure explanation is `explanation`, the short
// failure line `failure`); and for a session opened through the one app's session host, the shell's port turns every
// name into `experience.r02-g20.mushroom-weather.<name>`, and the 53 identifiers are unique. The
// `.accessibilityIdentifier` modifiers in the view body are not inspectable from a unit test (SwiftUI's accessibility
// tree), so the source is read (`#filePath`, as the accessibility tests do); the UI tests of the gate find the
// identifiers on screen. Synthetic data, explicit types, plain loops, no sleep, no wall-clock assertion; each test well
// under 10 s. iOS only, as the target.
#if os(iOS)
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import MushroomWeatherExperience
import MushroomWeatherCore

@MainActor
@Suite(.serialized) struct MushroomWeatherIdentifierTests {
    /// The identifier names of the clarification, in the order the contract lists them, with `explanation` after
    /// `failure` and the vent toggles as `vent-0` … `vent-5`.
    static let expectedNames: [String] = ["slot", "slot-minus", "slot-plus", "selection", "pods-detail", "site",
                                          "site-minus", "site-plus", "place", "remove", "vent-0", "vent-1", "vent-2",
                                          "vent-3", "vent-4", "vent-5", "moon", "moon-minus", "moon-plus", "moon-set",
                                          "reset-view", "cycle", "cycle-minus", "cycle-plus", "cycle-detail", "run",
                                          "undo", "redo", "next-level", "dismiss-tutorial", "hint", "campaign", "daily",
                                          "practice", "level-picker", "play-level", "replay", "replay-step",
                                          "replay-stop", "sound", "actions", "status", "failure", "explanation",
                                          "progress", "summary", "message", "tutorial", "hint-text", "band", "stars",
                                          "goal", "replay-position"]

    /// The identifier prefix of the experience `r02-g20.mushroom-weather`.
    static let prefix: String = "experience.r02-g20.mushroom-weather."

    /// The prefix of the vent toggles' names (`vent-<index>`).
    static let ventPrefix: String = "vent-"

    /// The vent toggles' identifier call as the panel's source writes it.
    static let ventCall: String = "port.identifier(\"vent-\\(index)\")"

    /// The panel's source text (`Experience/MushroomWeatherControls.swift`, beside this test's folder).
    static func panelSource() throws -> String {
        let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let file: URL = tests.deletingLastPathComponent().appendingPathComponent("Experience")
            .appendingPathComponent("MushroomWeatherControls.swift")
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

    /// The listed names the panel gives literally (every name but the vent toggles').
    static func fixedNames() -> [String] {
        var names: [String] = []
        for name in MushroomWeatherControls.identifierNames where !name.hasPrefix(ventPrefix) { names.append(name) }
        return names
    }

    /// `identifierNames` is exactly the 53 names of the clarification, each listed once, in the contract's order.
    @Test func theNamesAreTheClarifiedFiftyThree() {
        let names: [String] = MushroomWeatherControls.identifierNames
        #expect(Self.expectedNames.count == 53)
        #expect(Set(Self.expectedNames).count == 53, "the clarified names are unique")
        #expect(names.count == 53)
        #expect(Set(names).count == names.count, "every name is unique")
        #expect(Set(names) == Set(Self.expectedNames))
        #expect(names == Self.expectedNames, "the contract's order")
        for name in Self.expectedNames {
            var count: Int = 0
            for candidate in names where candidate == name { count += 1 }
            #expect(count == 1, "\(name)")
        }
    }

    /// The vent toggles' names are `vent-0` … `vent-(n − 1)` for the most vents a level may hold (six), labelled
    /// Vent 1 … 6.
    @Test func theVentNamesCoverEveryVent() {
        let most: Int = MushroomWeatherLevel.ventCounts.upperBound
        #expect(most == 6)
        var vents: [String] = []
        for name in MushroomWeatherControls.identifierNames where name.hasPrefix(Self.ventPrefix) { vents.append(name) }
        var expected: [String] = []
        for index in 0..<most { expected.append(Self.ventPrefix + String(index)) }
        #expect(vents == expected)
    }

    /// The failure explanation has its own identifier `explanation`, apart from the failure line's `failure`, and the
    /// panel's source gives each of the two exactly once.
    @Test func theExplanationHasItsOwnName() throws {
        let names: [String] = MushroomWeatherControls.identifierNames
        #expect(names.contains("explanation"))
        #expect(names.contains("failure"))
        let source: String = try Self.panelSource()
        #expect(Self.occurrences(of: "port.identifier(\"failure\")", in: source) == 1, "the failure line only")
        #expect(Self.occurrences(of: "port.identifier(\"explanation\")", in: source) == 1, "the explanation")
    }

    /// Every name is a non-empty, lower-case, hyphenated token (digits only in the vent index), so the identifier
    /// stays a plain dotted path.
    @Test func theNamesAreLowerCaseTokens() {
        let allowed: Set<Character> = Set("abcdefghijklmnopqrstuvwxyz0123456789-")
        for name in MushroomWeatherControls.identifierNames {
            #expect(!name.isEmpty)
            var plain: Bool = true
            for character in name where !allowed.contains(character) { plain = false }
            #expect(plain, "\(name)")
            #expect(!name.hasPrefix("-") && !name.hasSuffix("-"), "\(name)")
            #expect(!name.contains("--"), "\(name)")
            if !name.hasPrefix(Self.ventPrefix) {
                var digits: Bool = false
                for character in name where character.isNumber { digits = true }
                #expect(!digits, "\(name)")
            }
        }
    }

    /// The panel's source gives every fixed listed name through `port.identifier("<name>")` exactly once, the vent
    /// toggles' names through the one `port.identifier("vent-\(index)")`, and no identifier that is not listed.
    @Test func thePanelUsesEveryNameOnce() throws {
        let source: String = try Self.panelSource()
        let fixed: [String] = Self.fixedNames()
        #expect(fixed.count == 47)
        for name in fixed {
            let call: String = "port.identifier(\"\(name)\")"
            #expect(Self.occurrences(of: call, in: source) == 1, "\(name)")
        }
        #expect(Self.occurrences(of: Self.ventCall, in: source) == 1, "the vent toggles' one identifier call")
        #expect(Self.occurrences(of: "port.identifier(\"", in: source) == fixed.count + 1,
                "every identifier the panel gives is listed")
    }

    /// For an opened session, the shell's port gives `experience.r02-g20.mushroom-weather.<name>` for every name, and
    /// the 53 identifiers are unique.
    @Test func thePortPrefixesEveryName() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: MushroomWeatherTest.Shell = try await MushroomWeatherTest.open(session, seed: 0)
        var identifiers: [String] = []
        for name in MushroomWeatherControls.identifierNames {
            let identifier: String = shell.port.identifier(name)
            #expect(identifier.hasPrefix(Self.prefix), "\(identifier)")
            #expect(identifier == Self.prefix + name, "\(name)")
            identifiers.append(identifier)
        }
        #expect(identifiers.count == 53)
        #expect(Set(identifiers).count == identifiers.count, "every identifier is unique")
    }
}
#endif
