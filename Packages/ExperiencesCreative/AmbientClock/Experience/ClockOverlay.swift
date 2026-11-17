// ClockOverlay — feature 132 T-A18-203 (FR-A18-203, FR-A18-205, FR-A18-206; G-OVERLAY; clarifications Q2, Q4;
// research D2, D5; edge cases "Very large text", "Seconds shown", "Rendering unavailable"). The clock's time and date,
// drawn by the native overlay over the canvas (`ExperiencePresenter.makeCanvasOverlay(_:)`) with system fonts, never by
// the shader:
//
//   - Layout: the time is centred, the date below it. The time's font is the system font at 0.22 × the shorter canvas
//     side × the Dynamic Type factor, capped so the longest time text fits 90 % of the canvas width on one line
//     (`timeFontSize(canvas:dynamicTypeFactor:characters:)`, estimating a glyph as 0.6 × the font size), with
//     `minimumScaleFactor` 0.3 as the last resort. The date uses the title style. Both are white
//     (`NoiseGradientTheme.textColor`, at least 4.5 : 1 against every palette colour), without shadow.
//   - Ticking: a task calls `AmbientPresenter.tick(port:)` and sleeps until the deadline it returns (measured on the
//     presenter's clock source, at least 0.05 s), so the text changes at each whole minute — each whole second with
//     seconds shown — with no per-frame text work, and stays correct while drawing is paused or unavailable. The task
//     restarts when the seconds switch changes and ends when the overlay disappears (cancellation).
//   - The host draws the overlay with hit testing off and hides it from assistive technology; the canvas label is
//     the spoken time (`AmbientPresenter.describe`). Nothing is announced.
//
// Feature 134 (A18-P04) T-A18-404/406 (FR-A18-401, FR-A18-405, FR-A18-406; G-NIGHT/G-SCREENCARE; clarifications Q2,
// Q3): at night the text is warm amber (`NightPolicy.textColor`, at least 4.5 : 1 against every dimmed and tinted
// palette colour), white by day; the overlay is offset by the presenter's shown drift (points, the same offset the
// scene moves by) and its opacity is multiplied by the idle dim. The overlay hands the presenter its display scale,
// which turns the drift into the scene's pixels.
import AmbientClockCore
import Foundation
import SwiftUI
import UIKit
import VisualCoreExperienceHost

/// The time and date over the canvas (see the file header).
struct ClockOverlay: View {
    /// The share of the shorter canvas side the time's font size takes at the default text size.
    static let timeShare = 0.22
    /// The share of the canvas width the time text may take.
    static let widthShare = 0.9
    /// The estimated width of one glyph of the time, as a share of the font size.
    static let glyphWidthShare = 0.6
    /// The smallest scale the time text may shrink to beyond the computed size.
    static let minimumScaleFactor = 0.3
    /// The shortest wait between two ticks, seconds.
    static let minimumSleep = 0.05
    /// The longest time text the layout is sized for: seconds and a day period, "00:00:00 PM".
    static let longestTime = "00:00:00 PM"
    /// The Dynamic Type factor of the largest accessibility size (body text: 53 points over 17).
    static let largestDynamicTypeFactor = 53.0 / 17.0

    /// The presenter that ticks the clock.
    let presenter: AmbientPresenter
    /// What the overlay shows.
    let mirror: AmbientMirror
    /// The port the ticks are sent through.
    let port: ExperienceActionPort
    /// The Dynamic Type factor: 1 at the default text size.
    @ScaledMetric(relativeTo: .body) private var typeFactor: CGFloat = 1
    /// The points-to-pixels factor of the screen, handed to the presenter.
    @Environment(\.displayScale) private var displayScale: CGFloat

    /// The text colour: `NightPolicy.textColor` at night, else white (`NoiseGradientTheme.textColor`).
    static func textColor(night: Bool) -> Color {
        guard night else { return Color(uiColor: NoiseGradientTheme.textColor) }
        let c = NightPolicy.textColor
        return Color(.sRGB, red: c.x, green: c.y, blue: c.z, opacity: 1)
    }

