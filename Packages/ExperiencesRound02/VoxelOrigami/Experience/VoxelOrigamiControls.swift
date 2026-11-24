// VoxelOrigamiControls — feature 443 (R02-G15-03) T-R02G1503-006 (FR-R02G1503-005; clarification Q5). The minimal
// control panel: labelled buttons for the chosen hinge (hinge − and +, `hinge.choose [h]`; presentation state of the
// adapter, a level opens with its first turnable hinge chosen, clamped to the level's hinges), turning it (turn − and
// +, `hinge.turn [h, ±1]`), undo, redo and next level (kernel actions through the action port), each with an
// accessibility label, value and identifier; the header shows the actions left of the budget, the status (stage, or the
// failure in words), the progress description, the failure in words and a refused action in words. Touching cubes on
// the canvas, orbiting and full accessibility come in later features of R02-G15.
#if os(iOS)
import SwiftUI
import VisualCoreExperienceHost
import VoxelOrigamiCore

/// The control panel of Voxel Origami.
struct VoxelOrigamiControls: View {
    /// Where actions are sent.
    let port: ExperienceActionPort
    /// What the panel shows.
    let mirror: VoxelOrigamiMirror

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                hingeRow
                turnRow
                playRow
            }
            .padding()
        }
    }

    /// The level, actions, status, failure and refusal lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · \(mirror.actionsLeft) of \(mirror.budget) actions left")
            .font(.headline)
            .accessibilityIdentifier(port.identifier("actions"))
        Text(mirror.status).font(.subheadline)
            .accessibilityIdentifier(port.identifier("status"))
        if let failure = mirror.failureText {
            Text(failure).font(.footnote)
                .accessibilityIdentifier(port.identifier("failure"))
        }
        Text(mirror.measureLabel).font(.footnote)
            .accessibilityIdentifier(port.identifier("progress"))
        Text(mirror.targetLabel).font(.footnote)
        if let message = mirror.message {
            Text(message).font(.footnote)
                .accessibilityIdentifier(port.identifier("message"))
        }
    }

    /// Choose the previous or next hinge.
    @ViewBuilder private var hingeRow: some View {
        HStack(spacing: 16) {
            Button("Hinge −") { send("hinge.choose", [Double(mirror.clampedHinge(mirror.hinge - 1))]) }
                .accessibilityLabel("Choose the previous hinge")
                .accessibilityValue(mirror.hingeDetail)
                .accessibilityIdentifier(port.identifier("hinge-minus"))
            Text(mirror.hingeLabel)
                .accessibilityIdentifier(port.identifier("hinge"))
            Button("Hinge +") { send("hinge.choose", [Double(mirror.clampedHinge(mirror.hinge + 1))]) }
                .accessibilityLabel("Choose the next hinge")
                .accessibilityValue(mirror.hingeDetail)
                .accessibilityIdentifier(port.identifier("hinge-plus"))
        }
        Text(mirror.hingeDetail).font(.footnote)
            .accessibilityIdentifier(port.identifier("hinge-detail"))
    }

    /// Turn the chosen hinge a quarter turn back or forward.
    @ViewBuilder private var turnRow: some View {
        HStack(spacing: 16) {
            Button("Turn −") { send("hinge.turn", [Double(mirror.hinge), -1]) }
                .accessibilityLabel("Turn the chosen hinge a quarter turn back")
                .accessibilityValue(mirror.hingeDetail)
                .accessibilityIdentifier(port.identifier("turn-minus"))
            Button("Turn +") { send("hinge.turn", [Double(mirror.hinge), 1]) }
                .accessibilityLabel("Turn the chosen hinge a quarter turn forward")
                .accessibilityValue(mirror.hingeDetail)
                .accessibilityIdentifier(port.identifier("turn-plus"))
        }
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        HStack(spacing: 16) {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last turn")
                .accessibilityIdentifier(port.identifier("undo"))
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the turn")
                .accessibilityIdentifier(port.identifier("redo"))
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
                .accessibilityIdentifier(port.identifier("next-level"))
        }
    }

    /// Sends `control` and shows a refusal in words.
    private func send(_ control: String, _ values: [Double] = []) {
        let result = port.send(control, values)
        mirror.message = result.isAccepted
            ? nil : "That change was refused: \(VoxelOrigamiMirror.refusalText(code: result.code))."
    }
}
#endif
