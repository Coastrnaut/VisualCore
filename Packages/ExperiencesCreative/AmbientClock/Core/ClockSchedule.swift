// ClockSchedule — feature 131 T-A18-107 (FR-A18-105; G-FORMAT; research D3). The next instant at which the clock's
// text can change. Pure arithmetic on the given instant; reads no clock.
import Foundation

/// Computes the clock's next redraw deadline.
public enum ClockSchedule {
    /// The first instant strictly after `after` that is a whole second (when `showSeconds`) or a whole minute in
    /// `calendar`'s time zone (otherwise). The zone offset at `after` is used, which is exact across daylight saving
    /// transitions because every current offset is a whole number of minutes.
    public static func nextDeadline(after: Date, showSeconds: Bool, calendar: Calendar) -> Date {
        let step: Double = showSeconds ? 1 : 60
        let offset = Double(calendar.timeZone.secondsFromGMT(for: after))
        let local = after.timeIntervalSinceReferenceDate + offset
        var next = (local / step).rounded(.down) * step + step
        if next <= local { next += step }
        return Date(timeIntervalSinceReferenceDate: next - offset)
    }
}