    /// The time's font size in points for a canvas of `canvas` points at the Dynamic Type factor `dynamicTypeFactor`
    /// (non-finite or not positive: 1): 0.22 × the shorter side × the factor, capped so `characters` glyphs fit 90 %
    /// of the width (`estimatedWidth(fontSize:characters:)` at most 0.9 × the width); 0 for an empty canvas.
    static func timeFontSize(canvas: CGSize, dynamicTypeFactor: Double,
                             characters: Int = ClockOverlay.longestTime.count) -> Double {
        let width = Double(canvas.width), height = Double(canvas.height)
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { return 0 }
        let factor = dynamicTypeFactor.isFinite && dynamicTypeFactor > 0 ? dynamicTypeFactor : 1
        let wanted = timeShare * min(width, height) * factor
        // A hair below the exact cap, so the estimated width never exceeds 90 % by a rounding error.
        let cap = widthShare * width / (glyphWidthShare * Double(max(characters, 1))) * (1 - 1e-12)
        return min(wanted, cap)
    }

    /// The estimated width in points of `characters` glyphs of the time at `fontSize`: fontSize × 0.6 × characters.
    static func estimatedWidth(fontSize: Double, characters: Int) -> Double {
        fontSize * glyphWidthShare * Double(max(characters, 0))
    }

    /// Whether `text` (by default the longest time) fits on one line within 90 % of the width of `canvas` at the size
    /// `timeFontSize` gives for `dynamicTypeFactor`, without the minimum scale factor.
    static func fits(canvas: CGSize, dynamicTypeFactor: Double, text: String = ClockOverlay.longestTime) -> Bool {
        let size = timeFontSize(canvas: canvas, dynamicTypeFactor: dynamicTypeFactor, characters: text.count)
        return size > 0 && estimatedWidth(fontSize: size, characters: text.count) <= widthShare * Double(canvas.width)
    }

    /// The seconds to sleep from `now` until `deadline`: their difference, at least 0.05 s (non-finite: 0.05 s).
    static func sleepInterval(until deadline: Date, now: Date) -> Double {
        let interval = deadline.timeIntervalSince(now)
        return interval.isFinite ? max(minimumSleep, interval) : minimumSleep
    }

    /// The overlay.
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let time = mirror.display?.time ?? ""
            let date = mirror.display?.date ?? ""
            let fontSize = Self.timeFontSize(canvas: size, dynamicTypeFactor: Double(typeFactor),
                                             characters: max(Self.longestTime.count, time.count))
            VStack(spacing: 8) {
                Text(verbatim: time)
                    .font(.system(size: max(fontSize, 1)).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(Self.minimumScaleFactor)
                if !date.isEmpty {
                    Text(verbatim: date)
                        .font(.title)
                        .lineLimit(2)
                        .minimumScaleFactor(Self.minimumScaleFactor)
                        .multilineTextAlignment(.center)
                }
            }
            .foregroundStyle(Self.textColor(night: mirror.isNight))
            .frame(maxWidth: max(0, size.width * Self.widthShare))
            .frame(width: size.width, height: size.height)
            .offset(x: mirror.drift.x, y: mirror.drift.y)
            .opacity(mirror.dim)
        }
        .onAppear { presenter.displayScale = Double(displayScale) }
        .onChange(of: displayScale) { _, scale in presenter.displayScale = Double(scale) }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: mirror.showSeconds) { await tickLoop() }
    }

    /// Ticks the clock and sleeps until each deadline, until the task is cancelled.
    private func tickLoop() async {
        while !Task.isCancelled {
            let deadline = presenter.tick(port: port)
            let interval = Self.sleepInterval(until: deadline, now: presenter.clock.now)
            do {
                try await Task.sleep(for: .seconds(interval))
            } catch {
                return
            }
        }
    }
}
