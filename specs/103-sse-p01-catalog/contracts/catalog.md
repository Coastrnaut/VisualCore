# Contract: Solar System Explorer catalog and core (feature 103)

```swift
public enum Units {
    public static let kmPerAU: Double = 149_597_870.7
    public static let daysPerJulianYear: Double = 365.25
    public static func au(fromKm km: Double) -> Double?      // nil for non-finite or negative
    public static func km(fromAU au: Double) -> Double?
    public static func years(fromDays days: Double) -> Double?
    public static func days(fromYears years: Double) -> Double?
}
public enum BodyKind: String, Codable, Sendable { case star, planet }
public struct CelestialBody: Codable, Equatable, Sendable {
    public let id: String; public let name: String; public let kind: BodyKind
    public let meanRadiusKm: Double; public let semiMajorAxisKm: Double?
    public let siderealPeriodDays: Double?; public let axialTiltDegrees: Double
}
public struct SourceRecord: Codable, Equatable, Sendable {
    public let bodyID: String; public let quantity: String; public let title: String; public let publisher: String
    public let link: String; public let epoch: String; public let units: String; public let license: String
}
public struct BodyCatalog: Codable, Equatable, Sendable {
    public static let schemaVersion = 1
    public static let bundled: BodyCatalog
    public let bodies: [CelestialBody]; public let sources: [SourceRecord]
    public func encoded() -> Data; public static func decode(_ data: Data) -> Result<BodyCatalog, CatalogRefusal>
    public func factCard(for index: Int) -> FactCard?
}
public enum CitationAudit {
    public static let allowedLicenses: [String]          // ["public-domain", "CC0-1.0"]
    public static func problems(_ catalog: BodyCatalog) -> [String]
    public static func markdown(_ catalog: BodyCatalog) -> String   // docs/apps/solar-system-explorer/data-sources.md
}
public struct SolarState: Codable, Equatable, Sendable { public static let schemaVersion = 1; public var selection: Int }
```

Actions (adapter `SolarCore`): `body.select [0…8]`, `body.next`, `body.previous`; refusal code `a14.invalid-choice`.
