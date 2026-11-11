// ParameterSchema.swift — user-adjustable parameters with units, ranges and UI transforms (feature 012 T-A01-102;
// contract specs/012-gas-p01-gallery-domain/contracts/api.md; data model data-model.md).
import Foundation

/// Why a parameter definition, schema, value or palette was rejected.
public enum ParameterError: Error, Equatable, Sendable {
    /// The name does not match `^[a-zA-Z][a-zA-Z0-9_]{0,31}$`.
    case invalidName(String)
    /// Two definitions share a name.
    case duplicate(String)
    /// The range is not finite with minimum < maximum, or a logarithmic range does not start above 0.
    case invalidRange(String)
    /// The default value is outside the range or not finite.
    case defaultOutOfRange(String)
    /// More than `ParameterSchema.maxParameters` definitions.
    case tooMany(Int)
    /// A supplied value is NaN or infinite.
    case nonFinite(String)
    /// A palette id or its stops are invalid.
    case invalidPalette(String)
}

/// How a parameter maps to a 0…1 slider position.
public enum ParameterTransform: String, Codable, Sendable, CaseIterable {
    /// Evenly spaced values.
    case linear
    /// Evenly spaced ratios (requires a minimum above 0).
    case logarithmic
}

/// One user-adjustable parameter: a validated name, unit, finite range, default and slider transform.
public struct ParameterDefinition: Codable, Equatable, Sendable {
    /// Identifier, also the shader uniform suffix (`u_<name>`).
    public let name: String
    /// Short user-facing title.
    public let title: String
    /// Unit shown next to the value (for example "×", "Hz", "px", or empty).
    public let unit: String
    /// Smallest allowed value.
    public let minimum: Double
    /// Largest allowed value.
    public let maximum: Double
    /// Value used when none is supplied.
    public let defaultValue: Double
    /// Slider mapping.
    public let transform: ParameterTransform

    /// Creates a validated definition; throws `ParameterError` for a bad name, range or default.
    public init(name: String, title: String, unit: String = "", range: ClosedRange<Double>, defaultValue: Double,
                transform: ParameterTransform = .linear) throws(ParameterError) {
        guard name.range(of: #"^[a-zA-Z][a-zA-Z0-9_]{0,31}$"#, options: .regularExpression) != nil else { throw .invalidName(name) }
        guard range.lowerBound.isFinite, range.upperBound.isFinite, range.lowerBound < range.upperBound,
              transform == .linear || range.lowerBound > 0 else { throw .invalidRange(name) }
        guard defaultValue.isFinite, range.contains(defaultValue) else { throw .defaultOutOfRange(name) }
        self.name = name
        self.title = title
        self.unit = unit
        minimum = range.lowerBound
        maximum = range.upperBound
        self.defaultValue = defaultValue
        self.transform = transform
    }

    /// Decodes and re-validates a definition.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(name: c.decode(String.self, forKey: .name), title: c.decode(String.self, forKey: .title),
                          unit: c.decode(String.self, forKey: .unit),
                          range: c.decode(Double.self, forKey: .minimum)...max(c.decode(Double.self, forKey: .minimum), c.decode(Double.self, forKey: .maximum)),
                          defaultValue: c.decode(Double.self, forKey: .defaultValue),
                          transform: c.decode(ParameterTransform.self, forKey: .transform))
        } catch let e as ParameterError {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "\(e)"))
        }
    }

    /// The allowed range.
    public var range: ClosedRange<Double> { minimum...maximum }

    /// `value` clamped to the range (finite input only).
    public func clamped(_ value: Double) -> Double { min(max(value, minimum), maximum) }

    /// Slider position 0…1 for `value` (clamped first).
    public func normalized(_ value: Double) -> Double {
        let v = clamped(value)
        switch transform {
        case .linear: return (v - minimum) / (maximum - minimum)
        case .logarithmic: return log(v / minimum) / log(maximum / minimum)
        }
    }

    /// The value at slider position `t` (clamped to 0…1).
    public func value(normalized t: Double) -> Double {
        let t = min(max(t.isFinite ? t : 0, 0), 1)
        switch transform {
        case .linear: return minimum + t * (maximum - minimum)
        case .logarithmic: return clamped(minimum * pow(maximum / minimum, t))
        }
    }
}

/// Resolved values for every parameter of a schema, plus the notes produced while resolving.
public struct ResolvedParameters: Sendable, Equatable {
    /// One finite, in-range value per schema parameter.
    public let values: [String: Double]
    /// Notes about clamped values and dropped names, in parameter order then name order.
    public let warnings: [String]
}

/// An ordered set of parameter definitions with unique names.
public struct ParameterSchema: Sendable, Equatable {
    /// Upper bound on the number of parameters in one schema.
    public static let maxParameters = 64
    /// Definitions in display order.
    public let definitions: [ParameterDefinition]

    /// Creates a schema; throws `.duplicate` for repeated names and `.tooMany` above `maxParameters`.
    public init(_ definitions: [ParameterDefinition]) throws(ParameterError) {
        guard definitions.count <= Self.maxParameters else { throw .tooMany(definitions.count) }
        var seen = Set<String>()
        for d in definitions where !seen.insert(d.name).inserted { throw .duplicate(d.name) }
        self.definitions = definitions
    }

    /// The definition named `name`, if any.
    public func definition(_ name: String) -> ParameterDefinition? { definitions.first { $0.name == name } }

    /// Default value for every parameter.
    public var defaults: [String: Double] { Dictionary(uniqueKeysWithValues: definitions.map { ($0.name, $0.defaultValue) }) }

    /// Resolves supplied values. Non-finite values throw `.nonFinite`. Out-of-range values are clamped with a warning,
    /// missing values take the default, and unknown names are dropped with a warning.
    public func resolve(_ supplied: [String: Double]) throws(ParameterError) -> ResolvedParameters {
        var values: [String: Double] = [:]
        var warnings: [String] = []
        for d in definitions {
            guard let v = supplied[d.name] else { values[d.name] = d.defaultValue; continue }
            guard v.isFinite else { throw .nonFinite(d.name) }
            let c = d.clamped(v)
            if c != v { warnings.append("\(d.name): \(v) clamped to \(c)") }
            values[d.name] = c
        }
        for name in supplied.keys.sorted() where definition(name) == nil {
            warnings.append("\(name): unknown parameter dropped")
        }
        return ResolvedParameters(values: values, warnings: warnings)
    }
}
