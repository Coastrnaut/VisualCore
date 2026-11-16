// SimulationLegend — feature 119 (A16-P03) T-A16-306 (FR-A16-320; clarification Q5). The legend of the canvas overlay
// (`makeCanvasOverlay(_:)` returns it): on an opaque panel at the bottom-leading corner of the canvas, the family's
// colour bar from `SimulationPalette` and the current values of the CPU field:
//   reaction-diffusion  the minimum and maximum of the inhibitor v (channel 1), the value the palette colours, over the
//                       stops at t = 0, 0.5 and 1;
//   wave field          the minimum and maximum of the signed height (channel 0), over negative → zero → positive;
//   cellular automaton  the alive (value ≥ 0.5) and dead counts, over a dead and an alive swatch.
// The text is in the system caption style (Dynamic Type). The canvas description states the same values
// (`SimulationLegendValues.words`), so the legend view itself is hidden from VoiceOver and takes no touches.
// NaN values are ignored for the minimum and maximum (all NaN: 0 and 0); numbers have two decimals, negative zero
// printed as 0.00.
import SimulationLabCore
import SwiftUI
import VisualCoreSimulation

/// The values the legend shows for one field and family.
struct SimulationLegendValues: Equatable, Sendable {
    /// The family the values belong to.
    var kind: SimulationKind
    /// The smallest value (reaction-diffusion: v; wave: height; automaton: 0).
    var minimum: Float
    /// The largest value (reaction-diffusion: v; wave: height; automaton: 1).
    var maximum: Float
    /// The automaton's alive cells (0 for the other families).
    var alive: Int
    /// The automaton's dead cells (0 for the other families).
    var dead: Int

    /// The legend values of `field` for `kind`: the minimum and maximum of v (reaction-diffusion) or the height (wave),
    /// NaN ignored (all NaN: 0 and 0); for the automaton the alive (≥ 0.5) and dead counts with minimum 0 and maximum 1.
    static func of(_ field: SimulationField, kind: SimulationKind) -> SimulationLegendValues {
        let grid = field.current
        let cells = grid.width * grid.height
        let channels = max(1, grid.channels)
        switch kind {
        case .automaton:
            var alive = 0
            for index in 0..<cells where index * channels < grid.values.count {
                if grid.values[index * channels] >= 0.5 { alive += 1 }
            }
            return SimulationLegendValues(kind: kind, minimum: 0, maximum: 1, alive: alive, dead: cells - alive)
        case .reactionDiffusion, .wave:
            let channel = kind == .reactionDiffusion ? min(1, channels - 1) : 0
            var low = Float.infinity
            var high = -Float.infinity
            for index in 0..<cells {
                let position = index * channels + channel
                guard position < grid.values.count else { break }
                let value = grid.values[position]
                if value.isNaN { continue }
                low = min(low, value)
                high = max(high, value)
            }
            if low > high { low = 0; high = 0 }
            return SimulationLegendValues(kind: kind, minimum: low, maximum: high, alive: 0, dead: 0)
        }
    }

    /// `value` with two decimals ("0.12"); negative zero is printed as "0.00".
    static func twoDecimals(_ value: Float) -> String {
        let text = String(format: "%.2f", Double(value))
        return text == "-0.00" ? "0.00" : text
    }

    /// The legend's title: "Inhibitor v", "Height" or "Cells".
    var title: String {
        switch kind {
        case .reactionDiffusion: return "Inhibitor v"
        case .wave: return "Height"
        case .automaton: return "Cells"
        }
    }

    /// The legend in words for the canvas description: "Legend: inhibitor from 0.12 to 0.34.",
    /// "Legend: height from -0.25 to 0.40." or "Legend: 120 alive, 3976 dead.".
    var words: String {
        switch kind {
        case .reactionDiffusion:
            return "Legend: inhibitor from \(Self.twoDecimals(minimum)) to \(Self.twoDecimals(maximum))."
        case .wave:
            return "Legend: height from \(Self.twoDecimals(minimum)) to \(Self.twoDecimals(maximum))."
        case .automaton:
            return "Legend: \(alive) alive, \(dead) dead."
        }
    }
}

