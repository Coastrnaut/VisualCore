// Tours — feature 106 (A14-P04) T-A14-404 (FR-A14-403, FR-A14-410; SC-A14-403; clarification Q2; data-model "Tour",
// "TourStop"). The guided tours of Solar System Explorer: "Inner planets" (the Sun, Mercury, Venus, Earth, Mars;
// catalog indices 0…4) and "Giant planets" (Jupiter, Saturn, Uranus, Neptune; indices 5…8). Each stop holds 600 host
// steps (5 s at 120 steps per second), so the tours last 25 s and 20 s (at most `Tour.maxStops` = 6 stops and 40 s).
// Captions are built from the bundled catalog, never typed by hand: the Sun "Sun: mean radius 695,700 km (Resolution
// B3 on recommended nominal conversion constants)."; a planet "Mars: mean radius 3,389.5 km; one orbit takes
// 686.98 days (Planetary Fact Sheet — Metric)." — the stored values through `Units.storedText` with their units and
// the title of the body's mean-radius source record.
import Foundation

/// One stop of a tour: the body shown, how long it is held and its caption.
public struct TourStop: Equatable, Sendable {
    /// The catalog index of the body.
    public let bodyIndex: Int
    /// The host steps the stop is held (600 = 5 s).
    public let holdSteps: Int
    /// The caption shown and spoken at the stop.
    public let caption: String

    /// Creates a stop.
    public init(bodyIndex: Int, holdSteps: Int, caption: String) {
        self.bodyIndex = bodyIndex; self.holdSteps = holdSteps; self.caption = caption
    }
}

/// A guided tour: an ordered list of stops.
public struct Tour: Equatable, Sendable {
    /// The tour's id ("inner-planets", "giant-planets").
    public let id: String
    /// The tour's title ("Inner planets").
    public let title: String
    /// The stops in visiting order.
    public let stops: [TourStop]

    /// Creates a tour.
    public init(id: String, title: String, stops: [TourStop]) {
        self.id = id; self.title = title; self.stops = stops
    }

    /// The most stops a tour may hold (6).
    public static let maxStops = 6
    /// The host steps each bundled stop is held (600 = 5 s).
    public static let holdSteps = 600

    /// The total host steps of the tour (the sum of its stops' hold steps).
    public var totalSteps: Int {
        var total = 0
        for stop in stops { total += stop.holdSteps }
        return total
    }

    /// The tour's duration in seconds (``totalSteps`` / 120).
    public var durationSeconds: Double { Double(totalSteps) * SimClock.stepSeconds }

    /// The caption of the catalog body at `index` built from `catalog` (see the file header); "" outside the catalog.
    public static func caption(bodyIndex index: Int, catalog: BodyCatalog = .bundled) -> String {
        guard let body = catalog.body(at: index) else { return "" }
        let title = catalog.source(bodyID: body.id, quantity: .meanRadius)?.title ?? ""
        var text = "\(body.name): mean radius \(Units.storedText(body.meanRadiusKm)) \(BodyQuantity.meanRadius.units)"
        if let period = body.siderealPeriodDays {
            text += "; one orbit takes \(Units.storedText(period)) \(BodyQuantity.siderealPeriod.units)"
        }
        return text + " (\(title))."
    }

    /// A bundled tour visiting `indices` in order, each held ``holdSteps``.
    private static func make(_ id: String, _ title: String, _ indices: [Int]) -> Tour {
        var stops: [TourStop] = []
        for index in indices {
            stops.append(TourStop(bodyIndex: index, holdSteps: holdSteps, caption: caption(bodyIndex: index)))
        }
        return Tour(id: id, title: title, stops: stops)
    }

    /// The bundled tours: "Inner planets" (0, 1, 2, 3, 4) and "Giant planets" (5, 6, 7, 8).
    public static let bundled: [Tour] = [
        make("inner-planets", "Inner planets", [0, 1, 2, 3, 4]),
        make("giant-planets", "Giant planets", [5, 6, 7, 8]),
    ]
}
