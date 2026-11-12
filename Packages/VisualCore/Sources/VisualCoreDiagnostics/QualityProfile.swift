// QualityProfile — feature 192 T-U06-004 (UA-F06; FR-U06-001 to FR-U06-004, FR-U06-006). An experience declares its
// quality levels as a profile: 1 to 8 named levels, each with four budgets (resolution share, element share,
// iteration share, effect passes). Level 0 is the best and no budget rises from one level to the next. A profile is
// checked when it is created and nothing is repaired: an invalid declaration is refused with the exact reason.
// `QualityPolicy` and the governor choose the level; the profile says what the level means.

import Foundation

/// One quality level of an experience: a name and four budgets.
///
/// The initializer stores the values as given. The rules (name length, ranges, no rising budget) are checked by
/// `QualityProfile.init(levels:)`.
public struct QualityLevel: Sendable, Equatable {
    /// The name of the level (1 to 40 characters, unique in its profile).
    public let name: String
    /// The share of the full drawable resolution (finite, more than 0, at most 1).
    public let resolutionShare: Double
    /// The share of a requested element count, such as particles or instances (finite, 0 to 1).
    public let elementShare: Double
    /// The share of a requested iteration count, such as solver or ray-march steps (finite, 0 to 1).
    public let iterationShare: Double
    /// The number of extra effect passes (0 to 64).
    public let effectPasses: Int

    /// Creates a level without checking it; the defaults describe full quality with no effect pass.
    public init(name: String, resolutionShare: Double = 1, elementShare: Double = 1,
                iterationShare: Double = 1, effectPasses: Int = 0) {
        self.name = name
        self.resolutionShare = resolutionShare
        self.elementShare = elementShare
        self.iterationShare = iterationShare
        self.effectPasses = effectPasses
    }
}

/// The four budgets of a quality level, used to name the budget that broke a rule.
public enum QualityBudget: String, Sendable, CaseIterable {
    /// The share of the full drawable resolution.
    case resolutionShare
    /// The share of a requested element count.
    case elementShare
    /// The share of a requested iteration count.
    case iterationShare
    /// The number of extra effect passes.
    case effectPasses
}

/// The reason why a list of levels is not a valid `QualityProfile`. `level` is the index of the refused level.
public enum QualityProfileError: Error, Sendable, Equatable {
    /// The list of levels is empty.
    case noLevel
    /// The list has more than `QualityProfile.maxLevels` levels; the value is the number of levels given.
    case tooManyLevels(Int)
    /// The name of the level is empty or longer than `QualityProfile.maxNameLength` characters.
    case invalidName(level: Int)
    /// The name of the level is equal to the name of an earlier level.
    case duplicateName(level: Int)
    /// The budget of the level is not finite or lies outside its allowed range.
    case outOfRange(level: Int, budget: QualityBudget)
    /// The budget of the level is larger than the same budget of the level before it.
    case rising(level: Int, budget: QualityBudget)
}

/// The checked quality declaration of an experience: 1 to 8 levels, level 0 the best, no budget rising.
public struct QualityProfile: Sendable, Equatable {
    /// The largest number of levels in a profile.
    public static let maxLevels = 8
    /// The largest number of characters in a level name.
    public static let maxNameLength = 40
    /// The largest number of effect passes of a level.
    public static let maxEffectPasses = 64

    /// The levels, from the best (index 0) to the cheapest.
    public let levels: [QualityLevel]