/// The legend panel of the canvas overlay: title, colour bar and values, hidden from VoiceOver (the canvas description
/// says the same) and transparent to touches.
struct SimulationLegend: View {
    /// What the legend shows.
    let values: SimulationLegendValues
    /// The histogram drawn under the bar (feature 120, FR-A16-420); none when nil.
    var histogram: SimulationHistogram?

    /// A SwiftUI colour from palette bytes.
    static func color(_ rgb: SimulationPalette.RGB) -> Color {
        Color(red: Double(rgb.r) / 255, green: Double(rgb.g) / 255, blue: Double(rgb.b) / 255)
    }

    /// The colour stops of the family's bar, left to right.
    static func stops(_ kind: SimulationKind) -> [Color] {
        switch kind {
        case .reactionDiffusion: return SimulationPalette.reactionStops.map(color)
        case .wave:
            return [color(SimulationPalette.waveNegative), color(SimulationPalette.waveZero),
                    color(SimulationPalette.wavePositive)]
        case .automaton: return [color(SimulationPalette.dead), color(SimulationPalette.alive)]
        }
    }

    /// The 16 histogram bars, 120 points wide and at most 24 high, each as tall as its share of the fullest bin.
    private func bars(_ histogram: SimulationHistogram) -> some View {
        let fullest = max(1, histogram.bins.max() ?? 1)
        return HStack(alignment: .bottom, spacing: 1) {
            ForEach(histogram.bins.indices, id: \.self) { index in
                Rectangle()
                    .fill(Self.textColor)
                    .frame(width: 6.5, height: max(1, 24 * CGFloat(histogram.bins[index]) / CGFloat(fullest)))
            }
        }
        .frame(height: 24, alignment: .bottom)
    }

    /// The text colour on the panel.
    private static let textColor = Color.white.opacity(0.92)

    /// The panel at the bottom-leading corner of a full-size frame.
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: values.title).font(.caption).foregroundStyle(Self.textColor)
            bar
            labels
            if let histogram { bars(histogram) }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Self.color(SimulationPalette.background).opacity(1))
        )
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .accessibilityIdentifier("sim.legend")
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    /// The colour bar: a gradient of the palette stops, or the automaton's dead and alive swatches.
    @ViewBuilder private var bar: some View {
        if values.kind == .automaton {
            HStack(spacing: 0) {
                Rectangle().fill(Self.color(SimulationPalette.dead))
                Rectangle().fill(Self.color(SimulationPalette.alive))
            }
            .frame(minWidth: 120, minHeight: 10, maxHeight: 10)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            Rectangle()
                .fill(LinearGradient(colors: Self.stops(values.kind), startPoint: .leading, endPoint: .trailing))
                .frame(minWidth: 120, minHeight: 10, maxHeight: 10)
        }
    }

    /// The minimum and maximum under the bar, or the automaton's dead and alive counts.
    @ViewBuilder private var labels: some View {
        HStack {
            if values.kind == .automaton {
                Text(verbatim: "\(values.dead) dead")
                Spacer(minLength: 8)
                Text(verbatim: "\(values.alive) alive")
            } else {
                Text(verbatim: SimulationLegendValues.twoDecimals(values.minimum))
                Spacer(minLength: 8)
                Text(verbatim: SimulationLegendValues.twoDecimals(values.maximum))
            }
        }
        .font(.caption)
        .foregroundStyle(Self.textColor)
        .frame(minWidth: 120)
    }
}

/// The legend read from the presenter's mirror, so it follows the field without re-making the overlay.
struct SimulationLegendOverlay: View {
    /// What the controls and the legend show.
    let mirror: SimulationMirror

    /// The legend of the mirror's values; nothing before the first state.
    var body: some View {
        if let values = mirror.legend {
            SimulationLegend(values: values, histogram: mirror.histogram)
        }
    }
}
