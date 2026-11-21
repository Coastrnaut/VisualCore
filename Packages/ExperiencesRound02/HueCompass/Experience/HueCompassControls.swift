// HueCompassControls — feature 333 (R02-G04-03) T-R02G0403-006 (FR-R02G0403-005; clarification Q5). The minimal
// control panel: turn buttons (−4, −1, +1, +4 bearings), probe, a band picker (0 … 23, presentation only) with select
// (the current bearing with the picked band), undo, redo and next level, each with an accessibility label and value;
// every change is a kernel action sent through the action port. Swipe and orbit come in R02-G04-04; full accessibility
// in R02-G04-06.
#if os(iOS)
import HueCompassCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Hue Compass.
struct HueCompassControls: View {
    let port: ExperienceActionPort
    let mirror: HueCompassMirror

    /// The turn steps of the four turn buttons, in order.
    static let turns: [Int] = [-4, -1, 1, 4]
    /// The button titles of the turn buttons.
    static let turnTitles: [String] = ["−4", "−1", "+1", "+4"]

    /// The spoken name of a turn of `steps` bearings (positive: counter-clockwise, the kernel's angle direction).
    static func turnLabel(_ steps: Int) -> String {
        let count: Int = abs(steps)
        let unit: String = count == 1 ? "bearing" : "bearings"
        let way: String = steps < 0 ? "clockwise" : "counter-clockwise"
        return "Turn the needle \(count) \(unit) \(way)"
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                turnRow
                bandPicker
                probeRow
                playRow
            }
            .padding()
        }
    }

    /// The level, units and bearing lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · units \(mirror.spent) of \(mirror.allowance)")
            .font(.headline)
        Text("Bearing \(mirror.bearing) · band \(mirror.bandUnderNeedle + 1) · clues \(mirror.clueCount)")
            .font(.subheadline)
        if let message = mirror.message {
            Text(message).font(.footnote)
        }
    }

    /// One button per turn step.
    @ViewBuilder private var turnRow: some View {
        HStack(spacing: 12) {
            ForEach(0..<Self.turns.count, id: \.self) { index in
                Button(Self.turnTitles[index]) { send("compass.turn", [Double(Self.turns[index])]) }
                    .accessibilityLabel(Self.turnLabel(Self.turns[index]))
                    .accessibilityValue("Bearing \(mirror.bearing) of 96")
            }
        }
    }

    /// The band picker for the next selection: previous and next band.
    @ViewBuilder private var bandPicker: some View {
        Stepper("Band \(mirror.pickedBand + 1) of 24",
                onIncrement: { mirror.pickedBand = (mirror.pickedBand + 1) % 24 },
                onDecrement: { mirror.pickedBand = (mirror.pickedBand + 23) % 24 })
            .accessibilityLabel("Hue band to select")
            .accessibilityValue("Band \(mirror.pickedBand + 1) of 24")
    }

    /// Probe and select.
    @ViewBuilder private var probeRow: some View {
        HStack(spacing: 16) {
            Button("Probe") { send("compass.probe") }
                .accessibilityLabel("Probe the bearing under the needle")
                .accessibilityValue("Bearing \(mirror.bearing), \(mirror.allowance - mirror.spent) units left")
            Button("Select") { send("compass.select", [Double(mirror.bearing), Double(mirror.pickedBand)]) }
                .accessibilityLabel("Select the bearing under the needle with the picked band")
                .accessibilityValue("Bearing \(mirror.bearing), band \(mirror.pickedBand + 1)")
        }
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        HStack(spacing: 16) {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last turn")
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the turn")
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
        }
    }

    /// Sends `control` and shows a refusal.
    private func send(_ control: String, _ values: [Double] = []) {
        let result = port.send(control, values)
        mirror.message = result.isAccepted ? nil : "That change was refused: \(result.code)"
    }
}
#endif
