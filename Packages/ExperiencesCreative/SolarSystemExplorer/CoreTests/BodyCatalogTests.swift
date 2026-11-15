// BodyCatalogTests — feature 103 (A14-P01) T-A14-102 (FR-A14-101, 104, 121; clarification Q2; SC-A14-101). The body
// catalog, host-free and short: nine bodies in catalog order (the Sun first, without an axis or a period); the exact
// values of clarification Q2; planets in increasing distance; the sorted-key JSON round trip is exact; damaged, newer
// and out-of-range documents are each refused as a whole with their reason; the fact cards carry a unit and a source on
// every measured value, the Sun's card says it has no orbit and retrograde tilts are noted.
import Foundation
import SolarSystemExplorerCore
import Testing

@Suite struct BodyCatalogTests {
    private let catalog = BodyCatalog.bundled

    /// The bundled document as a JSON object, ready to be damaged.
    private func document() throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: catalog.encoded()) as? [String: Any])
    }

    /// The bundled document with body `index`'s `key` set to `value` (nil removes the key).
    private func withBody(_ index: Int, _ key: String, _ value: Any?) throws -> Data {
        var root = try document()
        var bodies = try #require(root["bodies"] as? [[String: Any]])
        bodies[index][key] = value
        root["bodies"] = bodies
        return try JSONSerialization.data(withJSONObject: root)
    }

    @Test func thereAreNineBodiesInOrder() {
        let ids: [String] = ["sun", "mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune"]
        let names: [String] = ["Sun", "Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"]
        #expect(catalog.bodies.map(\.id) == ids)
        #expect(catalog.bodies.map(\.name) == names)
        #expect(catalog.bodies[0].kind == .star && catalog.bodies.dropFirst().allSatisfy { $0.kind == .planet })
        #expect(catalog.bodies[0].semiMajorAxisKm == nil && catalog.bodies[0].siderealPeriodDays == nil)
        #expect(catalog.bodies[0].storedQuantities == [.meanRadius, .axialTilt])
        #expect(catalog.body(id: "mars")?.name == "Mars" && catalog.body(id: "pluto") == nil)
        #expect(catalog.body(at: 9) == nil && catalog.body(at: -1) == nil)
        #expect(BodyCatalog.schemaVersion == 1 && BodyCatalog.rangeProblem(catalog) == nil)
    }

    @Test func theValuesAreExactlyThoseOfClarificationQ2() {
        let radii: [Double] = [695_700, 2_439.7, 6_051.8, 6_371.0, 3_389.5, 69_911, 58_232, 25_362, 24_622]
        let axes: [Double?] = [nil, 57.909e6, 108.210e6, 149.598e6, 227.956e6, 778.479e6, 1_432.041e6, 2_867.043e6,
                               4_514.953e6]
        let periods: [Double?] = [nil, 87.969, 224.701, 365.256, 686.980, 4_332.589, 10_759.22, 30_685.4, 60_189.0]
        let tilts: [Double] = [7.25, 0.034, 177.4, 23.44, 25.19, 3.13, 26.73, 97.77, 28.32]
        #expect(catalog.bodies.map(\.meanRadiusKm) == radii)
        #expect(catalog.bodies.map(\.semiMajorAxisKm) == axes)
        #expect(catalog.bodies.map(\.siderealPeriodDays) == periods)
        #expect(catalog.bodies.map(\.axialTiltDegrees) == tilts)
        #expect(catalog.bodies.filter(\.isRetrograde).map(\.id) == ["venus", "uranus"])
    }

    @Test func planetsAreInIncreasingDistance() {
        var last: Double = 0
        for body in catalog.bodies.dropFirst() {
            let axis: Double = body.semiMajorAxisKm ?? 0
            #expect(axis > last, "\(body.id)")
            last = axis
        }
    }

    @Test func theJSONRoundTripIsExactAndSorted() throws {
        let data = catalog.encoded()
        #expect(BodyCatalog.decode(data) == .success(catalog))
        let text = String(decoding: data, as: UTF8.self)
        let sun = #"{"axialTiltDegrees":7.25,"id":"sun","kind":"star","meanRadiusKm":695700,"name":"Sun"}"#
        #expect(text.hasPrefix(#"{"bodies":["# + sun + ","), "\(text.prefix(120))")
        #expect(text.contains(#""meanRadiusKm":2439.7,"name":"Mercury","semiMajorAxisKm":57909000,"#))
        #expect(text.contains(#"],"schema":1,"sources":[{"bodyID":"sun","epoch":"nominal","license":"public-domain","#))
        #expect(!text.contains("null"))
        guard case .success(let decoded) = BodyCatalog.decode(data) else {
            Issue.record("the bundled document decodes")
            return
        }
        #expect(decoded.encoded() == data)
    }

    @Test func damagedAndNewerDocumentsAreRefused() throws {
        let full = String(decoding: catalog.encoded(), as: UTF8.self)
        let head = #"{"bodies":[{"axialTiltDegrees":1,"id":"x","#
        let tail = #"}],"schema":1,"sources":[]}"#
        let damaged: [String] = [
            "not json",
            String(full.dropLast(5)),
            #"{"bodies":[],"sources":[]}"#,
            #"{"bodies":[],"schema":"1","sources":[]}"#,
            #"{"bodies":[],"schema":0,"sources":[]}"#,
            #"{"schema":1,"sources":[]}"#,
            #"{"bodies":[],"schema":1}"#,
            head + #""kind":"moon","meanRadiusKm":2,"name":"X""# + tail,
            head + #""kind":"star","meanRadiusKm":"2","name":"X""# + tail,
            head + #""kind":"star","meanRadiusKm":1e999,"name":"X""# + tail,
            head + #""kind":"star","name":"X""# + tail,
            #"{"bodies":[],"schema":1,"sources":[{"bodyID":"x"}]}"#,
        ]
        for payload in damaged {
            #expect(BodyCatalog.decode(Data(payload.utf8)) == .failure(.damaged), "\(payload.prefix(80))")
        }
        let newer: [String] = [#"{"bodies":[],"schema":2,"sources":[]}"#, #"{"schema":9}"#]
        for payload in newer {
            #expect(BodyCatalog.decode(Data(payload.utf8)) == .failure(.newerVersion), "\(payload)")
        }
        #expect(BodyCatalog.decode(try withBody(3, "meanRadiusKm", "6371")) == .failure(.damaged))
        #expect(BodyCatalog.decode(try withBody(3, "name", nil)) == .failure(.damaged))
        #expect(CatalogRefusal.allCases.map(\.rawValue) == ["damaged", "newer-version", "out-of-range"])
    }

    @Test func outOfRangeDocumentsAreRefusedAsAWhole() throws {
        let cases: [(Int, String, Any?)] = [
            (3, "meanRadiusKm", 0.5),
            (3, "meanRadiusKm", 1_000_001),
            (3, "semiMajorAxisKm", 999_999),
            (8, "semiMajorAxisKm", 1.1e10),
            (3, "siderealPeriodDays", 0.9),
            (8, "siderealPeriodDays", 1_000_001),
            (3, "axialTiltDegrees", -0.1),
            (2, "axialTiltDegrees", 180.1),
            (3, "semiMajorAxisKm", nil),
            (3, "siderealPeriodDays", nil),
            (0, "semiMajorAxisKm", 2e6),
            (0, "siderealPeriodDays", 10),
            (4, "id", "earth"),
            (4, "id", ""),
            (4, "name", ""),
            (2, "semiMajorAxisKm", 160e6),
            (1, "kind", "star"),
            (1, "meanRadiusKm", -2_439.7),
        ]
        for (index, key, value) in cases {
            let data = try withBody(index, key, value)
            let label = "body \(index) \(key) = \(String(describing: value))"
            #expect(BodyCatalog.decode(data) == .failure(.outOfRange), "\(label)")
        }
        var root = try document()
        root["bodies"] = [Any]()
        #expect(BodyCatalog.decode(try JSONSerialization.data(withJSONObject: root)) == .failure(.outOfRange))
        var bodies = try #require(root["bodies"] as? [Any])
        let sun = try #require((try document()["bodies"] as? [Any])?.first)
        for _ in 0..<17 { bodies.append(sun) }
        root["bodies"] = bodies
        #expect(BodyCatalog.decode(try JSONSerialization.data(withJSONObject: root)) == .failure(.outOfRange))
        let one = BodyCatalog(bodies: [catalog.bodies[0]], sources: [])
        #expect(BodyCatalog.decode(one.encoded()) == .success(one), "one body and no sources is in range")
    }

    @Test func factCardsCarryUnitsAndSources() throws {
        let earth = try #require(catalog.factCard(for: 3))
        #expect(earth.name == "Earth" && earth.bodyID == "earth" && earth.kind == .planet)
        #expect(earth.facts.map(\.label) == ["Mean radius", "Distance from the Sun", "Orbital period", "Axial tilt"])
        #expect(earth.facts[0].text == "Mean radius: 6,371 km — Planetary Fact Sheet — Metric")
        #expect(earth.facts[1].text
                == "Distance from the Sun: 1.000 AU (149,598,000 km) — Planetary Fact Sheet — Metric")
        #expect(earth.facts[2].text == "Orbital period: 365.256 days (1.000 years) — Planetary Fact Sheet — Metric")
        #expect(earth.facts[3].text == "Axial tilt: 23.44 degrees — Planetary Fact Sheet — Metric")
        let mercury = try #require(catalog.factCard(for: 1))
        #expect(mercury.facts[0].value == "2,439.7" && mercury.facts[1].value == "0.387")
        #expect(mercury.facts[1].unit == "AU")
        #expect(mercury.facts[2].note == "0.241 years" && mercury.facts[3].value == "0.034")
        let neptune = try #require(catalog.factCard(for: 8))
        #expect(neptune.facts[1].value == "30.181" && neptune.facts[1].note == "4,514,953,000 km")
        #expect(neptune.facts[2].note == "164.789 years")
        let venus = try #require(catalog.factCard(for: 2))
        #expect(venus.facts[3].text == "Axial tilt: 177.4 degrees (retrograde) — Planetary Fact Sheet — Metric")
        #expect(try #require(catalog.factCard(for: 7)).facts[3].note == "retrograde")
        #expect(try #require(catalog.factCard(for: 4)).facts[3].note == "")
        let sun = try #require(catalog.factCard(for: 0))
        #expect(sun.facts.map(\.text) == [
            "Mean radius: 695,700 km — Resolution B3 on recommended nominal conversion constants",
            "Axial tilt: 7.25 degrees (to the ecliptic) — Sun Fact Sheet",
            "Orbit: none (centre of the system)",
        ])
        #expect(sun.text.hasSuffix("\nOrbit: none (centre of the system)"))
        for index in 0..<9 {
            let card = try #require(catalog.factCard(for: index))
            let measured: [Fact] = card.facts.filter { $0.label != "Orbit" }
            #expect(measured.allSatisfy { !$0.unit.isEmpty && !$0.source.isEmpty && !$0.value.isEmpty }, "\(card.name)")
        }
        #expect(catalog.factCard(for: 9) == nil && catalog.factCard(for: -1) == nil)
    }
}
