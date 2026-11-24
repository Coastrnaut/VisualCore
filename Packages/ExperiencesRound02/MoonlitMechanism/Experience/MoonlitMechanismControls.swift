// MoonlitMechanismControls — feature 433 (R02-G14-03) T-R02G1403-006 (FR-R02G1403-005; clarification Q5). The minimal
// control panel: labelled buttons for the handle (turn − and +), the chosen gear (gear − and +; presentation state
// only, a level opens with gear 1 chosen, clamped to the level's gears), re-seating the chosen gear (re-seat − and +,
// `gear.reseat [gear, ±1]`), the lamp (lamp − and +), the shown key frame (key frame − and +, `frame.show [k]`), run,
// undo, redo and next level (kernel actions through the action port), each with an accessibility label, value and
// identifier; the header shows the actions left of the budget, the status (stage, or the failure in words), the
// progress description, the failure in words and a refused action in words. Since feature 434 (R02-G14-04) the panel
// shows the pending turn or lamp steps of a canvas drag and has "Reset view"; full accessibility comes in a later
// feature of R02-G14.
#if os(iOS)
import MoonlitMechanismCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Moonlit Mechanism.
struct MoonlitMechanismControls: View {
    /// Where actions are sent.
    let port: ExperienceActionPort
    /// What the panel shows and chooses.
    let mirror: MoonlitMechanismMirror
    /// Returns the camera to the authored view (feature 434; presentation only).
    var resetView: () -> Void = {}
    /// Sends a control and shows a refusal in words (the presenter's `send`, feature 434); nil sends through the port
    /// directly.
    var sender: ((String, [Double]) -> Void)? = nil

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                turnRow
                gearRows
                lampRow
                frameRow
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
        if let pending = mirror.pending {
            Text(pending).font(.footnote)
                .accessibilityIdentifier(port.identifier("pending"))
        }
        if let message = mirror.message {
            Text(message).font(.footnote)
                .accessibilityIdentifier(port.identifier("message"))
        }
    }

    /// Turn the handle back or forward one tooth.
    @ViewBuilder private var turnRow: some View {
        HStack(spacing: 16) {
            Button("Turn −") { send("handle.turn", [-1]) }
                .accessibilityLabel("Turn the handle back one tooth")
                .accessibilityValue(mirror.measureLabel)
                .accessibilityIdentifier(port.identifier("turn-minus"))
            Button("Turn +") { send("handle.turn", [1]) }
                .accessibilityLabel("Turn the handle forward one tooth")
                .accessibilityValue(mirror.measureLabel)
                .accessibilityIdentifier(port.identifier("turn-plus"))
        }
    }

    /// Choose a gear and re-seat it.
    @ViewBuilder private var gearRows: some View {
        HStack(spacing: 16) {
            Button("Gear −") { mirror.stepGear(-1) }
                .accessibilityLabel("Choose the previous gear")
                .accessibilityValue(mirror.gearDetail)
                .accessibilityIdentifier(port.identifier("gear-minus"))
            Text(mirror.gearLabel)
                .accessibilityIdentifier(port.identifier("gear"))
            Button("Gear +") { mirror.stepGear(1) }
                .accessibilityLabel("Choose the next gear")
                .accessibilityValue(mirror.gearDetail)
                .accessibilityIdentifier(port.identifier("gear-plus"))
        }
        Text(mirror.gearDetail).font(.footnote)
            .accessibilityIdentifier(port.identifier("gear-detail"))
        HStack(spacing: 16) {
            Button("Re-seat −") { send("gear.reseat", [Double(mirror.gear), -1]) }
                .accessibilityLabel("Re-seat the chosen gear back one tooth")
                .accessibilityValue(mirror.gearDetail)
                .accessibilityIdentifier(port.identifier("reseat-minus"))
            Button("Re-seat +") { send("gear.reseat", [Double(mirror.gear), 1]) }
                .accessibilityLabel("Re-seat the chosen gear forward one tooth")
                .accessibilityValue(mirror.gearDetail)
                .accessibilityIdentifier(port.identifier("reseat-plus"))
        }
    }

    /// Lower or raise the lamp.
    @ViewBuilder private var lampRow: some View {
        HStack(spacing: 16) {
            Button("Lamp −") { send("lamp.step", [-1]) }
                .accessibilityLabel("Lower the lamp one height")
                .accessibilityValue(mirror.lampLabel)
                .accessibilityIdentifier(port.identifier("lamp-minus"))
            Text(mirror.lampLabel)
                .accessibilityIdentifier(port.identifier("lamp"))
            Button("Lamp +") { send("lamp.step", [1]) }
                .accessibilityLabel("Raise the lamp one height")
                .accessibilityValue(mirror.lampLabel)
                .accessibilityIdentifier(port.identifier("lamp-plus"))
        }
    }

    /// Show the previous or next key frame (presentation only).
    @ViewBuilder private var frameRow: some View {
        HStack(spacing: 16) {
            Button("Key frame −") { send("frame.show", [Double(mirror.clampedFrame(mirror.shownFrame - 1))]) }
                .accessibilityLabel("Show the previous key frame")
                .accessibilityValue(mirror.frameLabel)
                .accessibilityIdentifier(port.identifier("frame-minus"))
            Button("Key frame +") { send("frame.show", [Double(mirror.clampedFrame(mirror.shownFrame + 1))]) }
                .accessibilityLabel("Show the next key frame")
                .accessibilityValue(mirror.frameLabel)
                .accessibilityIdentifier(port.identifier("frame-plus"))
        }
        Text(mirror.frameLabel).font(.footnote)
            .accessibilityIdentifier(port.identifier("frame"))
    }

    /// Run, undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        HStack(spacing: 16) {
            Button("Run") { send("machine.run") }
                .accessibilityLabel("Run the machine through its key frames")
                .accessibilityValue(mirror.measureLabel)
                .accessibilityIdentifier(port.identifier("run"))
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last action")
                .accessibilityIdentifier(port.identifier("undo"))
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the action")
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

    /// Sends `control` and shows a refusal in words.
    private func send(_ control: String, _ values: [Double] = []) {
        if let sender {
            sender(control, values)
            return
        }
        let result = port.send(control, values)
        mirror.message = result.isAccepted
            ? nil : "That change was refused: \(MoonlitMechanismMirror.refusalText(code: result.code))."
    }
}
#endif
