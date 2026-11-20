// SkyParameters — feature 218 (R02-F18) T-R02F18-002 (FR-R02F18-005, FR-R02F18-007, FR-R02F18-008; clarifications Q4,
// Q5; data-model.md). The settings of the analytic sky shared by `SkyModel` and `vc/sky.glsl`: linear RGB colours
// (0 … 1) of zenith, horizon, ground, the dusk tint, the night scale and the sun, the sun disc's angular radius and its
// glow. Stored as JSON schema 1 with sorted keys; a newer schema is refused.
import Foundation
import VisualCoreMath

/// A refusal of a sky request.
public enum SkyError: Error, Equatable, Sendable {
    /// A sky parameter is not finite or outside its range; the payload names it.
    case skyParameter(String)
    /// A view or sun direction is zero or not finite.
    case direction
    /// Stored parameters have a schema newer than ``SkyParameters/schema``; the payload is that schema.
    case newerSchema(Int)
    /// Stored parameters are damaged or incomplete; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r2-f18.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .skyParameter: "r2-f18.sky-parameter"
        case .direction: "r2-f18.direction"
        case .newerSchema: "r2-f18.newer-schema"
        case .malformed: "r2-f18.malformed"
        }
    }
}

/// The settings of the analytic sky.
public struct SkyParameters: Sendable, Equatable {
    /// The stored-form schema.
    public static let schema = 1

    /// The colour straight up.
    public var zenith = Vec3(0.18, 0.36, 0.75)
    /// The colour at the horizon.
    public var horizon = Vec3(0.70, 0.80, 0.92)
    /// The colour below the horizon.
    public var ground = Vec3(0.30, 0.27, 0.24)
    /// The warm tint added towards the sun near the horizon at dawn and dusk.
    public var dusk = Vec3(0.90, 0.45, 0.20)
    /// The per-channel scale of the whole sky at night.
    public var night = Vec3(0.05, 0.06, 0.12)
    /// The colour of the sun disc and its glow.
    public var sunColour = Vec3(1.00, 0.95, 0.85)
    /// The sun disc's angular radius, 0.001 … 0.2 radians.
    public var sunRadius = 0.0093
    /// The glow's strength, 0 … 4.
    public var glowStrength = 0.5
    /// The glow's exponent, 1 … 4,096 (larger is tighter).
    public var glowExponent = 64.0

    /// The defaults of data-model.md.
    public init() {}

    /// These parameters, or ``SkyError/skyParameter(_:)`` naming the first value that is not finite or outside its
    /// range (colours 0 … 1 per channel).
    public func validated() throws(SkyError) -> SkyParameters {
        let colours: [(String, Vec3)] = [("zenith", zenith), ("horizon", horizon), ("ground", ground), ("dusk", dusk),
                                          ("night", night), ("sunColour", sunColour)]
        for (name, c) in colours {
            for v in [c.x, c.y, c.z] where !(v.isFinite && v >= 0 && v <= 1) { throw .skyParameter(name) }
        }
        guard sunRadius.isFinite, sunRadius >= 0.001, sunRadius <= 0.2 else { throw .skyParameter("sunRadius") }
        guard glowStrength.isFinite, glowStrength >= 0, glowStrength <= 4 else { throw .skyParameter("glowStrength") }
        guard glowExponent.isFinite, glowExponent >= 1, glowExponent <= 4_096 else { throw .skyParameter("glowExponent") }
        return self
    }

    /// The stored form: JSON with sorted keys.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        // Finite doubles only, so encoding cannot fail.
        return (try? encoder.encode(self)) ?? Data()
    }

    /// Reads stored parameters; refuses a newer schema, damaged data and values outside their ranges.
    public static func decode(_ data: Data) throws(SkyError) -> SkyParameters {
        do {
            return try JSONDecoder().decode(SkyParameters.self, from: data)
        } catch let error as SkyError {
            throw error
        } catch {
            throw .malformed(String(describing: error))
        }
    }
}

extension SkyParameters: Codable {
    private enum Key: String, CodingKey {
        case schema, zenith, horizon, ground, dusk, night, sunColour, sunRadius, glowStrength, glowExponent
    }

    /// Reads the stored form (see ``decode(_:)``).
    public init(from decoder: any Decoder) throws {
        let c: KeyedDecodingContainer<Key>
        let schemaValue: Int
        do {
            c = try decoder.container(keyedBy: Key.self)
            schemaValue = try c.decode(Int.self, forKey: .schema)
        } catch {
            throw SkyError.malformed(String(describing: error))
        }
        guard schemaValue <= Self.schema else { throw SkyError.newerSchema(schemaValue) }
        guard schemaValue == Self.schema else { throw SkyError.malformed("schema \(schemaValue)") }
        do {
            zenith = try c.decode(Vec3.self, forKey: .zenith)
            horizon = try c.decode(Vec3.self, forKey: .horizon)
            ground = try c.decode(Vec3.self, forKey: .ground)
            dusk = try c.decode(Vec3.self, forKey: .dusk)
            night = try c.decode(Vec3.self, forKey: .night)
            sunColour = try c.decode(Vec3.self, forKey: .sunColour)
            sunRadius = try c.decode(Double.self, forKey: .sunRadius)
            glowStrength = try c.decode(Double.self, forKey: .glowStrength)
            glowExponent = try c.decode(Double.self, forKey: .glowExponent)
        } catch {
            throw SkyError.malformed(String(describing: error))
        }
        _ = try validated()
    }

    /// Writes the stored form with the schema.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: Key.self)
        try c.encode(Self.schema, forKey: .schema)
        try c.encode(zenith, forKey: .zenith)
        try c.encode(horizon, forKey: .horizon)
        try c.encode(ground, forKey: .ground)
        try c.encode(dusk, forKey: .dusk)
        try c.encode(night, forKey: .night)
        try c.encode(sunColour, forKey: .sunColour)
        try c.encode(sunRadius, forKey: .sunRadius)
        try c.encode(glowStrength, forKey: .glowStrength)
        try c.encode(glowExponent, forKey: .glowExponent)
    }
}
