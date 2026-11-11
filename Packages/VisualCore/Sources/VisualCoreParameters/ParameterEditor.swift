// ParameterEditor.swift — editing state for a parameter schema: set by value or slider position, reset to a baseline,
// modified flags and unit formatting (feature 013 T-A01-202; FR-A01-206; contract specs/013-gas-p02-scene-controls/contracts/api.md).
import Foundation

/// Values for every parameter of a schema, always finite and in range, plus the baseline that reset returns to.
public struct ParameterEditor: Sendable, Equatable {
    /// The schema being edited.
    public let schema: ParameterSchema
    /// Current values (every schema name).
    public private(set) var values: [String: Double]
    /// Values that `reset` returns to.
    public private(set) var baseline: [String: Double]

    /// Resolves `values` through the schema; they become both the current values and the baseline.
    public init(schema: ParameterSchema, values: [String: Double] = [:]) throws(ParameterError) {
        self.schema = schema
        let resolved = try schema.resolve(values).values
        self.values = resolved
        baseline = resolved
    }

    /// Sets `name` to `value` clamped to its range; false for an unknown name or a non-finite value.
    @discardableResult
    public mutating func set(_ name: String, to value: Double) -> Bool {
        guard let d = schema.definition(name), value.isFinite else { return false }
        values[name] = d.clamped(value)
        return true
    }

    /// Sets `name` from a slider position (clamped to 0…1; non-finite counts as 0); false for an unknown name.
    @discardableResult
    public mutating func set(_ name: String, normalized t: Double) -> Bool {
        guard let d = schema.definition(name) else { return false }
        values[name] = d.value(normalized: t.isFinite ? t : 0)
        return true
    }

    /// Slider position (0…1) of `name`; 0 for an unknown name.
    public func normalized(_ name: String) -> Double {
        guard let d = schema.definition(name), let v = values[name] else { return 0 }
        return d.normalized(v)
    }

    /// Whether `name` differs from its baseline.
    public func isModified(_ name: String) -> Bool { values[name] != baseline[name] }

    /// Names that differ from the baseline, in schema order.
    public var modifiedNames: [String] { schema.definitions.map(\.name).filter(isModified) }

    /// Returns `name` to its baseline (a no-op when unchanged or unknown).
    public mutating func reset(_ name: String) {
        if let b = baseline[name] { values[name] = b }
    }

    /// Returns every parameter to its baseline.
    public mutating func resetAll() { values = baseline }

    /// Replaces the baseline and the current values with `values` resolved through the schema.
    public mutating func rebase(_ values: [String: Double]) throws(ParameterError) {
        let resolved = try schema.resolve(values).values
        self.values = resolved
        baseline = resolved
    }

    /// `name`'s value with 3 significant digits and its unit (for example "4.5 ×", "600 /s"); empty for unknown names.
    public func formatted(_ name: String) -> String {
        guard let d = schema.definition(name), let v = values[name] else { return "" }
        let number = String(format: "%.3g", v)
        return d.unit.isEmpty ? number : "\(number) \(d.unit)"
    }
}
