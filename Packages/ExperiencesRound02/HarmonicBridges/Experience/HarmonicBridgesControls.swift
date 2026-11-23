// HarmonicBridgesControls — feature 413 (R02-G12-03) T-R02G1203-006 (FR-R02G1203-005; clarification Q5). The minimal
// control panel: labelled steppers for the chosen string and peg (presentation state only; a level opens with string 0
// chosen at its current peg, both clamped), tune (the chosen string to the chosen peg) and test (kernel actions
// through the action port), undo, redo and next level, each with an accessibility label, value and identifier; the
// header shows the actions left of the budget, the stage, the failure in words and a refused action in words. Feature
// 414 (R02-G12-04) adds "Reset view" (the authored camera) and sends through the presenter, which shows and logs
// refusals; full accessibility comes in R02-G12-06.
#if os(iOS)
import HarmonicBridgesCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Harmonic Bridges.
struct HarmonicBridgesControls: View {
    /// The action port (its identifiers name the controls).
    let port: ExperienceActionPort
    /// What the panel shows and chooses.
    let mirror: HarmonicBridgesMirror
    /// Returns the camera to the authored view.
    let resetView: () -> Void
    /// Sends a control with its values through the presenter (which shows and logs a refusal).
    let sender: (String, [Double]) -> Void

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                choiceRow
                actionRow
                playRow
            }
            .padding()
        }
    }

    /// The level, actions, stage, failure and refusal lines.
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
        Text(mirror.targetLabel).font(.footnote)
        if let message = mirror.message {
            Text(message).font(.footnote)
                .accessibilityIdentifier(port.identifier("message"))
        }
    }

    /// The string and peg steppers.
    @ViewBuilder private var choiceRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Stepper(mirror.stringLabel,
                    onIncrement: { mirror.stepString(1) },
                    onDecrement: { mirror.stepString(-1) })
                .accessibilityLabel("Chosen string")
                .accessibilityValue(mirror.choiceLabel)
                .accessibilityIdentifier(port.identifier("string"))
            Stepper(mirror.pegLabel,
                    onIncrement: { mirror.stepPeg(1) },
                    onDecrement: { mirror.stepPeg(-1) })
                .accessibilityLabel("Peg to tune the chosen string to")
                .accessibilityValue(mirror.pegLabel)
                .accessibilityIdentifier(port.identifier("peg"))
        }
    }

    /// Tune the chosen string and test the crossing.
    @ViewBuilder private var actionRow: some View {
        HStack(spacing: 16) {
            Button("Tune") { send("string.tune", choiceValues) }
                .accessibilityLabel("Tune the chosen string to the chosen peg")
                .accessibilityValue(mirror.choiceLabel)
                .accessibilityIdentifier(port.identifier("tune"))
            Button("Test") { send("crossing.test") }
                .accessibilityLabel("Test the crossing in every step")
                .accessibilityValue(mirror.measureLabel)
                .accessibilityIdentifier(port.identifier("test"))
        }
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        HStack(spacing: 16) {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last action")
                .accessibilityIdentifier(port.identifier("undo"))
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the action")
                .accessibilityIdentifier(port.identifier("redo"))
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
                .accessibilityIdentifier(port.identifier("next-level"))
            Button("Reset view") { resetView() }
                .accessibilityLabel("Return the camera to the authored view")
                .accessibilityIdentifier(port.identifier("reset-view"))
        }
    }

    /// The choice as the values of `string.tune`.
    private var choiceValues: [Double] { [Double(mirror.string), Double(mirror.peg)] }

    /// Sends `control` through the presenter.
    private func send(_ control: String, _ values: [Double] = []) {
        sender(control, values)
    }
}
#endif