    /// Creates a profile, or throws the first rule that `levels` breaks. Nothing is repaired.
    ///
    /// Order of the checks: no level; too many levels; then for each level in order its name (empty or too long,
    /// then duplicate), its four budgets in the order of `QualityBudget.allCases` (range), and, from the second
    /// level on, the four budgets in the same order against the level before it (rising).
    public init(levels: [QualityLevel]) throws(QualityProfileError) {
        guard !levels.isEmpty else { throw .noLevel }
        guard levels.count <= Self.maxLevels else { throw .tooManyLevels(levels.count) }
        for (index, level) in levels.enumerated() {
            guard !level.name.isEmpty, level.name.count <= Self.maxNameLength else {
                throw .invalidName(level: index)
            }
            guard !levels[..<index].contains(where: { $0.name == level.name }) else {
                throw .duplicateName(level: index)
            }
            guard level.resolutionShare.isFinite, level.resolutionShare > 0, level.resolutionShare <= 1 else {
                throw .outOfRange(level: index, budget: .resolutionShare)
            }
            guard level.elementShare.isFinite, level.elementShare >= 0, level.elementShare <= 1 else {
                throw .outOfRange(level: index, budget: .elementShare)
            }
            guard level.iterationShare.isFinite, level.iterationShare >= 0, level.iterationShare <= 1 else {
                throw .outOfRange(level: index, budget: .iterationShare)
            }
            guard level.effectPasses >= 0, level.effectPasses <= Self.maxEffectPasses else {
                throw .outOfRange(level: index, budget: .effectPasses)
            }
            if index >= 1 {
                let previous = levels[index - 1]
                guard level.resolutionShare <= previous.resolutionShare else {
                    throw .rising(level: index, budget: .resolutionShare)
                }
                guard level.elementShare <= previous.elementShare else {
                    throw .rising(level: index, budget: .elementShare)
                }
                guard level.iterationShare <= previous.iterationShare else {
                    throw .rising(level: index, budget: .iterationShare)
                }
                guard level.effectPasses <= previous.effectPasses else {
                    throw .rising(level: index, budget: .effectPasses)
                }
            }
        }
        self.levels = levels
    }

    /// Stores levels that are valid by construction (used by `uniform(levels:)` only).
    private init(unchecked levels: [QualityLevel]) {
        self.levels = levels
    }

    /// A profile of `levels` equal levels (clamped to 1…8) named `level-0`, `level-1`, …, with every share 1 and
    /// no effect pass.
    public static func uniform(levels: Int) -> QualityProfile {
        let count = min(max(levels, 1), maxLevels)
        return QualityProfile(unchecked: (0..<count).map { QualityLevel(name: "level-\($0)") })
    }

    /// The profile of one full-quality level, for an experience that declares no quality levels.
    public static let single: QualityProfile = uniform(levels: 1)

    /// The number of levels (1 to 8).
    public var count: Int { levels.count }

    /// The names of the levels, from the best to the cheapest.
    public var names: [String] { levels.map(\.name) }

    /// The level at `index`, clamped to the first and the last level.
    public func level(_ index: Int) -> QualityLevel {
        levels[min(max(index, 0), levels.count - 1)]
    }

    /// The element count for a `requested` count at `level` (clamped):
    /// `min(requested, max(minimum, ⌊requested × elementShare⌋))`, and 0 when `requested` is 0 or less.
    /// A negative `minimum` counts as 0.
    public func elements(requested: Int, level: Int, minimum: Int = 0) -> Int {
        Self.scaled(requested: requested, share: self.level(level).elementShare, minimum: minimum)
    }

    /// The iteration count for a `requested` count at `level` (clamped):
    /// `min(requested, max(minimum, ⌊requested × iterationShare⌋))`, and 0 when `requested` is 0 or less.
    /// A negative `minimum` counts as 0.
    public func iterations(requested: Int, level: Int, minimum: Int = 1) -> Int {
        Self.scaled(requested: requested, share: self.level(level).iterationShare, minimum: minimum)
    }

    private static func scaled(requested: Int, share: Double, minimum: Int) -> Int {
        guard requested > 0 else { return 0 }
        let scaled = Int((Double(requested) * share).rounded(.down))
        return min(requested, max(max(minimum, 0), scaled))
    }
}

/// Compares a quality profile with what the experience declares elsewhere (its tier count and the catalog).
public enum QualityDeclaration {
    /// The differences between `profile` and the declaration, one text each; empty when nothing differs.
    ///
    /// The count of the profile must equal `tierCount` (a tier count below 1 counts as 1). The names must equal
    /// `catalogNames` in the same order; `nil` catalog names are not compared.
    public static func problems(profile: QualityProfile, tierCount: Int, catalogNames: [String]?) -> [String] {
        var problems: [String] = []
        if profile.count != max(tierCount, 1) {
            problems.append("the profile has \(profile.count) levels and the experience declares \(tierCount) tiers")
        }
        if let catalogNames, catalogNames != profile.names {
            problems.append("the profile names \(profile.names) differ from the catalog names \(catalogNames)")
        }
        return problems
    }
}
