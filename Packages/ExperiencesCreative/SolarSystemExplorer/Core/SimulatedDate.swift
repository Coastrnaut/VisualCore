// SimulatedDate — feature 104 (A14-P02) T-A14-204 (FR-A14-211; clarification Q3; research D3; data-model
// "SimulatedDate"; SC-A14-203). The simulated date of Solar System Explorer as days since J2000.0
// (2000-01-01 12:00 UTC; TT and UTC are not distinguished, the difference is far below the model's accuracy), allowed
// in −18,262.5 … 18,627.5 (1950-01-01 00:00 to 2051-01-01 00:00 UTC; the spec's "2050-12-31 00:00" would be
// 18,626.5, the specified constant 18,627.5 is kept) and started at 0. A step is one of ±1, ±30 and ±365 days; any
// other step is refused `a14.invalid-step`, and a step that would leave the range is refused `a14.out-of-range`; a
// refused step changes nothing. Steps are whole days, so any sequence of steps followed by its reverse returns exactly
// to the start in `Double`. `label` is the UTC calendar date `yyyy-MM-dd`, computed with a Gregorian calendar in the
// UTC time zone (locale en_US_POSIX), so it is the same on every device.
import Foundation

/// Why a date step was refused.
public enum DateStepRefusal: String, CaseIterable, Codable, Error, Sendable {
    /// A step that is not one of ±1, ±30, ±365 days.
    case invalidStep = "a14.invalid-step"
    /// A step that would leave −18,262.5 … 18,627.5 days.
    case outOfRange = "a14.out-of-range"
}

/// A simulated date: days since J2000.0 (2000-01-01 12:00 UTC).
public struct SimulatedDate: Equatable, Hashable, Sendable {
    /// The allowed day offsets (1950-01-01 00:00 to 2051-01-01 00:00 UTC).
    public static let range: ClosedRange<Double> = -18_262.5 ... 18_627.5
    /// The allowed steps in days.
    public static let allowedSteps: Set<Int> = [-365, -30, -1, 1, 30, 365]
    /// J2000.0 as seconds since 1970-01-01 00:00 UTC (2000-01-01 12:00 UTC).
    public static let j2000UnixSeconds: Double = 946_728_000
    /// Seconds per day.
    public static let secondsPerDay: Double = 86_400
    /// J2000.0 itself (day 0), the start date.
    public static let j2000 = SimulatedDate(unchecked: 0)

    /// Days since J2000.0, within ``range``.
    public let dayOffset: Double

    /// The date `dayOffset` days after J2000.0; nil for a non-finite value or one outside ``range``.
    public init?(dayOffset: Double) {
        guard dayOffset.isFinite, Self.range.contains(dayOffset) else { return nil }
        self.dayOffset = dayOffset
    }

    /// A date already known to be in range.
    private init(unchecked dayOffset: Double) { self.dayOffset = dayOffset }

    /// The date `days` later; `.invalidStep` for a step outside ``allowedSteps`` and `.outOfRange` when the result
    /// would leave ``range``.
    public func stepped(by days: Int) -> Result<SimulatedDate, DateStepRefusal> {
        guard Self.allowedSteps.contains(days) else { return .failure(.invalidStep) }
        let next = dayOffset + Double(days)
        guard Self.range.contains(next) else { return .failure(.outOfRange) }
        return .success(SimulatedDate(unchecked: next))
    }

    /// The instant of this date.
    public var date: Date { Date(timeIntervalSince1970: Self.j2000UnixSeconds + dayOffset * Self.secondsPerDay) }

    /// The Gregorian calendar in UTC used for labels.
    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    /// The UTC calendar date `yyyy-MM-dd` ("2000-01-01" for day 0).
    public var label: String {
        let parts = Self.utcCalendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
