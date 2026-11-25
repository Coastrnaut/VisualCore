// StarlitCartoucheControls — feature 453 (R02-G16-03) T-R02G1603-006 (FR-R02G1603-005; clarification Q5). The minimal
// control panel: labelled buttons for the chosen destination (destination − and +, skipping the ship's star) and wait
// (wait − and +, 0 … 8), both `route.choose [star, wait]` (presentation state of the adapter; a level opens, and every
// leg ends, with the other end of the lowest-index corridor from the ship's star and wait 0), flying the chosen leg
// (`route.fly [star, wait]`), undo, redo and next level (kernel actions through the action port), each with an
// accessibility label, value and identifier; the header shows the actions left of the budget, the status (stage, or the
// failure in words), the progress description, the failure in words and a refused action in words. Tapping stars on
// the canvas, the time slider and the route preview arrive in feature 454 (R02-G16-04), which adds the pending leg of
// a ship drag and "Reset view" to the panel; full accessibility comes in a later feature of R02-G16.
#if os(iOS)
import StarlitCartoucheCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Starlit Cartouche.
struct StarlitCartoucheControls: View {
    /// Where actions are sent.
    let port: ExperienceActionPort
    /// What the panel shows.
    let mirror: StarlitCartoucheMirror
    /// Returns the camera to the authored view (feature 454; presentation only).
    var resetView: () -> Void = {}
    /// Sends a control and shows a refusal in words (the presenter's `send`, feature 454); nil sends through the port
    /// directly.
    var sender: ((String, [Double]) -> Void)? = nil

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                destinationRow
                waitRow
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
        if let pending = mirror.pending {
            Text(pending).font(.footnote)
                .accessibilityIdentifier(port.identifier("pending"))
        }
    }

    /// Choose the previous or next destination star.
    @ViewBuilder private var destinationRow: some View {
        HStack(spacing: 16) {
            Button("Star −") { send("route.choose", [Double(mirror.nextDestination(-1)), Double(mirror.wait)]) }
                .accessibilityLabel("Choose the previous destination star")
                .accessibilityValue(mirror.legLabel)
                .accessibilityIdentifier(port.identifier("star-minus"))
            Text("star \(mirror.destination)")
                .accessibilityIdentifier(port.identifier("star"))
            Button("Star +") { send("route.choose", [Double(mirror.nextDestination(1)), Double(mirror.wait)]) }
                .accessibilityLabel("Choose the next destination star")
                .accessibilityValue(mirror.legLabel)
                .accessibilityIdentifier(port.identifier("star-plus"))
        }
        Text(mirror.legLabel).font(.footnote)
            .accessibilityIdentifier(port.identifier("leg-detail"))
    }

    /// Choose a shorter or longer wait before launching.
    @ViewBuilder private var waitRow: some View {
        HStack(spacing: 16) {
            Button("Wait −") { choose(wait: mirror.wait - 1) }
                .accessibilityLabel("Wait one beat less before launching")
                .accessibilityValue(mirror.legLabel)
                .accessibilityIdentifier(port.identifier("wait-minus"))
            Text("wait \(mirror.wait)")
                .accessibilityIdentifier(port.identifier("wait"))
            Button("Wait +") { choose(wait: mirror.wait + 1) }
                .accessibilityLabel("Wait one beat more before launching")
                .accessibilityValue(mirror.legLabel)
                .accessibilityIdentifier(port.identifier("wait-plus"))
            Button("Fly") { send("route.fly", [Double(mirror.destination), Double(mirror.wait)]) }
                .accessibilityLabel("Fly the chosen leg")
                .accessibilityValue(mirror.legLabel)
                .accessibilityIdentifier(port.identifier("fly"))
        }
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        HStack(spacing: 16) {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last leg")
                .accessibilityIdentifier(port.identifier("undo"))
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the leg")
                .accessibilityIdentifier(port.identifier("redo"))
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
                .accessibilityIdentifier(port.identifier("next-level"))
        }
        Button("Reset view") { resetView() }
            .accessibilityLabel("Return the camera to the authored view")
            .accessibilityValue("presentation only")
            .accessibilityIdentifier(port.identifier("reset-view"))
    }

    /// Chooses wait `wait` (clamped to 0 … 8) with the current destination.
    private func choose(wait: Int) {
        send("route.choose", [Double(mirror.destination), Double(mirror.clampedWait(wait))])
    }

    /// Sends `control` and shows a refusal in words.
    private func send(_ control: String, _ values: [Double] = []) {
        if let sender {
            sender(control, values)
            return
        }
        let result = port.send(control, values)
        mirror.message = result.isAccepted
            ? nil : "That change was refused: \(StarlitCartoucheMirror.refusalText(code: result.code))."
    }
}
#endif
