// EventChecks — feature 107 (A14-P05) T-A14-502 (FR-A14-501; SC-A14-501; clarification Q1; data-model "EventFixture",
// "EventResult"; contracts/review.md). Checks of the approximate orbit model against published events: four Mars
// oppositions (2003-08-28, 2018-07-27, 2020-10-13, 2022-12-08; "Mars close approaches and oppositions", NASA Mars
// Exploration Program, public domain) and three Earth perihelia (2000-01-03, 2020-01-05, 2025-01-04; "Earth's Seasons
// and Apsides", US Naval Observatory, public domain), each with a tolerance of ±3 days.
//
// The published day is the published UTC date at 00:00 plus half a day (noon), as days since J2000.0
// (2000-01-01 12:00 UTC), so it is a whole number. `evaluate(_:)` searches day by day within ±10 days of it:
//   - opposition: the day when the body's and Earth's heliocentric ecliptic longitudes, atan2(y, x) of
//     `OrbitModel.position(bodyID:day:)`, are equal — a sign change of their difference wrapped into (−π, π] (a change
//     across ±π is a conjunction, not an opposition, and is skipped); the change nearest the published day is refined
//     by bisection to 0.01 day and the midpoint of the last interval is the model day;
//   - perihelion: the day of the body's least distance from the Sun — the least of the 21 daily distances, then the
//     least of a 0.01-day scan within ±1 day of it.
// The offset is model day − published day and the check passes when |offset| ≤ the tolerance. A fixture whose date
// does not parse, whose body the model does not know or whose event is not found in the window gives a non-finite
// model day and offset and does not pass. Pure and host-free (no wall clock).
import Foundation
import VisualCoreMath

/// The kind of a published event.
public enum EventKind: String, CaseIterable, Codable, Sendable {
    /// The body opposite the Sun as seen from Earth: equal heliocentric ecliptic longitudes.
    case opposition
    /// The body's least distance from the Sun.
    case perihelion
}

/// A published event the model is checked against.
public struct EventFixture: Equatable, Sendable {
    /// The event's name, such as "Mars opposition 2003".
    public let name: String
    /// The kind of event.
    public let kind: EventKind
    /// The catalog id of the body ("mars", "earth").
    public let bodyID: String
    /// The published UTC date, `yyyy-MM-dd`.
    public let publishedDate: String
    /// The largest allowed |model − published| in days (3).
    public let toleranceDays: Double
    /// The source of the published date.
    public let source: String

    /// Creates a fixture.
    public init(name: String, kind: EventKind, bodyID: String, publishedDate: String, toleranceDays: Double = 3,
                source: String) {
        self.name = name; self.kind = kind; self.bodyID = bodyID; self.publishedDate = publishedDate
        self.toleranceDays = toleranceDays; self.source = source
    }

    /// The source of the Mars oppositions.
    public static let marsSource = "Mars close approaches and oppositions, NASA Mars Exploration Program (public domain)"
    /// The source of the Earth perihelia.
    public static let earthSource = "Earth's Seasons and Apsides, US Naval Observatory (public domain)"

    /// The seven bundled fixtures of clarification Q1: four Mars oppositions, then three Earth perihelia.
    public static let bundled: [EventFixture] = {
        var fixtures: [EventFixture] = []
        let oppositions: [String] = ["2003-08-28", "2018-07-27", "2020-10-13", "2022-12-08"]
        for date in oppositions {
            fixtures.append(EventFixture(name: "Mars opposition \(date.prefix(4))", kind: .opposition, bodyID: "mars",
                                         publishedDate: date, source: marsSource))
        }
        let perihelia: [String] = ["2000-01-03", "2020-01-05", "2025-01-04"]
        for date in perihelia {
            fixtures.append(EventFixture(name: "Earth perihelion \(date.prefix(4))", kind: .perihelion,
                                         bodyID: "earth", publishedDate: date, source: earthSource))
        }
        return fixtures
    }()

    /// The published day: days since J2000.0 of the published date at 12:00 UTC; nil when the date does not parse.
    public var publishedDay: Double? { EventChecks.noonDay(of: publishedDate) }
}

/// The outcome of one event check.
public struct EventResult: Equatable, Sendable {
    /// The fixture checked.
    public let fixture: EventFixture
    /// The model's day of the event, days since J2000.0 (non-finite when not found).
    public let modelDay: Double
    /// The model day minus the published day, days (non-finite when not found).
    public let offsetDays: Double
    /// True when |offset| ≤ the fixture's tolerance.
    public let passed: Bool

    /// Creates a result.
    public init(fixture: EventFixture, modelDay: Double, offsetDays: Double, passed: Bool) {
        self.fixture = fixture; self.modelDay = modelDay; self.offsetDays = offsetDays; self.passed = passed
    }
}

