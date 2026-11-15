// ToursTests — feature 106 (A14-P04) T-A14-404 (FR-A14-403, FR-A14-410; SC-A14-403; clarification Q2). The bundled
// tours: two tours of at most six stops and 40 s, visiting the stated catalog indices in order with 600-step holds;
// every number in a caption (before the parenthesised source) is the `Units.storedText` of a stored value of that
// body, and the caption names the body's mean-radius source title.
import Foundation
import SolarSystemExplorerCore
import Testing

@Suite struct ToursTests {
    /// The number tokens (digits, "," and ".") of `text`, with a trailing "." or "," dropped.
    private func numbers(in text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for character in text {
            if character.isNumber || ((character == "," || character == ".") && !current.isEmpty) {
                current.append(character)
            } else if !current.isEmpty {
                tokens.append(current)
                current = ""
            }
        }
        if !current.isEmpty { tokens.append(current) }
        var trimmed: [String] = []
        for var token in tokens {
            while token.hasSuffix(".") || token.hasSuffix(",") { token.removeLast() }
            trimmed.append(token)
        }
        return trimmed
    }

    @Test func twoToursWithTheStatedStopsInOrder() {
        let tours: [Tour] = Tour.bundled
        #expect(tours.count == 2)
        #expect(tours[0].id == "inner-planets" && tours[0].title == "Inner planets")
        #expect(tours[1].id == "giant-planets" && tours[1].title == "Giant planets")
        let inner: [Int] = tours[0].stops.map(\.bodyIndex)
        let giant: [Int] = tours[1].stops.map(\.bodyIndex)
        #expect(inner == [0, 1, 2, 3, 4])
        #expect(giant == [5, 6, 7, 8])
    }

    @Test func toursAreShortAndHoldSixHundredSteps() {
        #expect(Tour.maxStops == 6)
        let expectedSeconds: [Double] = [25, 20]
        for (offset, tour) in Tour.bundled.enumerated() {
            #expect(tour.stops.count <= Tour.maxStops, "\(tour.id)")
            #expect(tour.durationSeconds <= 40, "\(tour.id)")
            #expect(tour.durationSeconds == expectedSeconds[offset], "\(tour.id)")
            #expect(tour.totalSteps == tour.stops.count * 600, "\(tour.id)")
            for stop in tour.stops {
                #expect(stop.holdSteps == 600)
                #expect(BodyCatalog.bundled.body(at: stop.bodyIndex) != nil, "\(tour.id) \(stop.bodyIndex)")
            }
        }
    }

    @Test func captionNumbersAreStoredCatalogValuesOfTheBody() throws {
        let catalog: BodyCatalog = BodyCatalog.bundled
        for tour in Tour.bundled {
            for stop in tour.stops {
                let body: CelestialBody = try #require(catalog.body(at: stop.bodyIndex))
                let title: String = try #require(catalog.source(bodyID: body.id, quantity: .meanRadius)?.title)
                #expect(stop.caption.hasPrefix("\(body.name): "), "\(stop.caption)")
                #expect(stop.caption.hasSuffix(" (\(title))."), "\(stop.caption)")
                let sourceStart: String.Index = try #require(stop.caption.range(of: " (\(title)).")?.lowerBound)
                let measured = String(stop.caption[..<sourceStart])
                var allowed: Set<String> = []
                for quantity in body.storedQuantities {
                    if let value = body.value(of: quantity) { allowed.insert(Units.storedText(value)) }
                }
                let found: [String] = numbers(in: measured)
                #expect(!found.isEmpty, "\(stop.caption)")
                for number in found {
                    #expect(allowed.contains(number), "\(body.id): \(number) in \(stop.caption)")
                }
                #expect(measured.contains("\(Units.storedText(body.meanRadiusKm)) km"), "\(stop.caption)")
                if let period = body.siderealPeriodDays {
                    #expect(measured.contains("\(Units.storedText(period)) days"), "\(stop.caption)")
                }
            }
        }
    }

    @Test func captionsReadAsSpecified() {
        #expect(Tour.caption(bodyIndex: 0)
            == "Sun: mean radius 695,700 km (Resolution B3 on recommended nominal conversion constants).")
        #expect(Tour.caption(bodyIndex: 4)
            == "Mars: mean radius 3,389.5 km; one orbit takes 686.98 days (Planetary Fact Sheet — Metric).")
        #expect(Tour.caption(bodyIndex: 9) == "")
        #expect(Tour.caption(bodyIndex: -1) == "")
    }
}
