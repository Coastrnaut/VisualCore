// EffectDefinition — feature 180 (A25-P01) T-A25-103 (FR-A25-101, FR-A25-102; SC-A25-101; clarification Q1;
// data-model.md "EffectID", "ParameterSpec", "EffectDefinition"; contracts/core.md). The five built-in effects of
// version 1: each has a stable id, a title, its named parameters (closed finite range, a default inside it, and
// whether only whole numbers are allowed) and a fingerprint, a `StateDigest` of domain `a25.effect.v1` over the id,
// the version and every parameter's name, lower bound, upper bound, default and whole flag, in parameter order.
// Choices recorded here: a refused value names its field as `<effect>.<parameter>` (for example `grade.contrast`);
// validation checks, in order, unknown names (the first in name order), then each parameter in definition order:
// missing, not finite, a fraction for a whole-number parameter (`out-of-range`), outside the range (`out-of-range`).
// Definitions are built only here, so every bound is finite. Pure Foundation; no UI, GPU or clock.
import Foundation
import VisualCoreExperience

/// The stable identifier of a built-in effect; the raw value is stored in chain files.
public enum EffectID: String, CaseIterable, Sendable, Codable {
    /// Color grade: exposure, contrast and saturation.
    case grade
    /// Box blur over whole-pixel radius.
    case blur
    /// Sine displacement of the sampling position.
    case distort
    /// Radial darkening towards the corners.
    case vignette
    /// Quantisation of each channel to a number of levels.
    case posterize
}

/// One named parameter of an effect: its closed, finite range, its default inside the range, and whether it takes
/// only whole numbers.
public struct ParameterSpec: Equatable, Sendable {
    /// The parameter's name, unique within its effect.
    public let name: String
    /// The closed range of allowed values; both ends are finite and allowed.
    public let range: ClosedRange<Double>
    /// The value a new node takes; inside ``range``.
    public let defaultValue: Double
    /// True when only whole numbers are allowed (a fraction is refused as out of range).
    public let whole: Bool

    /// A parameter with the given name, range, default and whole flag (built only by ``EffectLibrary``).
    init(name: String, range: ClosedRange<Double>, defaultValue: Double, whole: Bool = false) {
        self.name = name
        self.range = range
        self.defaultValue = defaultValue
        self.whole = whole
    }
}

/// The definition of one built-in effect: id, version, title and ordered parameters.
public struct EffectDefinition: Equatable, Sendable {
    /// The domain of the definition fingerprint.
    public static let fingerprintDomain = "a25.effect.v1"

    /// The effect's stable identifier.
    public let id: EffectID
    /// The definition's version; any change to the formula or the parameters takes a new version.
    public let version: Int
    /// The title shown to a person.
    public let title: String
    /// The parameters in their fixed order.
    public let parameters: [ParameterSpec]

    /// A definition with the given fields (built only by ``EffectLibrary``).
    init(id: EffectID, version: Int, title: String, parameters: [ParameterSpec]) {
        self.id = id
        self.version = version
        self.title = title
        self.parameters = parameters
    }

    /// The default value of every parameter, by name.
    public var defaults: [String: Double] {
        var values: [String: Double] = [:]
        for parameter in parameters { values[parameter.name] = parameter.defaultValue }
        return values
    }

    /// The parameter named `name`, or nil when the effect has none of that name.
    public func parameter(named name: String) -> ParameterSpec? {
        parameters.first { $0.name == name }
    }

    /// The field name of a parameter in refusals: `<effect>.<parameter>`.
    public func field(_ name: String) -> String {
        "\(id.rawValue).\(name)"
    }

    /// The fingerprint of the definition: a `StateDigest` of domain ``fingerprintDomain`` over the id's raw value,
    /// the version, the number of parameters and, for each parameter in order, its name, lower bound, upper bound,
    /// default and whole flag. Every bound of a built-in definition is finite, so no value is ever skipped.
    public func fingerprint() -> StateDigest {
        var builder = DigestBuilder(domain: Self.fingerprintDomain)
        builder.add(id.rawValue)
        builder.add(version)
        builder.add(count: parameters.count)
        for parameter in parameters {
            builder.add(parameter.name)
            try? builder.add(parameter.range.lowerBound)
            try? builder.add(parameter.range.upperBound)
            try? builder.add(parameter.defaultValue)
            builder.add(parameter.whole)
        }
        return builder.finish()
    }

