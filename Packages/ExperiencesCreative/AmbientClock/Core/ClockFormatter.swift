// ClockFormatter — feature 131 T-A18-105 (FR-A18-104; G-FORMAT; research D2). Formats an instant into the clock's
// time line, date line and spoken string with the system's own locale data. Pure Foundation; reads no clock.
import Foundation

/// The text the clock shows and speaks for one instant.
public struct ClockDisplay: Equatable, Sendable {
    /// The time line (for example "10:42 PM" or "22:42:05").
    public var time: String
    /// The full date line, or the empty string when the date line is off.
    public var date: String
    /// The spoken string: the time text, then ", " and the date when the date line is on.
    public var spoken: String

    /// Creates a display.
    public init(time: String, date: String, spoken: String) {
        self.time = time
        self.date = date
        self.spoken = spoken
    }
}

/// Formats instants for the clock. Formatters are cached per (locale, zone, template) behind a lock.
public enum ClockFormatter {
    /// The `DateFormatter` template for the time line: `jmm` (system), `hmma` (h12) or `HHmm` (h24), with `ss`
    /// appended when seconds are shown.
    public static func timeTemplate(hourCycle: HourCycle, showSeconds: Bool) -> String {
        let base: String
        switch hourCycle {
        case .system: base = "jmm"
        case .h12: base = "hmma"
        case .h24: base = "HHmm"
        }
        return showSeconds ? base + "ss" : base
    }

    /// The display for `date` under `preferences` in `environment`.
    public static func display(at date: Date, preferences: ClockPreferences,
                               environment: ClockEnvironment) -> ClockDisplay {
        let template = timeTemplate(hourCycle: preferences.hourCycle, showSeconds: preferences.showSeconds)
        let time = FormatterCache.shared.string(from: date, environment: environment, key: .template(template))
        let dateText = preferences.showDate
            ? FormatterCache.shared.string(from: date, environment: environment, key: .fullDate)
            : ""
        let spoken = dateText.isEmpty ? time : time + ", " + dateText
        return ClockDisplay(time: time, date: dateText, spoken: spoken)
    }

    /// Whether `locale` uses a 12-hour clock: its localized format for the template `j` contains a day period (`a`).
    public static func usesTwelveHourClock(locale: Locale) -> Bool {
        (DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale) ?? "").contains("a")
    }
}

/// A lock-protected cache of configured date formatters. `DateFormatter` is used for formatting only after it is
/// configured, under the lock, so sharing it is safe.
private final class FormatterCache: @unchecked Sendable {
    enum Style: Hashable {
        case template(String)
        case fullDate
    }

    struct Key: Hashable {
        var locale: String
        var zone: String
        var style: Style
    }

    static let shared = FormatterCache()

    private let lock = NSLock()
    private var formatters: [Key: DateFormatter] = [:]

    func string(from date: Date, environment: ClockEnvironment, key style: Style) -> String {
        let key = Key(locale: environment.locale.identifier, zone: environment.timeZone.identifier, style: style)
        lock.lock()
        defer { lock.unlock() }
        let formatter: DateFormatter
        if let cached = formatters[key] {
            formatter = cached
        } else {
            formatter = DateFormatter()
            formatter.locale = environment.locale
            formatter.timeZone = environment.timeZone
            formatter.calendar = environment.calendar
            switch style {
            case .template(let template):
                formatter.setLocalizedDateFormatFromTemplate(template)
            case .fullDate:
                formatter.dateStyle = .full
                formatter.timeStyle = .none
            }
            formatters[key] = formatter
        }
        return formatter.string(from: date)
    }
}
