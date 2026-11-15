// Units — feature 103 (A14-P01) T-A14-102 (FR-A14-102; clarification Q2; data-model "Units"; SC-A14-102). The explicit
// unit conversions of Solar System Explorer: kilometres ↔ astronomical units through the defined constant
// 1 AU = 149,597,870.7 km (IAU 2012 Resolution B2), and days ↔ Julian years through 365.25 days. Distances are stored
// in kilometres and times in days; AU and years are always derived here, never stored. A non-finite or negative
// magnitude is refused (nil), so no conversion ever produces a value that cannot be shown with its unit.
//
// The display formatting of numbers (`Units.text(_:fractionDigits:trimZeros:)`, `Units.storedText(_:)`) is also here:
// it is deterministic and locale-free (a "." decimal point and "," grouping of thousands), so fact cards and the
// committed data-sources document give the same text on every device.
import Foundation

/// Explicit unit conversions (km ↔ AU, days ↔ Julian years) and deterministic number text.
public enum Units {
    /// Kilometres per astronomical unit (exact, by definition).
    public static let kmPerAU: Double = 149_597_870.7
    /// Days per Julian year (exact, by definition).
    public static let daysPerJulianYear: Double = 365.25

    /// `km` in astronomical units; nil for a non-finite or negative value.
    public static func au(fromKm km: Double) -> Double? {
        guard isMagnitude(km) else { return nil }
        return km / kmPerAU
    }

    /// `au` in kilometres; nil for a non-finite or negative value (or a result that is not finite).
    public static func km(fromAU au: Double) -> Double? {
        guard isMagnitude(au) else { return nil }
        let km = au * kmPerAU
        return km.isFinite ? km : nil
    }

    /// `days` in Julian years; nil for a non-finite or negative value.
    public static func years(fromDays days: Double) -> Double? {
        guard isMagnitude(days) else { return nil }
        return days / daysPerJulianYear
    }

    /// `years` (Julian) in days; nil for a non-finite or negative value (or a result that is not finite).
    public static func days(fromYears years: Double) -> Double? {
        guard isMagnitude(years) else { return nil }
        let days = years * daysPerJulianYear
        return days.isFinite ? days : nil
    }

    /// True when `value` is a finite magnitude of zero or more.
    public static func isMagnitude(_ value: Double) -> Bool { value.isFinite && value >= 0 }

    /// `value` rounded to `fractionDigits` decimals with "," grouping of thousands and a "." decimal point
    /// (locale-free); with `trimZeros`, trailing fraction zeros (and a bare point) are dropped. "—" for a non-finite
    /// value. Examples: `text(6371.0, fractionDigits: 1, trimZeros: true)` is "6,371", `text(0.38709, fractionDigits:
    /// 3)` is "0.387".
    public static func text(_ value: Double, fractionDigits: Int, trimZeros: Bool = false) -> String {
        guard value.isFinite else { return "—" }
        let digits = min(max(fractionDigits, 0), 12)
        var plain = String(format: "%.\(digits)f", value)
        if trimZeros, plain.contains(".") {
            while plain.hasSuffix("0") { plain.removeLast() }
            if plain.hasSuffix(".") { plain.removeLast() }
        }
        if plain == "-0" { plain = "0" }
        return grouped(plain)
    }

    /// A stored value exactly as stored (the shortest decimal text that reads back to the same `Double`, never in
    /// exponent form for the catalog's magnitudes) with "," grouping of thousands: 57909000 is "57,909,000", 2439.7 is
    /// "2,439.7", 0.034 is "0.034". "—" for a non-finite value.
    public static func storedText(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        var plain = "\(value)"
        if plain.contains("e") || plain.contains("E") {
            plain = String(format: "%.0f", value)
        }
        if plain.hasSuffix(".0") { plain.removeLast(2) }
        return grouped(plain)
    }

    /// `plain` ("-1234567.89") with its integer part grouped by thousands ("-1,234,567.89").
    private static func grouped(_ plain: String) -> String {
        var sign = ""
        var body = Substring(plain)
        if body.hasPrefix("-") {
            sign = "-"
            body = body.dropFirst()
        }
        let parts = body.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let integer = Array(parts[0])
        var result = ""
        for (offset, character) in integer.enumerated() {
            if offset > 0, (integer.count - offset) % 3 == 0 { result.append(",") }
            result.append(character)
        }
        if parts.count > 1 { result += "." + parts[1] }
        return sign + result
    }
}
