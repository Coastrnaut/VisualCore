// ContainerInventoryTests — feature 191 T-U05-008 (UA-F05, US6; FR-U05-060, FR-U05-061): rules match whole paths
// and keys; listed items give nothing and each stray item gives `file:<path>` or `key:<name>`; an invalid pattern,
// a system rule without an origin and a rule without a writer are refused. The rule set is modelled on
// data-model.md section 5 and written out here, so the test does not take it from the app.
import Foundation
import Testing
import VisualCoreExperience

@Suite struct ContainerInventoryTests {
    private static let folder = "Library/Application Support/Experiences/[a-z0-9.-]+"

    private static let stateRule = InventoryRule(kind: .file, pattern: folder + "/state\\.json",
                                                 writer: "the app: the saved state")
    private static let quarantineRule = InventoryRule(kind: .file, pattern: folder + "/quarantine-[0-9]+\\.json",
                                                      writer: "the app: quarantined copies")
    private static let handleFileRule = InventoryRule(kind: .file, pattern: folder + "/[A-Za-z0-9._-]+",
                                                      writer: "the experience, through its handle")
    private static let defaultsRule = InventoryRule(kind: .file, pattern: "Library/Preferences/.+\\.plist",
                                                    writer: "the system: the defaults domain of the app",
                                                    system: true, origin: "observed on a simulator run")
    private static let preferencesRule = InventoryRule(kind: .key, pattern: "vc\\.shell\\.preferences",
                                                       writer: "the app: the session state")
    private static let handleKeyRule = InventoryRule(kind: .key, pattern: "exp\\.[a-z0-9.-]+\\.[A-Za-z0-9._-]+",
                                                     writer: "an experience, through its handle")

    private static let rules = [stateRule, quarantineRule, handleFileRule, defaultsRule, preferencesRule,
                                handleKeyRule]

    private static func inventory() throws -> ContainerInventory { try ContainerInventory(rules: rules) }

    /// The error `ContainerInventory(rules:)` throws for `rules`, or nil when it accepts them.
    private static func refusal(_ rules: [InventoryRule]) -> InventoryError? {
        do {
            _ = try ContainerInventory(rules: rules)
            return nil
        } catch {
            return error
        }
    }

    private static let listedFiles = [
        "Library/Application Support/Experiences/a01.e1/state.json",
        "Library/Application Support/Experiences/r02-g01.e26/quarantine-3.json",
        "Library/Application Support/Experiences/a01.e1/best-run.bin",
        "Library/Preferences/com.example.app.plist",
    ]
    private static let listedKeys = ["vc.shell.preferences", "exp.a01.e1.high-score", "exp.r02-g01.e26.level_2"]

    @Test func theRulesAreKeptAsGiven() throws {
        let inventory = try Self.inventory()
        #expect(inventory.rules == Self.rules)
    }

    @Test func listedFilesAndKeysGiveNothing() throws {
        let inventory = try Self.inventory()
        let found = inventory.unlisted(files: Self.listedFiles, keys: Self.listedKeys)
        #expect(found == [])
        let nothing = inventory.unlisted(files: [], keys: [])
        #expect(nothing == [])
    }

    @Test func aStrayFileIsNamedWithItsPath() throws {
        let inventory = try Self.inventory()
        let found = inventory.unlisted(files: Self.listedFiles + ["Library/Application Support/stray.txt"],
                                       keys: Self.listedKeys)
        #expect(found == ["file:Library/Application Support/stray.txt"])
    }

    @Test func aStrayKeyIsNamedWithItsName() throws {
        let inventory = try Self.inventory()
        let found = inventory.unlisted(files: Self.listedFiles, keys: Self.listedKeys + ["stray.key"])
        #expect(found == ["key:stray.key"])
    }

