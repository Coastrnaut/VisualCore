// ShaderVariantSet.swift — bounded shader variant switches and their combinations (feature 206 T-R02F06-004;
// FR-R02F06-003, clarification Q3, research R4). Contract:
// specs/206-shader-domain-specific-parameters-and-gl-es-safe-compilation/contracts/api.md.
//
// Up to 6 switches, 1–8 unique values each, at most 64 combinations. Combinations are enumerated in lexicographic
// order of switch name, then value index (the first switch by name varies slowest); a combination's key is
// `name=value` pairs joined by `;` in switch-name order.

/// Why a variant switch or set was refused.
public enum VariantError: Error, Equatable, Sendable {
    /// The named switch has no values.
    case noValues(String)
    /// The named switch has more than 8 values.
    case tooManyValues(String)
    /// The named switch lists the value twice (switch name, value).
    case duplicateValue(String, String)
    /// Two switches share the name.
    case duplicateSwitch(String)
    /// More than 6 switches; the associated value is the count given.
    case tooManySwitches(Int)
    /// More than 64 combinations; the associated value is the product of the value counts.
    case tooManyCombinations(Int)
    /// A switch name or value breaks the define rules of `DefineSet`.
    case define(DefineError)
}

/// One define name and its closed list of allowed values.
public struct VariantSwitch: Equatable, Sendable {
    /// The define name.
    public let name: String
    /// The allowed values, in the order given (the value index order of enumeration).
    public let values: [String]

    /// Validates `name` and `values` as a `DefineSet` would; 1–8 unique values.
    public init(name: String, values: [String]) throws(VariantError) {
        do throws(DefineError) {
            try DefineSet.validate(name: name, value: "")
            for value in values { try DefineSet.validate(name: name, value: value) }
        } catch { throw .define(error) }
        guard !values.isEmpty else { throw .noValues(name) }
        guard values.count <= ShaderVariantSet.maxValuesPerSwitch else { throw .tooManyValues(name) }
        var seen = Set<String>()
        for value in values where !seen.insert(value).inserted { throw .duplicateValue(name, value) }
        self.name = name
        self.values = values
    }
}

/// One combination of switch values: its stable key and the defines it compiles with.
public struct VariantCombination: Equatable, Sendable {
    /// `name=value` pairs joined by `;` in switch-name order; empty for a set without switches.
    public let key: String
    /// The combination's defines, one per switch.
    public let defines: DefineSet
}

/// A bounded set of variant switches and every combination of their values, in a stable order.
public struct ShaderVariantSet: Equatable, Sendable {
    /// Maximum number of switches (6).
    public static let maxSwitches = 6
    /// Maximum number of values per switch (8).
    public static let maxValuesPerSwitch = 8
    /// Maximum number of combinations (64, the program cache size).
    public static let maxCombinations = 64

    /// The switches, sorted by name.
    public let switches: [VariantSwitch]
    /// Every combination, in lexicographic order of switch name then value index.
    public let combinations: [VariantCombination]

    /// Validates the bounds and enumerates the combinations.
    public init(_ switches: [VariantSwitch]) throws(VariantError) {
        guard switches.count <= Self.maxSwitches else { throw .tooManySwitches(switches.count) }
        var names = Set<String>()
        for item in switches where !names.insert(item.name).inserted { throw .duplicateSwitch(item.name) }
        let sorted = switches.sorted { $0.name < $1.name }
        let total = sorted.reduce(1) { $0 * $1.values.count }
        guard total <= Self.maxCombinations else { throw .tooManyCombinations(total) }
        var result: [VariantCombination] = []
        result.reserveCapacity(total)
        var indices = Array(repeating: 0, count: sorted.count)
        for _ in 0..<total {
            var defines: [String: String] = [:]
            var pairs: [String] = []
            for (position, item) in sorted.enumerated() {
                let value = item.values[indices[position]]
                defines[item.name] = value
                pairs.append("\(item.name)=\(value)")
            }
            result.append(VariantCombination(key: pairs.joined(separator: ";"), defines: DefineSet(validated: defines)))
            // Odometer step: the last switch by name varies fastest.
            var position = sorted.count - 1
            while position >= 0 {
                indices[position] += 1
                if indices[position] < sorted[position].values.count { break }
                indices[position] = 0
                position -= 1
            }
        }
        self.switches = sorted
        self.combinations = result
    }
}
