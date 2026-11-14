// SpectrumView — feature 063 (A08-P03) T-A08-302 (FR-A08-301, FR-A08-302, FR-A08-303; SC-A08-303; clarifications 4
// and 5; data-model "SpectrumView"). The geometry of the spectrum view, host-free and in the caller's units (the
// presenter passes pixels): a logarithmic frequency axis from 20 Hz to half the sample rate, x = log10(f ÷ 20) ÷
// log10(nyquist ÷ 20) × width; the bins reduced to pixel columns keeping the strongest bin of each column (columns with
// no bin are skipped, so the curve has at most one point per column); a level axis from −100 dBFS (and below) at the
// low edge to 0 dBFS at the high edge. Like `ScopeTrace`, y grows with the value (y-up): 0 dBFS maps to rect.y +
// height; the caller flips if its y axis points down. The decade marks (100 Hz, 1 kHz, 10 kHz below Nyquist) and the
// level marks every 20 dB are drawn as grid lines; their values are spoken and shown in the status text.
import Foundation

/// The axes, the column reduction and the points of the spectrum view.
public enum SpectrumView {
    /// The lowest frequency on the axis in hertz (the left edge).
    public static let minimumFrequency = 20.0
    /// The lowest level on the axis in dB relative to full scale (the low edge); lower levels sit on it.
    public static let floorDB = -100.0
    /// The level grid lines in dBFS, every 20 dB from 0 to −100.
    public static let levelMarks: [Double] = [0, -20, -40, -60, -80, -100]
    /// The decade grid lines in hertz (each shown only below Nyquist).
    public static let decadeFrequencies: [Double] = [100, 1_000, 10_000]
    /// The most pixel columns of one curve.
    public static let maximumWidth = 4_096

    /// The horizontal position of `frequency` on an axis `width` wide: log10(f ÷ 20) ÷ log10(nyquist ÷ 20) × width,
    /// where nyquist = `sampleRate` ÷ 2; `nil` below 20 Hz, above Nyquist, for a non-finite input or when Nyquist is
    /// not above 20 Hz.
    public static func x(frequency: Double, sampleRate: Double, width: Double) -> Double? {
        let nyquist = sampleRate / 2
        guard frequency.isFinite, nyquist.isFinite, width.isFinite, nyquist > minimumFrequency,
              frequency >= minimumFrequency, frequency <= nyquist else { return nil }
        return log10(frequency / minimumFrequency) / log10(nyquist / minimumFrequency) * width
    }

    /// The strongest level of each pixel column: for bins k = 1…size/2−1 (and within `magnitudesDB`) at
    /// f = k · `sampleRate` ÷ `size` ≥ 20 Hz, the column Int(x(f)) clamped to 0…width−1 keeps the largest finite
    /// level among its bins. One entry per non-empty column, sorted by column; `width` is clamped to 1…4,096.
    public static func columns(magnitudesDB: [Float], sampleRate: Double, size: Int,
                               width: Int) -> [(column: Int, levelDB: Double)] {
        let width = min(max(width, 1), maximumWidth)
        let lastBin = min(size / 2, magnitudesDB.count)
        guard size > 0, lastBin > 1 else { return [] }
        var best = [Double?](repeating: nil, count: width)
        for k in 1..<lastBin {
            let level = Double(magnitudesDB[k])
            guard level.isFinite,
                  let x = x(frequency: Double(k) * sampleRate / Double(size), sampleRate: sampleRate,
                            width: Double(width)) else { continue }
            let column = min(max(Int(x), 0), width - 1)
            if let current = best[column], current >= level { continue }
            best[column] = level
        }
        return best.enumerated().compactMap { column, level in level.map { (column: column, levelDB: $0) } }
    }

    /// The curve through `columns` inside `rect`, one point per entry in order: x at the column's centre,
    /// rect.x + (column + 0.5) ÷ `columnCount` × width, and y = rect.y + (clamp(level, −100…0) + 100) ÷ 100 × height,
    /// so 0 dBFS is the high edge rect.y + height and −100 dBFS (and below) the low edge rect.y (y-up, like
    /// `ScopeTrace`). Empty when `columnCount` is not positive.
    public static func points(_ columns: [(column: Int, levelDB: Double)],
                              in rect: (x: Double, y: Double, width: Double, height: Double),
                              columnCount: Int) -> [TracePoint] {
        guard columnCount > 0 else { return [] }
        let n = Double(columnCount)
        return columns.map { entry in
            TracePoint(x: rect.x + (Double(entry.column) + 0.5) / n * rect.width,
                       y: rect.y + (clampedLevel(entry.levelDB) - floorDB) / -floorDB * rect.height)
        }
    }

    /// The decade marks below Nyquist (100 Hz, 1 kHz, 10 kHz where in range) with their x on an axis `width` wide.
    public static func decadeMarks(sampleRate: Double, width: Double) -> [(frequency: Double, x: Double)] {
        decadeFrequencies.compactMap { f in
            guard f < sampleRate / 2, let x = x(frequency: f, sampleRate: sampleRate, width: width) else { return nil }
            return (frequency: f, x: x)
        }
    }

    /// `level` clamped to −100…0 dBFS (a non-finite level counts as the floor).
    public static func clampedLevel(_ level: Double) -> Double {
        level.isFinite ? min(max(level, floorDB), 0) : floorDB
    }
}
