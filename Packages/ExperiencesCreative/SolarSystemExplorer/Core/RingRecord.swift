// RingRecord — feature 105 (A14-P03) T-A14-303 (FR-A14-302; clarification Q2; data-model "RingRecord"; research D2).
// Saturn's main rings as sourced numbers: from the C ring's inner edge (74,500 km) to the A ring's outer edge
// (136,775 km), with the Cassini division between the B and A rings (117,580–122,170 km), all from the NASA NSSDCA
// "Saturnian Rings Fact Sheet" (nssdc.gsfc.nasa.gov/planetary/factsheet/satringfact.html), epoch J2000.0, km, a work of
// the US government in the public domain. Each value has one `SourceRecord` (`SourceRecord.ringRecords`: quantities
// `ring-inner-radius`, `ring-outer-radius` and `cassini-division`), audited by `CitationAudit.ringProblems`. The radii
// are distances from Saturn's centre in its equatorial plane; the drawing tilts that plane by Saturn's catalog axial
// tilt and does not model the pole's azimuth (stated approximation).
import Foundation

/// Saturn's main rings in kilometres from the planet's centre.
public struct RingRecord: Codable, Equatable, Sendable {
    /// The body the rings belong to (`saturn`).
    public let bodyID: String
    /// The inner edge of the C ring, km.
    public let innerKm: Double
    /// The inner edge of the Cassini division, km.
    public let cassiniInnerKm: Double
    /// The outer edge of the Cassini division, km.
    public let cassiniOuterKm: Double
    /// The outer edge of the A ring, km.
    public let outerKm: Double

    /// Creates a record from its values (no validation; ``problems`` checks).
    public init(bodyID: String, innerKm: Double, cassiniInnerKm: Double, cassiniOuterKm: Double, outerKm: Double) {
        self.bodyID = bodyID; self.innerKm = innerKm; self.cassiniInnerKm = cassiniInnerKm
        self.cassiniOuterKm = cassiniOuterKm; self.outerKm = outerKm
    }

    /// Saturn's main rings (see the file header).
    public static let saturn = RingRecord(bodyID: "saturn", innerKm: 74_500, cassiniInnerKm: 117_580,
                                          cassiniOuterKm: 122_170, outerKm: 136_775)

    /// The record's problems, empty when every value is finite and positive and
    /// inner < cassini inner < cassini outer < outer.
    public var problems: [String] {
        let values: [Double] = [innerKm, cassiniInnerKm, cassiniOuterKm, outerKm]
        guard values.allSatisfy({ $0.isFinite && $0 > 0 }) else {
            return ["\(bodyID) rings: a value is not finite and positive"]
        }
        guard innerKm < cassiniInnerKm, cassiniInnerKm < cassiniOuterKm, cassiniOuterKm < outerKm else {
            return ["\(bodyID) rings: edges out of order"]
        }
        return []
    }

    /// True when `radiusKm` lies in the Cassini division.
    public func inCassiniDivision(_ radiusKm: Double) -> Bool {
        radiusKm >= cassiniInnerKm && radiusKm <= cassiniOuterKm
    }
}
