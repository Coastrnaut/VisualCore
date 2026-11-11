// GoToInput.swift — parsing and validation for "Go to coordinates" (feature 028 T-A03-308; FR-A03-305; US4;
// research R4; clarification 1). The zoom is the spoken magnification: span = the mode's default width ÷ zoom.
import Foundation
import VisualCoreMath

/// A validated Go to request.
public struct GoToTarget: Equatable, Sendable {
    /// The plane point to center.
    public let center: Vec2
    /// The magnification (as in the canvas description).
    public let zoom: Double

    /// The framing for `mode`: span = default width ÷ zoom.
    public func framing(for mode: FractalMode) -> PlaneFraming {
        PlaneFraming(center: center, span: FractalState.defaultWidth(for: mode) / zoom)
    }
}

/// What is wrong with a Go to entry.
public struct GoToError: Error, Equatable, Sendable {
    /// The entry with the problem.
    public enum Field: String, Sendable { case real, imaginary, zoom }
    /// The entry with the problem.
    public let field: Field
    /// The text shown under the fields.
    public let message: String
}

/// Parses the three Go to fields.
public enum GoToInput {
    /// The largest |real| or |imaginary| accepted.
    public static let maxCoordinate = Bookmark.maxCoordinate
    /// The largest zoom accepted.
    public static let maxZoom = 1e15

    /// Trims the text, accepts "." or the locale's decimal separator and a leading "−" (U+2212), and parses a finite
    /// number; nil otherwise.
    public static func number(_ text: String, locale: Locale = .current) -> Double? {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("\u{2212}") { t = "-" + t.dropFirst() }
        if let sep = locale.decimalSeparator, sep != "." { t = t.replacingOccurrences(of: sep, with: ".") }
        t = t.replacingOccurrences(of: " ", with: "")
        guard !t.isEmpty, let v = Double(t), v.isFinite else { return nil }
        return v
    }

    /// The target, or the first problem (real, then imaginary, then zoom).
    public static func parse(real: String, imaginary: String, zoom: String,
                             locale: Locale = .current) -> Result<GoToTarget, GoToError> {
        func coordinate(_ text: String, _ field: GoToError.Field) -> Result<Double, GoToError> {
            guard let v = number(text, locale: locale) else { return .failure(GoToError(field: field, message: "Enter a number")) }
            guard abs(v) <= maxCoordinate else {
                return .failure(GoToError(field: field, message: "Use a value between −4 and 4"))
            }
            return .success(v)
        }
        let x: Double, y: Double
        switch coordinate(real, .real) { case .success(let v): x = v; case .failure(let e): return .failure(e) }
        switch coordinate(imaginary, .imaginary) { case .success(let v): y = v; case .failure(let e): return .failure(e) }
        guard let z = number(zoom, locale: locale) else { return .failure(GoToError(field: .zoom, message: "Enter a number")) }
        guard z > 0, z <= maxZoom else {
            return .failure(GoToError(field: .zoom, message: "Zoom must be above 0 and at most 1e15"))
        }
        return .success(GoToTarget(center: Vec2(x, y), zoom: z))
    }
}
