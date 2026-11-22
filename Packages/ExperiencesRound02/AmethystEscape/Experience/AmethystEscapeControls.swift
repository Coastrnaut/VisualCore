// AmethystEscapeControls — feature 363 (R02-G07-03) T-R02G0703-006 (FR-R02G0703-005; clarification Q5). The minimal
// control panel: a labelled shell picker (previous and next shell, named in words), turn the picked shell − and +,
// advance the pearl, undo, redo and next level, each with an accessibility label and value; every change is a kernel
// action sent through the action port. Bezel dragging, tap to advance and layer isolation come in R02-G07-04; full
// accessibility in R02-G07-06. Feature 364 (R02-G07-04) T-R02G0704-006 (FR-R02G0704-007): the panel gains "Show all
// layers" (clears the isolation) and "Reset view" (returns the camera to the authored view); refusals are shown and
// logged by the presenter.
#if os(iOS)
import AmethystEscapeCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Amethyst Escape.
struct AmethystEscapeControls: View {
    let port: ExperienceActionPort
    let mirror: AmethystEscapeMirror
    /// The presenter, for "Show all layers", "Reset view" (feature 364) and refusals shown like the gestures' ones.
    let presenter: AmethystEscapePresenter

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                shellRow
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
        if let message = mirror.message {
            Text(message).font(.footnote)
        }
    }

    /// The shell picker and the turn − and + buttons.
    @ViewBuilder private var shellRow: some View {
        HStack(spacing: 12) {
            Stepper(mirror.pickedShellLabel,
                    onIncrement: { mirror.pickNext(1) },
                    onDecrement: { mirror.pickNext(-1) })
                .accessibilityLabel("Shell to turn")
                .accessibilityValue(mirror.pickedShellLabel)
            Button("Turn −") { send("shell.rotate", [Double(mirror.pickedShell), -1]) }
                .accessibilityLabel("Turn the picked shell one sector anticlockwise")
                .accessibilityValue(mirror.pickedOffsetLabel)
            Button("Turn +") { send("shell.rotate", [Double(mirror.pickedShell), 1]) }
                .accessibilityLabel("Turn the picked shell one sector clockwise")
                .accessibilityValue(mirror.pickedOffsetLabel)
        }
    }

    /// Advance, undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        HStack(spacing: 16) {
            Button("Advance") { send("pearl.advance") }
                .accessibilityLabel("Roll the pearl one pocket")
                .accessibilityValue(mirror.pearlLabel)
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last action")
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the action")
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
            Button("Show all layers") { presenter.showAllLayers() }
                .accessibilityLabel("Show every shell of the crystal")
                .accessibilityValue("layers")
            Button("Reset view") { presenter.resetView() }
                .accessibilityLabel("Return the camera to the starting view")
                .accessibilityValue("camera")
        }
    }

    /// Sends `control` through the presenter, which shows and logs a refusal.
    private func send(_ control: String, _ values: [Double] = []) {
        presenter.send(control, values, port: port)
    }
}
#endif