    @Test func aPatternMustMatchTheWholeText() throws {
        let inventory = try Self.inventory()
        let found = inventory.unlisted(
            files: ["xLibrary/Application Support/Experiences/a01.x/state.json",
                    "Library/Application Support/Experiences/a01.x/state.json/more",
                    "Library/Application Support/Experiences/a01.x/sub/state.json"],
            keys: ["vc.shell.preferences.extra", "xvc.shell.preferences", "vcxshellxpreferences"])
        #expect(found == [
            "file:Library/Application Support/Experiences/a01.x/state.json/more",
            "file:Library/Application Support/Experiences/a01.x/sub/state.json",
            "file:xLibrary/Application Support/Experiences/a01.x/state.json",
            "key:vc.shell.preferences.extra",
            "key:vcxshellxpreferences",
            "key:xvc.shell.preferences",
        ])
    }

    @Test func anAlternationMatchesWholeTextsOnly() throws {
        let inventory = try ContainerInventory(rules: [InventoryRule(kind: .key, pattern: "a|ab", writer: "test")])
        let found = inventory.unlisted(files: [], keys: ["a", "ab", "abc", "b"])
        #expect(found == ["key:abc", "key:b"])
    }

    @Test func aFileRuleDoesNotCoverAKeyAndTheOtherWayRound() throws {
        let inventory = try Self.inventory()
        let found = inventory.unlisted(files: ["vc.shell.preferences"],
                                       keys: ["Library/Preferences/com.example.app.plist"])
        #expect(found == ["file:vc.shell.preferences", "key:Library/Preferences/com.example.app.plist"])
    }

    @Test func duplicatesGiveOneEntryAndTheResultIsSorted() throws {
        let inventory = try Self.inventory()
        let found = inventory.unlisted(files: ["z.txt", "a.txt", "z.txt"], keys: ["stray.b", "stray.a", "stray.b"])
        #expect(found == ["file:a.txt", "file:z.txt", "key:stray.a", "key:stray.b"])
    }

    @Test func theFirstMatchingRuleIsReturned() throws {
        let inventory = try Self.inventory()
        let state = inventory.rule(forFile: "Library/Application Support/Experiences/a01.e1/state.json")
        #expect(state == Self.stateRule)
        let quarantine = inventory.rule(forFile: "Library/Application Support/Experiences/a01.e1/quarantine-12.json")
        #expect(quarantine == Self.quarantineRule)
        let other = inventory.rule(forFile: "Library/Application Support/Experiences/a01.e1/notes.txt")
        #expect(other == Self.handleFileRule)
        let system = inventory.rule(forFile: "Library/Preferences/com.example.app.plist")
        #expect(system == Self.defaultsRule)
        #expect(system?.system == true)
        let noFile = inventory.rule(forFile: "Documents/stray.txt")
        #expect(noFile == nil)
        let preferences = inventory.rule(forKey: "vc.shell.preferences")
        #expect(preferences == Self.preferencesRule)
        let handle = inventory.rule(forKey: "exp.a01.e1.high-score")
        #expect(handle == Self.handleKeyRule)
        let noKey = inventory.rule(forKey: "stray.key")
        #expect(noKey == nil)
        let keyAsFile = inventory.rule(forFile: "vc.shell.preferences")
        #expect(keyAsFile == nil)
    }

    @Test func anInvalidPatternIsRefused() {
        let bad = InventoryRule(kind: .file, pattern: "(", writer: "test")
        let error = Self.refusal([Self.stateRule, bad])
        #expect(error == .invalidPattern("("))
        let unbalanced = Self.refusal([InventoryRule(kind: .key, pattern: ")(", writer: "test")])
        #expect(unbalanced == .invalidPattern(")("))
    }

    @Test func aSystemRuleWithoutAnOriginIsRefused() {
        let pattern = "Library/Caches/.+"
        for origin in [nil, "", "  \n\t"] as [String?] {
            let rule = InventoryRule(kind: .file, pattern: pattern, writer: "the system", system: true,
                                     origin: origin)
            let error = Self.refusal([rule])
            #expect(error == .systemRuleWithoutOrigin(pattern))
        }
        let withOrigin = InventoryRule(kind: .file, pattern: pattern, writer: "the system", system: true,
                                       origin: "observed")
        let accepted = Self.refusal([withOrigin])
        #expect(accepted == nil)
    }

    @Test func anEmptyWriterIsRefused() {
        let error = Self.refusal([InventoryRule(kind: .key, pattern: "some\\.key", writer: "")])
        #expect(error == .emptyWriter("some\\.key"))
    }

    @Test func aRuleOfTheAppNeedsNoOrigin() {
        let rule = InventoryRule(kind: .key, pattern: "some\\.key", writer: "the app")
        #expect(rule.system == false)
        #expect(rule.origin == nil)
        #expect(rule.kind == .key)
        #expect(InventoryRule.Kind.file.rawValue == "file")
        #expect(InventoryRule.Kind.key.rawValue == "key")
        let accepted = Self.refusal([rule])
        #expect(accepted == nil)
    }

    @Test func anEmptyRuleSetListsNothing() throws {
        let inventory = try ContainerInventory(rules: [])
        let found = inventory.unlisted(files: ["a"], keys: ["b"])
        #expect(found == ["file:a", "key:b"])
    }
}
