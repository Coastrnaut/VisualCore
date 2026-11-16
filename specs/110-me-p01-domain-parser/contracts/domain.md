# Contract: Molecular Explorer domain and parser (feature 110)

```swift
public struct Element: Codable, Equatable, Sendable {
    public let symbol: String; public let name: String; public let atomicNumber: Int
    public let covalentRadius: Double; public let vanDerWaalsRadius: Double; public let colorHex: String
}
public enum Elements {
    public static let all: [Element]                      // H C N O F P S Cl Br I
    public static let sources: [SourceRecord]
    public static func element(symbol: String) -> Element? // case-insensitive, normalised
}
public enum ElementAudit {
    public static let allowedLicenses: [String]          // ["public-domain", "CC0-1.0", "factual-data"]
    public static func problems(elements: [Element], sources: [SourceRecord]) -> [String]
    public static func problems(molecules: [Molecule]) -> [String]   // molecule source records
    public static func markdown() -> String              // docs/apps/molecular-explorer/data-sources.md
}
public struct Atom: Codable, Equatable, Sendable { public let symbol: String; public let x, y, z: Double }
public enum BondOrigin: String, Codable, Sendable { case recorded, inferred }
public struct Bond: Codable, Equatable, Sendable { public let a, b: Int; public let order: Int; public let origin: BondOrigin }
public struct Molecule: Codable, Equatable, Sendable {
    public let id: String; public let title: String; public let atoms: [Atom]; public let bonds: [Bond]
    public let source: SourceRecord
    public var formula: String { get }                   // Hill order
    public static func make(...) -> Result<Molecule, MoleculeRefusal>
}
public enum XYZParser {
    public static let maxBytes = 65_536, maxAtoms = 500, maxLineBytes = 256, maxCommentCharacters = 256
    public static let maxCoordinate = 1_000.0, minDistance = 0.4
    public static func parse(_ data: Data) -> Result<ParsedXYZ, XYZRefusal>   // ParsedXYZ: comment, atoms
}
public enum BondInference {
    public static let tolerance = 0.4
    public static func bonds(for atoms: [Atom]) -> [Bond]   // sorted, single, inferred
}
public enum MoleculeLibrary { public static let molecules: [Molecule] }   // water, methane, ethanol, benzene, caffeine
public struct MoleculeState: Codable, Equatable, Sendable { public static let schemaVersion = 1; public var selection: Int }
```

Actions (adapter `MoleculeCore`): `molecule.select [0…4]`, `molecule.next`, `molecule.previous`; refusal code
`a15.invalid-choice`.
