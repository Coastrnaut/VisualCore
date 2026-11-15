// WorldLight — feature 091 (A12-P03) T-A12-302 (FR-A12-310; clarification Q3; research D3; data-model "WorldLight";
// G-LIGHT). The light of a world: the sun's azimuth (degrees, wrapped into 0…360, 0 included, 360 excluded), its
// elevation (degrees, 10…85) and the ambient level (0.1…0.6); default azimuth 30°, elevation 50°, ambient 0.35. The
// direction towards the sun is the unit vector (cos e · sin a, sin e, cos e · cos a), y up, used by every renderer
// (terrain, sea, props).
//
// `setAzimuth(_:)` wraps any finite value (−30 becomes 330, 360 becomes 0) and refuses a non-finite one;
// `setElevation(_:)` and `setAmbient(_:)` refuse a non-finite or out-of-range value (the `light.*` actions' refusal
// "out of range"). A refusal returns false and changes nothing. Decoding refuses an azimuth outside 0…360 (360
// excluded) or an elevation or ambient outside its range, so a decoded light is always valid. Stored values are
// normalised so −0 is written as 0.
import Foundation
import VisualCoreMath

/// The light of a world (azimuth, elevation, ambient), always within its limits.
public struct WorldLight: Codable, Equatable, Sendable {
    /// The allowed elevation in degrees.
    public static let elevationRange: ClosedRange<Double> = 10...85
    /// The allowed ambient level.
    public static let ambientRange: ClosedRange<Double> = 0.1...0.6
    /// The default light: azimuth 30°, elevation 50°, ambient 0.35.
    public static let `default` = WorldLight(azimuth: 30, elevation: 50, ambient: 0.35)

    /// Azimuth in degrees, 0 ≤ azimuth < 360.
    public private(set) var azimuth: Double
    /// Elevation in degrees, within ``elevationRange``.
    public private(set) var elevation: Double
    /// Ambient level, within ``ambientRange``.
    public private(set) var ambient: Double

    /// A light with the azimuth wrapped and the elevation and ambient clamped into their ranges; a non-finite
    /// component takes the default light's value.
    public init(azimuth: Double, elevation: Double, ambient: Double) {
        self.azimuth = azimuth.isFinite ? Self.wrap(azimuth) : 30
        self.elevation = elevation.isFinite ? min(max(elevation, Self.elevationRange.lowerBound),
                                                  Self.elevationRange.upperBound) + 0 : 50
        self.ambient = ambient.isFinite ? min(max(ambient, Self.ambientRange.lowerBound),
                                              Self.ambientRange.upperBound) + 0 : 0.35
    }

    /// The unit direction towards the light: (cos e · sin a, sin e, cos e · cos a).
    public var direction: Vec3 {
        let a = azimuth * WorldView.radiansPerDegree, e = elevation * WorldView.radiansPerDegree
        return Vec3(cos(e) * sin(a), sin(e), cos(e) * cos(a))
    }

    /// True when every component is finite and within its range.
    public var isValid: Bool {
        azimuth.isFinite && azimuth >= 0 && azimuth < 360 && Self.elevationRange.contains(elevation)
            && Self.ambientRange.contains(ambient)
    }

    /// Sets the azimuth to `degrees` wrapped into 0…360; false, with nothing changed, when it is non-finite.
    @discardableResult
    public mutating func setAzimuth(_ degrees: Double) -> Bool {
        guard degrees.isFinite else { return false }
        azimuth = Self.wrap(degrees)
        return true
    }

    /// Sets the elevation to `degrees` (10…85); false, with nothing changed, when non-finite or out of range.
    @discardableResult
    public mutating func setElevation(_ degrees: Double) -> Bool {
        guard Self.elevationRange.contains(degrees) else { return false }
        elevation = degrees + 0
        return true
    }

    /// Sets the ambient level to `value` (0.1…0.6); false, with nothing changed, when non-finite or out of range.
    @discardableResult
    public mutating func setAmbient(_ value: Double) -> Bool {
        guard Self.ambientRange.contains(value) else { return false }
        ambient = value + 0
        return true
    }

    /// `degrees` wrapped into 0…360 (360 excluded; −0 becomes 0).
    static func wrap(_ degrees: Double) -> Double {
        var wrapped = degrees.truncatingRemainder(dividingBy: 360)
        if wrapped < 0 { wrapped += 360 }
        if wrapped >= 360 { wrapped = 0 }
        return wrapped + 0
    }

    private enum CodingKeys: String, CodingKey { case ambient, azimuth, elevation }

    /// Decodes `{"ambient", "azimuth", "elevation"}`, refusing a component that is non-finite or outside its range.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        azimuth = try c.decode(Double.self, forKey: .azimuth)
        elevation = try c.decode(Double.self, forKey: .elevation)
        ambient = try c.decode(Double.self, forKey: .ambient)
        guard isValid else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath,
                                                    debugDescription: "light outside its limits"))
        }
    }

    /// Encodes `{"ambient", "azimuth", "elevation"}`.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(ambient, forKey: .ambient)
        try c.encode(azimuth, forKey: .azimuth)
        try c.encode(elevation, forKey: .elevation)
    }
}
