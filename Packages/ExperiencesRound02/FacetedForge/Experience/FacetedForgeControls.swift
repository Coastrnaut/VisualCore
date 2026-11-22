// FacetedForgeControls — feature 373 (R02-G08-03) T-R02G0803-006 (FR-R02G0803-005; clarification Q5). The minimal
// control panel: a labelled piece picker, a direction picker, depth − and + (the preview choice, presentation state
// only), cut (a kernel action through the action port), undo, redo and next level, each with an accessibility label and
// value. Dragging the cut plane's rim, the depth slider, tap to commit and orbit come in R02-G08-04; full accessibility
// in R02-G08-06. Feature 374 (R02-G08-04): "Reset view" returns the camera to the authored view; every action goes
// through the presenter, which shows and logs a refusal like a gesture's.
#if os(iOS)
import FacetedForgeCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Faceted Forge.
struct FacetedForgeControls: View {
    let port: ExperienceActionPort
    let mirror: FacetedForgeMirror
    /// The presenter, for "Reset view" (feature 374) and refusals shown and logged like the gestures' ones.
    let presenter: FacetedForgePresenter

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                choiceRow
                playRow
            }
            .padding()
        }
    }

    /// The level, cuts and stage lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · cuts \(mirror.cuts) of \(mirror.budget)")
            .font(.headline)
        Text(mirror.status).font(.subheadline)
        Text(mirror.targetLabel).font(.footnote)
        if let message = mirror.message {
            Text(message).font(.footnote)
        }
    }

    /// The piece and direction pickers and the depth − and + buttons.
    @ViewBuilder private var choiceRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Stepper(mirror.pieceLabel,
                    onIncrement: { mirror.pickPiece(1) },
                    onDecrement: { mirror.pickPiece(-1) })
                .accessibilityLabel("Piece to cut")
                .accessibilityValue(mirror.pieceLabel)
            Stepper(mirror.directionLabel,
                    onIncrement: { mirror.pickDirection(1) },
                    onDecrement: { mirror.pickDirection(-1) })
                .accessibilityLabel("Direction of the cut")
                .accessibilityValue(mirror.directionLabel)
            HStack(spacing: 12) {
                Button("Depth −") { mirror.stepDepth(-1) }
                    .accessibilityLabel("Move the cut plane one step back")
                    .accessibilityValue(mirror.depthLabel)
                Text(mirror.depthLabel).font(.footnote)
                Button("Depth +") { mirror.stepDepth(1) }
                    .accessibilityLabel("Move the cut plane one step forward")
                    .accessibilityValue(mirror.depthLabel)
            }
        }
    }

    /// Cut, undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        HStack(spacing: 16) {
            Button("Cut") {
                let choice = mirror.choice
                send("piece.cut", [Double(choice.piece), Double(choice.direction), Double(choice.depth)])
            }
            .accessibilityLabel("Cut the chosen piece with the shown plane")
            .accessibilityValue(mirror.pieceLabel + ", " + mirror.directionLabel + ", " + mirror.depthLabel)
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last cut")
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the cut")
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
            Button("Reset view") { presenter.resetView() }
                .accessibilityLabel("Return the camera to the authored view")
        }
    }

    /// Sends `control` and shows a refusal.
    private func send(_ control: String, _ values: [Double] = []) {
        presenter.send(control, values, port: port)
    }
}
#endif
