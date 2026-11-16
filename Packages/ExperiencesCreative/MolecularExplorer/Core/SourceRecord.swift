// SourceRecord — feature 110 (A15-P01) T-A15-102 (FR-A15-101, FR-A15-130; clarifications Q1, Q2; data-model
// "SourceRecord"). Where one stored value came from: the key of what it describes (an element symbol such as `Cl` or a
// molecule id such as `caffeine`), the quantity (`name`, `atomic-number`, `covalent-radius`, `van-der-waals-radius`,
// `color` for an element; `structure` for a molecule), the source's title, publisher and link text (a host and path,
// no scheme), the units ("Å" for lengths, "" for a name, a number or a colour) and the license, one of
// `ElementAudit.allowedLicenses`. Records carry no validation of their own; `ElementAudit` audits them.
//
// Feature 114 (A15-P05) T-A15-502 (FR-A15-505): an imported molecule's structure record has the title "imported
// file", the publisher "your own file", no link, the units "Å" and the license `own-data` ("your own data"). That
// license is never bundled: `ElementAudit.allowedLicenses` (the licenses of the bundled data) stays unchanged.
import Foundation

/// The source of one stored value: what it describes, the source, the units and the license.
public struct SourceRecord: Codable, Equatable, Hashable, Sendable {
    /// The key of what the value describes: an element symbol (`H` … `I`) or a molecule id (`water` … `caffeine`).
    public let key: String
    /// The quantity (`name`, `atomic-number`, `covalent-radius`, `van-der-waals-radius`, `color` or `structure`).
    public let quantity: String
    /// The source's title.
    public let title: String
    /// The source's publisher.
    public let publisher: String
    /// The link text (a host and path, no scheme).
    public let link: String
    /// The units of the value ("Å", or "" for a name, a number or a colour).
    public let units: String
    /// The license, one of ``ElementAudit/allowedLicenses`` when the record is sound.
    public let license: String

    /// Creates a record from all of its fields (no validation; ``ElementAudit`` audits).
    public init(key: String, quantity: String, title: String, publisher: String, link: String, units: String,
                license: String) {
        self.key = key; self.quantity = quantity; self.title = title; self.publisher = publisher
        self.link = link; self.units = units; self.license = license
    }

    /// The PubChem periodic table's title.
    public static let pubChemPeriodicTableTitle = "PubChem Periodic Table of Elements"
    /// The publisher of every PubChem record.
    public static let pubChemPublisher = "National Library of Medicine (NCBI)"
    /// The PubChem periodic table's link text.
    public static let pubChemPeriodicTableLink = "pubchem.ncbi.nlm.nih.gov/periodic-table"
    /// The covalent-radius source's title (single-bond radii; carbon's sp³ value).
    public static let corderoTitle = "Covalent radii revisited (B. Cordero et al., Dalton Transactions, 2008)"
    /// The covalent-radius source's publisher.
    public static let corderoPublisher = "Royal Society of Chemistry"
    /// The covalent-radius source's link text (its DOI).
    public static let corderoLink = "doi.org/10.1039/b801115j"
    /// The quantity of a molecule's structure record.
    public static let structureQuantity = "structure"
    /// The units of every length (ångström).
    public static let angstrom = "Å"
    /// The title of an imported molecule's structure record (feature 114).
    public static let importedTitle = "imported file"
    /// The publisher of an imported molecule's structure record (feature 114).
    public static let importedPublisher = "your own file"
    /// The license of a person's own imported data, shown as "your own data" (feature 114; never a bundled license).
    public static let ownDataLicense = "own-data"
}
