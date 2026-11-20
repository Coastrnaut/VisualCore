// LissajousLabyrinthControls — feature 313 (R02-G02-03) T-R02G0203-006 (FR-R02G0203-005; clarification Q5). The minimal
// control panel: a stepper for each of the four dials (frequency A and B 1 … 9, phase A and C 0 … 15), undo, redo and
// next level, each with an accessibility label and value; every change is a kernel action sent through the action port.
// Dials, gestures and the trace scrubber come in R02-G02-04; full accessibility in R02-G02-06.
#if os(iOS)
import LissajousLabyrinthCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Lissajous Labyrinth.
struct LissajousLabyrinthControls: View {
    let port: ExperienceActionPort
    let mirror: LissajousLabyrinthMirror

    /// The dials in control order with their names: frequency A, frequency B, phase A, phase C.
    private static let names: [String] = ["Frequency A", "Frequency B", "Phase A", "Phase C"]

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Level \(mirror.levelNumber) · actions \(mirror.spent) of \(mirror.allowance)")
                    .font(.headline)
                if let message = mirror.message {
                    Text(message).font(.footnote)
                }
                if let dials = mirror.dials {
                    ForEach(0..<4, id: \.self) { index in
                        let dial: LissajousLabyrinthDial = LissajousLabyrinthDial.allCases[index]
                        let value: Int = dials[dial]
                        Stepper("\(Self.names[index]) \(value)",
                                onIncrement: { set(index, dial: dial, to: value + 1) },
                                onDecrement: { set(index, dial: dial, to: value - 1) })
                            .accessibilityLabel(Self.names[index])
                            .accessibilityValue("\(value)")
                    }
                }
                HStack(spacing: 16) {
                    Button("Undo") { send("play.undo") }
                        .accessibilityLabel("Undo the last change")
                    Button("Redo") { send("play.redo") }
                        .accessibilityLabel("Redo the change")
                    Button("Next level") { send("level.next") }
                        .accessibilityLabel("Go to the next level")
                }
            }
            .padding()
        }
    }

    /// Sends `dial.set` for the dial at control index `index` to `value`, wrapped into the dial's range.
    private func set(_ index: Int, dial: LissajousLabyrinthDial, to value: Int) {
        let range = dial.range
        let span = range.upperBound - range.lowerBound + 1
        let wrapped = ((value - range.lowerBound) % span + span) % span + range.lowerBound
        send("dial.set", [Double(index), Double(wrapped)])
    }

    /// Sends `control` and shows a refusal.
    private func send(_ control: String, _ values: [Double] = []) {
        let result = port.send(control, values)
        mirror.message = result.isAccepted ? nil : "That change was refused: \(result.code)"
    }
}
#endif
