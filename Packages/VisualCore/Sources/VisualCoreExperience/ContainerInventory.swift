// ContainerInventory — feature 191 T-U05-009 (UA-F05; FR-U05-060, FR-U05-061; research R8). The allow-list of the
// files and stored values of the app's data container: every rule says what it matches and what writes it, and
// `unlisted(files:keys:)` names everything no rule covers. Pure logic: the caller lists the container.
import Foundation

/// One entry of the allow-list: a pattern for files or for keys, and what writes the matching items.
public struct InventoryRule: Sendable, Equatable {
    /// What a rule matches.
    public enum Kind: String, Sendable {
        /// A file, named by its path relative to the container.
        case file
        /// A stored value, named by its key.
        case key
    }

    /// Whether the rule matches files or keys.
    public let kind: Kind
    /// A regular expression that must match the whole relative path or the whole key.
    public let pattern: String
    /// What writes the matching items, as text for people. Must not be empty.
    public let writer: String
    /// Whether the system writes the matching items on its own. A system rule needs an `origin`.
    public let system: Bool
    /// For a system rule: the observation that established it. `nil` for a rule of the app.
    public let origin: String?

    /// Creates a rule. Nothing is checked here; `ContainerInventory.init(rules:)` checks it.
    public init(kind: Kind, pattern: String, writer: String, system: Bool = false, origin: String? = nil) {
        self.kind = kind
        self.pattern = pattern
        self.writer = writer
        self.system = system
        self.origin = origin
    }
}

/// Why a rule set was refused. The payload is the pattern of the refused rule.
public enum InventoryError: Error, Sendable, Equatable {
    /// The pattern is not a valid regular expression.
    case invalidPattern(String)
    /// The rule is a system rule and its origin is missing, empty or only white space.
    case systemRuleWithoutOrigin(String)
    /// The rule's writer is empty or only white space.
    case emptyWriter(String)
}

/// The allow-list of a data container: finds the files and keys that no rule covers.
public struct ContainerInventory: Sendable {
    /// The rules, in the order given.
    public let rules: [InventoryRule]

    /// The compiled expression of each rule, at the rule's index.
    private let matchers: [WholeMatcher]

    /// Creates an inventory from `rules`.
    ///
    /// The rules are checked in the order given, and for each rule in this order: the pattern is a valid regular
    /// expression (`invalidPattern`), a system rule has an origin that is not empty or only white space
    /// (`systemRuleWithoutOrigin`), the writer is not empty or only white space (`emptyWriter`). The first
    /// problem is thrown.
    public init(rules: [InventoryRule]) throws(InventoryError) {
        var matchers: [WholeMatcher] = []
        matchers.reserveCapacity(rules.count)
        for rule in rules {
            guard let matcher = WholeMatcher(pattern: rule.pattern) else {
                throw .invalidPattern(rule.pattern)
            }
            if rule.system {
                let origin = (rule.origin ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !origin.isEmpty else { throw .systemRuleWithoutOrigin(rule.pattern) }
            }
            guard !rule.writer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw .emptyWriter(rule.pattern)
            }
            matchers.append(matcher)
        }
        self.rules = rules
        self.matchers = matchers
    }

    /// The items no rule matches wholly: `file:` and the path for a file, `key:` and the key for a stored value.
    ///
    /// The result is sorted, and an item given more than once appears once. Empty when everything is listed.
    public func unlisted(files: [String], keys: [String]) -> [String] {
        var result: Set<String> = []
        for path in files where rule(forFile: path) == nil { result.insert("file:" + path) }
        for key in keys where rule(forKey: key) == nil { result.insert("key:" + key) }
        return result.sorted()
    }

    /// The first file rule whose pattern matches the whole of `path`, or nil.
    public func rule(forFile path: String) -> InventoryRule? {
        firstRule(of: .file, matching: path)
    }

    /// The first key rule whose pattern matches the whole of `key`, or nil.
    public func rule(forKey key: String) -> InventoryRule? {
        firstRule(of: .key, matching: key)
    }

    private func firstRule(of kind: InventoryRule.Kind, matching text: String) -> InventoryRule? {
        for (rule, matcher) in zip(rules, matchers) where rule.kind == kind && matcher.matches(text) {
            return rule
        }
        return nil
    }
}

/// A compiled regular expression that matches whole texts only.
///
/// `@unchecked Sendable`: `NSRegularExpression` is immutable after its creation and documented as safe to use
/// from several threads at once; the only stored value is that expression, and it is never changed.
private struct WholeMatcher: @unchecked Sendable {
    private let expression: NSRegularExpression

    /// Nil when `pattern` is not a valid regular expression.
    init?(pattern: String) {
        // The pattern is compiled on its own first, so that a pattern such as ")(" is not made valid by the
        // group around it. The group and the anchors make an alternation match the whole text or not at all.
        guard (try? NSRegularExpression(pattern: pattern)) != nil,
              let whole = try? NSRegularExpression(pattern: "\\A(?:" + pattern + ")\\z") else { return nil }
        expression = whole
    }

    func matches(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = expression.firstMatch(in: text, options: [], range: range) else { return false }
        return match.range.location == range.location && match.range.length == range.length
    }
}
