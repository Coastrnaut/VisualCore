// EchoCartographerControls — feature 403 (R02-G11-03) T-R02G1103-006 (FR-R02G1103-005; clarification Q5). The minimal
// control panel: labelled steppers for the cursor's column and row (presentation state only), pulse, claim and mark at
// the cursor (kernel actions through the action port), undo, redo and next level, each with an accessibility label and
// value. Tapping to emit, dragging markers and orbiting come in R02-G11-04; full accessibility in R02-G11-06.
#if os(iOS)
import EchoCartographerCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Echo Cartographer.
struct EchoCartographerControls: View {
    let port: ExperienceActionPort
    let mirror: EchoCartographerMirror

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                cursorRow
                cellRow
                playRow
            }
            .padding()
        }
    }

    /// The level, energy and stage lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · energy \(mirror.energy) of \(mirror.budget)")
            .font(.headline)
        Text(mirror.status).font(.subheadline)
        Text(mirror.measureLabel).font(.footnote)
        Text(mirror.targetLabel).font(.footnote)
        if let message = mirror.message {
            Text(message).font(.footnote)
        }
    }

    /// The column and row steppers.
    @ViewBuilder private var cursorRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Stepper(mirror.columnLabel,
                    onIncrement: { mirror.stepColumn(1) },
                    onDecrement: { mirror.stepColumn(-1) })
                .accessibilityLabel("Column of the chosen cell")
                .accessibilityValue(mirror.columnLabel)
            Stepper(mirror.rowLabel,
                    onIncrement: { mirror.stepRow(1) },
                    onDecrement: { mirror.stepRow(-1) })
                .accessibilityLabel("Row of the chosen cell")
                .accessibilityValue(mirror.rowLabel)
        }
    }

    /// Pulse, claim and mark at the cursor.
    @ViewBuilder private var cellRow: some View {
        HStack(spacing: 16) {
            Button("Pulse") { send("cell.pulse", cursorValues) }
                .accessibilityLabel("Send a pulse from the chosen cell")
                .accessibilityValue(mirror.cursorLabel)
            Button("Claim") { send("cell.claim", cursorValues) }
                .accessibilityLabel("Claim a beacon at the chosen cell")
                .accessibilityValue(mirror.cursorLabel)
            Button("Mark") { send("cell.mark", cursorValues) }
                .accessibilityLabel("Toggle a marker on the chosen cell")
                .accessibilityValue(mirror.cursorLabel)
        }
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        HStack(spacing: 16) {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last action")
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the action")
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
        }
    }

    /// The cursor as the values of a `cell.*` control.
    private var cursorValues: [Double] { [Double(mirror.column), Double(mirror.row)] }

    /// Sends `control` and shows a refusal.
    private func send(_ control: String, _ values: [Double] = []) {
        let result = port.send(control, values)
        mirror.message = result.isAccepted ? nil : "That change was refused: \(result.code)"
    }
}
#endif
