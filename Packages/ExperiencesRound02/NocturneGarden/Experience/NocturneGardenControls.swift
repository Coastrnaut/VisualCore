// NocturneGardenControls — feature 383 (R02-G09-03) T-R02G0903-006 (FR-R02G0903-005; clarification Q5). The minimal
// control panel: labelled pickers for the kind, the column, the row, the size and the bloom (presentation state only),
// plant, move, resize and remove (kernel actions through the action port), a sun picker (Sun − and +) with "Set sun"
// (feature 384: one move reaches any allowed elevation), undo, redo, next level and "Reset view", each with an
// accessibility label and value. Dragging stems, pinching to scale and sliding the sun come in R02-G09-04;
// full accessibility in R02-G09-06.
#if os(iOS)
import NocturneGardenCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Nocturne Garden.
struct NocturneGardenControls: View {
    let port: ExperienceActionPort
    let mirror: NocturneGardenMirror
    /// Returns the camera to the authored view (feature 384).
    let resetView: () -> Void
    /// Sends a control the way the presenter does (refusals shown and logged).
    let sender: (String, [Double]) -> Void

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                pickRow
                bloomRow
                playRow
            }
            .padding()
        }
    }

    /// The level, moves and stage lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · moves \(mirror.moves) of \(mirror.budget)")
            .font(.headline)
        Text(mirror.status).font(.subheadline)
        Text(mirror.measureLabel).font(.footnote)
        Text(mirror.targetLabel).font(.footnote)
        if let preview = mirror.previewText {
            // Feature 384 convergence (T-R02G0904-014): the drag's exact preview in words.
            Text("Dragging: " + preview).font(.footnote)
                .accessibilityLabel("Drag preview")
                .accessibilityValue(preview)
        }
        if let message = mirror.message {
            Text(message).font(.footnote)
        }
    }

    /// The kind, column, row and size pickers and the plant button.
    @ViewBuilder private var pickRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Stepper(mirror.kindLabel,
                    onIncrement: { mirror.pickKind(1) },
                    onDecrement: { mirror.pickKind(-1) })
                .accessibilityLabel("Bloom kind to plant")
                .accessibilityValue(mirror.kindLabel)
            Stepper(mirror.columnLabel,
                    onIncrement: { mirror.stepColumn(1) },
                    onDecrement: { mirror.stepColumn(-1) })
                .accessibilityLabel("Column of the anchor cell")
                .accessibilityValue(mirror.columnLabel)
            Stepper(mirror.rowLabel,
                    onIncrement: { mirror.stepRow(1) },
                    onDecrement: { mirror.stepRow(-1) })
                .accessibilityLabel("Row of the anchor cell")
                .accessibilityValue(mirror.rowLabel)
            Stepper(mirror.sizeLabel,
                    onIncrement: { mirror.stepSize(1) },
                    onDecrement: { mirror.stepSize(-1) })
                .accessibilityLabel("Bloom size")
                .accessibilityValue(mirror.sizeLabel)
            Button("Plant") {
                send("bloom.plant", [Double(mirror.kind), Double(mirror.column), Double(mirror.row),
                                     Double(mirror.size)])
            }
            .accessibilityLabel("Plant the chosen bloom at the chosen cell")
            .accessibilityValue(mirror.kindLabel + ", " + mirror.columnLabel + ", " + mirror.rowLabel + ", "
                                + mirror.sizeLabel)
        }
    }

    /// The bloom picker with move, resize and remove.
    @ViewBuilder private var bloomRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Stepper(mirror.bloomLabel,
                    onIncrement: { mirror.pickBloom(1) },
                    onDecrement: { mirror.pickBloom(-1) })
                .accessibilityLabel("Planted bloom to change")
                .accessibilityValue(mirror.bloomLabel)
            HStack(spacing: 12) {
                Button("Move") {
                    send("bloom.move", [Double(mirror.bloom), Double(mirror.column), Double(mirror.row)])
                }
                .accessibilityLabel("Move the chosen bloom to the chosen cell")
                Button("Resize") { send("bloom.resize", [Double(mirror.bloom), Double(mirror.size)]) }
                    .accessibilityLabel("Give the chosen bloom the chosen size")
                Button("Remove") { send("bloom.remove", [Double(mirror.bloom)]) }
                    .accessibilityLabel("Remove the chosen bloom")
            }
        }
    }

    /// Sun − and +, undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Button("Sun −") { mirror.stepSun(-1) }
                    .accessibilityLabel("Pick a higher sun")
                    .accessibilityValue(mirror.sunPickLabel)
                Text(mirror.sunPickLabel).font(.footnote)
                Button("Sun +") { mirror.stepSun(1) }
                    .accessibilityLabel("Pick a lower sun")
                    .accessibilityValue(mirror.sunPickLabel)
                Button("Set sun") { send("sun.set", [Double(mirror.sunPick)]) }
                    .accessibilityLabel("Move the sun to the picked elevation")
                    .accessibilityValue(mirror.sunLabel + "; picked " + mirror.sunPickLabel)
            }
            HStack(spacing: 16) {
                Button("Undo") { send("play.undo") }
                    .accessibilityLabel("Undo the last move")
                Button("Redo") { send("play.redo") }
                    .accessibilityLabel("Redo the move")
                Button("Next level") { send("level.next") }
                    .accessibilityLabel("Go to the next level")
                Button("Reset view") { resetView() }
                    .accessibilityLabel("Return the camera to the authored view")
            }
        }
    }

    /// Sends `control` through the presenter, which shows and logs a refusal.
    private func send(_ control: String, _ values: [Double] = []) {
        sender(control, values)
    }
}
#endif