/// The checks of the orbit model against published events (see the file header).
public enum EventChecks {
    /// The days searched on each side of the published day (10).
    public static let windowDays = 10
    /// The resolution of the refined event day (0.01 day).
    public static let resolutionDays = 0.01
    /// The body whose longitude an opposition is measured against.
    public static let observerID = "earth"

    /// The Gregorian calendar in UTC used to read dates.
    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    /// Days since J2000.0 of `date` (`yyyy-MM-dd`) at 12:00 UTC; nil when it does not parse.
    public static func noonDay(of date: String) -> Double? {
        let parts = date.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day) else { return nil }
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day
        components.hour = 0; components.minute = 0; components.second = 0
        guard let instant = utcCalendar.date(from: components) else { return nil }
        let check = utcCalendar.dateComponents([.year, .month, .day], from: instant)
        guard check.year == year, check.month == month, check.day == day else { return nil }
        let midnight = (instant.timeIntervalSince1970 - SimulatedDate.j2000UnixSeconds) / SimulatedDate.secondsPerDay
        return midnight + 0.5
    }

    /// The checks of every bundled fixture, in order.
    public static func evaluateBundled(model: OrbitModel = .bundled) -> [EventResult] {
        var results: [EventResult] = []
        for fixture in EventFixture.bundled { results.append(evaluate(fixture, model: model)) }
        return results
    }

    /// The check of `fixture` against `model` (see the file header).
    public static func evaluate(_ fixture: EventFixture, model: OrbitModel = .bundled) -> EventResult {
        guard let published = fixture.publishedDay else {
            return EventResult(fixture: fixture, modelDay: .nan, offsetDays: .nan, passed: false)
        }
        let found: Double?
        switch fixture.kind {
        case .opposition: found = opposition(bodyID: fixture.bodyID, near: published, model: model)
        case .perihelion: found = perihelion(bodyID: fixture.bodyID, near: published, model: model)
        }
        guard let day = found, day.isFinite else {
            return EventResult(fixture: fixture, modelDay: .nan, offsetDays: .nan, passed: false)
        }
        let offset = day - published
        return EventResult(fixture: fixture, modelDay: day, offsetDays: offset,
                           passed: abs(offset) <= fixture.toleranceDays)
    }

    /// The heliocentric ecliptic longitude of `bodyID` minus Earth's at `day`, radians wrapped into (−π, π]; nil for
    /// an unknown body.
    public static func longitudeDifference(bodyID: String, day: Double, model: OrbitModel = .bundled) -> Double? {
        guard let body = model.position(bodyID: bodyID, day: day),
              let earth = model.position(bodyID: observerID, day: day) else { return nil }
        let difference = atan2(body.y, body.x) - atan2(earth.y, earth.x)
        return atan2(sin(difference), cos(difference))
    }

    /// The opposition day of `bodyID` nearest `published` within the window, refined to 0.01 day; nil when none.
    static func opposition(bodyID: String, near published: Double, model: OrbitModel) -> Double? {
        var best: Double?
        for step in -windowDays..<windowDays {
            let lower = published + Double(step)
            let upper = lower + 1
            guard let a = longitudeDifference(bodyID: bodyID, day: lower, model: model),
                  let b = longitudeDifference(bodyID: bodyID, day: upper, model: model) else { return nil }
            // A sign change across ±π is a conjunction; only changes near zero are oppositions.
            guard abs(a) < Double.pi / 2, abs(b) < Double.pi / 2 else { continue }
            var crossing: Double?
            if a == 0 {
                crossing = lower
            } else if a * b < 0 {
                var low = lower
                var high = upper
                var lowValue = a
                while high - low > resolutionDays {
                    let mid = (low + high) / 2
                    guard let value = longitudeDifference(bodyID: bodyID, day: mid, model: model) else { return nil }
                    if lowValue * value <= 0 {
                        high = mid
                    } else {
                        low = mid
                        lowValue = value
                    }
                }
                crossing = (low + high) / 2
            }
            if let crossing, best.map({ abs(crossing - published) < abs($0 - published) }) ?? true {
                best = crossing
            }
        }
        return best
    }

    /// The perihelion day of `bodyID` near `published`: the least daily distance within the window, then the least
    /// of a 0.01-day scan within ±1 day of it; nil for an unknown body.
    static func perihelion(bodyID: String, near published: Double, model: OrbitModel) -> Double? {
        var bestDay = published
        var bestDistance = Double.infinity
        for step in -windowDays...windowDays {
            let day = published + Double(step)
            guard let distance = model.distanceAU(bodyID: bodyID, day: day) else { return nil }
            if distance < bestDistance {
                bestDistance = distance
                bestDay = day
            }
        }
        let center = bestDay
        let samples = Int((2 / resolutionDays).rounded())
        for index in 0...samples {
            let day = center - 1 + Double(index) * resolutionDays
            guard let distance = model.distanceAU(bodyID: bodyID, day: day) else { return nil }
            if distance < bestDistance {
                bestDistance = distance
                bestDay = day
            }
        }
        return bestDay
    }
}
