// Elements — feature 110 (A15-P01) T-A15-102 (FR-A15-101; clarification Q1; data-model "Element"; contracts/domain.md;
// research D1; SC-A15-101). The element catalog of Molecular Explorer: ten elements in atomic-number order — H, C, N,
// O, F, P, S, Cl, Br, I (1, 6, 7, 8, 9, 15, 16, 17, 35, 53) — each with its symbol, name, atomic number, single-bond
// covalent radius (Å), van der Waals radius (Å) and display colour (six hex digits).
//
// Sources, one `SourceRecord` per stored value (5 per element, 50 in all, element by element in the quantity order
// name, atomic-number, covalent-radius, van-der-waals-radius, color):
// - name, atomic number, van der Waals radius (PubChem gives pm; stored in Å: 1.20, 1.70, 1.55, 1.52, 1.35, 1.80,
//   1.80, 1.75, 1.83, 1.98) and display colour (FFFFFF, 909090, 3050F8, FF0D0D, 90E050, FF8000, FFFF30, 1FF01F,
//   A62929, 940094): "PubChem Periodic Table of Elements", National Library of Medicine (NCBI),
//   pubchem.ncbi.nlm.nih.gov/periodic-table, `public-domain` (a work of the US government);
// - covalent radius (Å: 0.31, 0.76, 0.71, 0.66, 0.57, 1.07, 1.05, 1.02, 1.20, 1.39; carbon's sp³ value): B. Cordero
//   et al., "Covalent radii revisited", Dalton Transactions 2008, Royal Society of Chemistry, `factual-data`
//   (numerical facts, cited for provenance).
// Units are "Å" for both radii and "" for the name, the atomic number and the colour.
//
// `Elements.element(symbol:)` matches a symbol case-insensitively and returns the element with its normalised symbol
// (`cl` → `Cl`), or nil for a symbol outside the catalog.
import Foundation

/// One supported chemical element with its catalog values.
public struct Element: Codable, Equatable, Hashable, Sendable {
    /// The normalised symbol (`H`, `Cl`).
    public let symbol: String
    /// The English name (`Hydrogen`).
    public let name: String
    /// The atomic number.
    public let atomicNumber: Int
    /// The single-bond covalent radius, ångström.
    public let covalentRadius: Double
    /// The van der Waals radius, ångström.
    public let vanDerWaalsRadius: Double
    /// The display colour as six hex digits without `#` (`FF0D0D`).
    public let colorHex: String

    /// Creates an element from all of its values (no validation; ``ElementAudit`` audits).
    public init(symbol: String, name: String, atomicNumber: Int, covalentRadius: Double, vanDerWaalsRadius: Double,
                colorHex: String) {
        self.symbol = symbol; self.name = name; self.atomicNumber = atomicNumber
        self.covalentRadius = covalentRadius; self.vanDerWaalsRadius = vanDerWaalsRadius; self.colorHex = colorHex
    }
}

/// The stored quantities of an element, each with one source record.
public enum ElementQuantity: String, CaseIterable, Codable, Sendable {
    /// The element's name.
    case name = "name"
    /// The atomic number.
    case atomicNumber = "atomic-number"
    /// The single-bond covalent radius.
    case covalentRadius = "covalent-radius"
    /// The van der Waals radius.
    case vanDerWaalsRadius = "van-der-waals-radius"
    /// The display colour.
    case color = "color"

    /// The units the quantity's record must carry ("Å" for a radius, "" otherwise).
    public var units: String {
        switch self {
        case .covalentRadius, .vanDerWaalsRadius: return SourceRecord.angstrom
        case .name, .atomicNumber, .color: return ""
        }
    }
}

/// The element catalog: the ten supported elements and the source record of every stored value.
public enum Elements {
    /// The ten elements in atomic-number order: H, C, N, O, F, P, S, Cl, Br, I.
    public static let all: [Element] = [
        Element(symbol: "H", name: "Hydrogen", atomicNumber: 1, covalentRadius: 0.31, vanDerWaalsRadius: 1.20,
                colorHex: "FFFFFF"),
        Element(symbol: "C", name: "Carbon", atomicNumber: 6, covalentRadius: 0.76, vanDerWaalsRadius: 1.70,
                colorHex: "909090"),
        Element(symbol: "N", name: "Nitrogen", atomicNumber: 7, covalentRadius: 0.71, vanDerWaalsRadius: 1.55,
                colorHex: "3050F8"),
        Element(symbol: "O", name: "Oxygen", atomicNumber: 8, covalentRadius: 0.66, vanDerWaalsRadius: 1.52,
                colorHex: "FF0D0D"),
        Element(symbol: "F", name: "Fluorine", atomicNumber: 9, covalentRadius: 0.57, vanDerWaalsRadius: 1.35,
                colorHex: "90E050"),
        Element(symbol: "P", name: "Phosphorus", atomicNumber: 15, covalentRadius: 1.07, vanDerWaalsRadius: 1.80,
                colorHex: "FF8000"),
        Element(symbol: "S", name: "Sulfur", atomicNumber: 16, covalentRadius: 1.05, vanDerWaalsRadius: 1.80,
                colorHex: "FFFF30"),
        Element(symbol: "Cl", name: "Chlorine", atomicNumber: 17, covalentRadius: 1.02, vanDerWaalsRadius: 1.75,
                colorHex: "1FF01F"),
        Element(symbol: "Br", name: "Bromine", atomicNumber: 35, covalentRadius: 1.20, vanDerWaalsRadius: 1.83,
                colorHex: "A62929"),
        Element(symbol: "I", name: "Iodine", atomicNumber: 53, covalentRadius: 1.39, vanDerWaalsRadius: 1.98,
                colorHex: "940094"),
    ]

    /// One record per stored value: element by element, in ``ElementQuantity`` order (50 records).
    public static let sources: [SourceRecord] = all.flatMap { element in
        ElementQuantity.allCases.map { record(symbol: element.symbol, quantity: $0) }
    }

    /// The bundled record of `quantity` for the element `symbol`: PubChem for every quantity but the covalent radius,
    /// which comes from Cordero et al. 2008.
    static func record(symbol: String, quantity: ElementQuantity) -> SourceRecord {
        if quantity == .covalentRadius {
            return SourceRecord(key: symbol, quantity: quantity.rawValue, title: SourceRecord.corderoTitle,
                                publisher: SourceRecord.corderoPublisher, link: SourceRecord.corderoLink,
                                units: quantity.units, license: "factual-data")
        }
        return SourceRecord(key: symbol, quantity: quantity.rawValue, title: SourceRecord.pubChemPeriodicTableTitle,
                            publisher: SourceRecord.pubChemPublisher, link: SourceRecord.pubChemPeriodicTableLink,
                            units: quantity.units, license: "public-domain")
    }

    /// The element whose symbol matches `symbol` ignoring case (`cl` → `Cl`), or nil for a symbol outside the catalog.
    public static func element(symbol: String) -> Element? {
        let wanted = symbol.lowercased()
        return all.first { $0.symbol.lowercased() == wanted }
    }

    /// The source record of `quantity` for the element `symbol` (exact symbol), or nil when there is none.
    public static func source(symbol: String, quantity: ElementQuantity) -> SourceRecord? {
        sources.first { $0.key == symbol && $0.quantity == quantity.rawValue }
    }
}