    /// Refuses a set of values that is not exactly this effect's parameters within their ranges. Checks, in order:
    /// a name the effect does not have (``ChainRefusal/unknownParameter(_:)``, the first in name order), then each
    /// parameter in definition order: absent (``ChainRefusal/missingParameter(_:)``), NaN or infinite
    /// (``ChainRefusal/notFinite(_:)``), a fraction for a whole-number parameter or a value outside the range
    /// (``ChainRefusal/outOfRange(_:)``). Every refusal names the field as `<effect>.<parameter>`.
    public func validate(values: [String: Double]) throws(ChainRefusal) {
        for name in values.keys.sorted() where parameter(named: name) == nil {
            throw .unknownParameter(field(name))
        }
        for parameter in parameters {
            guard let value = values[parameter.name] else { throw .missingParameter(field(parameter.name)) }
            guard value.isFinite else { throw .notFinite(field(parameter.name)) }
            if parameter.whole, value.rounded(.towardZero) != value { throw .outOfRange(field(parameter.name)) }
            guard parameter.range.contains(value) else { throw .outOfRange(field(parameter.name)) }
        }
    }
}

/// The five built-in effects of version 1 (clarification Q1).
public enum EffectLibrary {
    /// Color grade: y = x·2^exposure; y = (y − 0.5)·contrast + 0.5; y = L + (y − L)·saturation with Rec. 709 luma L.
    static let grade = EffectDefinition(id: .grade, version: 1, title: "Color grade", parameters: [
        ParameterSpec(name: "exposure", range: -2...2, defaultValue: 0),
        ParameterSpec(name: "contrast", range: 0.5...2, defaultValue: 1),
        ParameterSpec(name: "saturation", range: 0...2, defaultValue: 1),
    ])

    /// Blur: the mean of the (2·radius + 1)² texel centres around the pixel; radius in whole pixels.
    static let blur = EffectDefinition(id: .blur, version: 1, title: "Blur", parameters: [
        ParameterSpec(name: "radius", range: 0...8, defaultValue: 2, whole: true),
    ])

    /// Distort: sample at uv + amplitude·(sin(2π·frequency·uv.y), sin(2π·frequency·uv.x)).
    static let distort = EffectDefinition(id: .distort, version: 1, title: "Distort", parameters: [
        ParameterSpec(name: "amplitude", range: 0...0.05, defaultValue: 0.01),
        ParameterSpec(name: "frequency", range: 1...16, defaultValue: 4),
    ])

    /// Vignette: d = 2·‖uv − 0.5‖/√2; rgb·(1 − amount·smoothstep(radius − softness, radius, d)).
    static let vignette = EffectDefinition(id: .vignette, version: 1, title: "Vignette", parameters: [
        ParameterSpec(name: "amount", range: 0...1, defaultValue: 0.5),
        ParameterSpec(name: "radius", range: 0.2...1, defaultValue: 0.75),
        ParameterSpec(name: "softness", range: 0.05...1, defaultValue: 0.3),
    ])

    /// Posterize: y = floor(x·(levels − 1) + 0.5)/(levels − 1); levels whole.
    static let posterize = EffectDefinition(id: .posterize, version: 1, title: "Posterize", parameters: [
        ParameterSpec(name: "levels", range: 2...32, defaultValue: 8, whole: true),
    ])

    /// The five definitions in the order grade, blur, distort, vignette, posterize.
    public static let all: [EffectDefinition] = [grade, blur, distort, vignette, posterize]

    /// The definition of `id`.
    public static func definition(_ id: EffectID) -> EffectDefinition {
        switch id {
        case .grade: grade
        case .blur: blur
        case .distort: distort
        case .vignette: vignette
        case .posterize: posterize
        }
    }
}
