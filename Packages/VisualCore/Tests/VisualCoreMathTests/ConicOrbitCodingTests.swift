// ConicOrbitCodingTests — feature 215 (R02-F15) T-R02F15-006 (FR-R02F15-007; SC-R02F15-006; clarification Q5).
// The schema-1 stored form round-trips byte-identically for the three conic kinds; newer, missing, truncated and
// invalid stored forms are refused with their reason codes. Test data uses explicit types and plain loops.
import Foundation
import Testing
@testable import VisualCoreMath

@Suite struct ConicOrbitCodingTests {
    private func orbit(e: Double) throws(OrbitError) -> ConicOrbit {
        try ConicOrbit(periapsisDistance: 0.75, eccentricity: e, inclination: 0.123_456_789,
                       ascendingNode: -2.5, argumentOfPeriapsis: 1.0 / 3.0, timeOfPeriapsis: -17.25,
                       gravitationalParameter: 39.478_417_6)
    }

    @Test func roundTripIsByteIdenticalForEveryKind() throws {
        let eccentricities: [Double] = [0.2, 1, 2.75]
        for e in eccentricities {
            let original = try orbit(e: e)
            let data = original.encoded()
            let decoded = try ConicOrbit.decode(data)
            #expect(decoded == original, "e \(e)")
            #expect(decoded.encoded() == data, "e \(e)")
        }
        let kinds: [ConicKind] = [try orbit(e: 0.2).kind, try orbit(e: 1).kind, try orbit(e: 2.75).kind]
        #expect(kinds == [.elliptic, .parabolic, .hyperbolic])
    }

    @Test func storedFormHasSortedKeysAndSchema() throws {
        let text = String(decoding: try orbit(e: 0.2).encoded(), as: UTF8.self)
        #expect(text.hasPrefix("{\"argumentOfPeriapsis\":"))
        #expect(text.contains("\"schema\":1"))
        let keys: [String] = ["argumentOfPeriapsis", "ascendingNode", "eccentricity", "gravitationalParameter",
                              "inclination", "periapsisDistance", "schema", "timeOfPeriapsis"]
        var last = text.startIndex
        for key in keys {
            let range = try #require(text.range(of: "\"\(key)\":"), "key \(key)")
            #expect(range.lowerBound >= last, "key \(key) in order")
            last = range.lowerBound
        }
    }

    private func json(schema: String?, q: String = "1") -> Data {
        var fields: [String] = [
            "\"argumentOfPeriapsis\":0", "\"ascendingNode\":0", "\"eccentricity\":0.5",
            "\"gravitationalParameter\":1", "\"inclination\":0", "\"periapsisDistance\":\(q)", "\"timeOfPeriapsis\":0",
        ]
        if let schema { fields.append("\"schema\":\(schema)") }
        return Data(("{" + fields.joined(separator: ",") + "}").utf8)
    }

    @Test func refusals() throws {
        #expect(try ConicOrbit.decode(json(schema: "1")).eccentricity == 0.5)

        do {
            _ = try ConicOrbit.decode(json(schema: "2"))
            Issue.record("schema 2 accepted")
        } catch {
            #expect(error == .newerSchema(2))
            #expect(error.reasonCode == "r2-f15.newer-schema")
        }

        let damaged: [Data] = [json(schema: nil), Data(json(schema: "1").dropLast(9)), Data(), json(schema: "\"one\"")]
        for (index, data) in damaged.enumerated() {
            do {
                _ = try ConicOrbit.decode(data)
                Issue.record("damaged case \(index) accepted")
            } catch {
                #expect(error.reasonCode == "r2-f15.malformed", "damaged case \(index): \(error)")
            }
        }

        do {
            _ = try ConicOrbit.decode(json(schema: "1", q: "0"))
            Issue.record("q = 0 accepted")
        } catch {
            #expect(error == .invalidElements("periapsisDistance"))
            #expect(error.reasonCode == "r2-f15.invalid-elements")
        }
    }

    @Test func codableInitThrowsOrbitErrors() {
        let decoder = JSONDecoder()
        #expect(throws: OrbitError.newerSchema(3)) { try decoder.decode(ConicOrbit.self, from: json(schema: "3")) }
        #expect(throws: OrbitError.invalidElements("periapsisDistance")) {
            try decoder.decode(ConicOrbit.self, from: json(schema: "1", q: "-1"))
        }
    }
}
