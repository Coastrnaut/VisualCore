// VoxelOrigamiControls — feature 443 (R02-G15-03) T-R02G1503-006 (FR-R02G1503-005; clarification Q5). The minimal
// control panel: labelled buttons for the chosen hinge (hinge − and +, `hinge.choose [h]`; presentation state of the
// adapter, a level opens with its first turnable hinge chosen, clamped to the level's hinges), turning it (turn − and
// +, `hinge.turn [h, ±1]`), undo, redo and next level (kernel actions through the action port), each with an
// accessibility label, value and identifier; the header shows the actions left of the budget, the status (stage, or the
// failure in words), the progress description, the failure in words and a refused action in words. Since feature 444
// (R02-G15-04) the panel shows the pending turn of a canvas drag and has "Reset view". Feature 445 (R02-G15-05)
// T-R02G1505-005: the tutorial instruction with Dismiss, Hint (each press reveals the next level), the failure
// explanation with Undo and Retry, the goal with the level's band and best stars, Campaign / Daily / Practice and a
// picker of the open levels with Play level; all as wrapping text in the panel, never over the solid. "Next level"
// stays; before a win it is refused in words. Full accessibility comes in a later feature of R02-G15.
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
    /// The presenter (feature 445): hints, tutorial, retry, undo and the daily level.
    let presenter: VoxelOrigamiPresenter
    /// Returns the camera to the authored view (feature 444; presentation only).
    var resetView: () -> Void = {}
    /// Sends a control and shows a refusal in words (the presenter's `send`, feature 444); nil sends through the port
    /// directly.
    var sender: ((String, [Double]) -> Void)? = nil

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teaching
                hingeRow
                turnRow
                playRow
                progressRows
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
        Button("Reset view") { resetView() }
            .accessibilityLabel("Return the camera to the authored view")
            .accessibilityValue("presentation only")
            .accessibilityIdentifier(port.identifier("reset-view"))
    }

    /// The tutorial instruction, the hint, the goal and the failure's explanation with Undo and Retry (feature 445).
    @ViewBuilder private var teaching: some View {
        if let instruction = mirror.instruction {
            VStack(alignment: .leading, spacing: 4) {
                Text(instruction).font(.callout).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(port.identifier("instruction"))
                Button("Dismiss") { presenter.dismissTutorial(port: port) }
                    .accessibilityLabel("Dismiss the tutorial")
                    .accessibilityIdentifier(port.identifier("dismiss-tutorial"))
            }
        }
        HStack(spacing: 12) {
            Button("Hint") { presenter.showHint() }
                .accessibilityLabel("Show a hint")
                .accessibilityValue(mirror.hintLevel == 0 ? "none shown" : "level \(mirror.hintLevel) of 3")
                .accessibilityIdentifier(port.identifier("hint"))
            Text(mirror.goalLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("goal"))
        }
        if let hint = mirror.hintText {
            Text(hint).font(.callout).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("hint-text"))
        }
        if let explanation = mirror.explanation {
            Text(explanation).font(.callout).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("explanation"))
            HStack(spacing: 12) {
                Button("Undo") { presenter.undoAction(port: port) }
                    .accessibilityLabel("Undo the last turn")
                    .accessibilityIdentifier(port.identifier("failure-undo"))
                Button("Retry") { presenter.retry(port: port) }
                    .accessibilityLabel("Start the level again")
                    .accessibilityIdentifier(port.identifier("retry"))
            }
        }
    }

    /// The mode buttons and the picker of open levels with their bands and stars (feature 445).
    @ViewBuilder private var progressRows: some View {
        HStack(spacing: 12) {
            Button("Campaign") { send("mode.campaign") }
                .accessibilityLabel("Play the campaign")
                .accessibilityValue(Self.modeName(mirror.mode) == "campaign" ? "selected" : "not selected")
                .accessibilityIdentifier(port.identifier("campaign"))
            Button("Daily") { presenter.playDaily(port: port) }
                .accessibilityLabel("Play today's daily level")
                .accessibilityValue(Self.modeName(mirror.mode) == "daily" ? "selected" : "not selected")
                .accessibilityIdentifier(port.identifier("daily"))
            Button("Practice") { send("mode.practice") }
                .accessibilityLabel("Practise this level with more actions")
                .accessibilityValue(Self.modeName(mirror.mode) == "practice" ? "selected" : "not selected")
                .accessibilityIdentifier(port.identifier("practice"))
        }
        HStack(spacing: 12) {
            Stepper(levelLabel(mirror.pickedLevel),
                    onIncrement: { mirror.pickedLevel = min(mirror.pickedLevel + 1, mirror.frontier) },
                    onDecrement: { mirror.pickedLevel = max(mirror.pickedLevel - 1, 1) })
                .accessibilityLabel("Level to play")
                .accessibilityValue(levelLabel(mirror.pickedLevel))
                .accessibilityIdentifier(port.identifier("level-picker"))
            Button("Play level") { send("level.select", [Double(mirror.pickedLevel)]) }
                .accessibilityLabel("Play the picked level")
                .accessibilityIdentifier(port.identifier("play-level"))
        }
    }

    /// "Level n, band b" with its stars when won.
    private func levelLabel(_ level: Int) -> String {
        let band: Int = VoxelOrigamiProgress.band(of: level)
        if let stars = mirror.stars[level] { return "Level \(level), band \(band), \(stars) stars" }
        return "Level \(level), band \(band)"
    }

    /// The mode's name: campaign, daily or practice.
    static func modeName(_ mode: VoxelOrigamiMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        }
    }

    /// Sends `control` and shows a refusal in words.
    private func send(_ control: String, _ values: [Double] = []) {
        if let sender {
            sender(control, values)
            return
        }
        let result = port.send(control, values)
        mirror.message = result.isAccepted
            ? nil : "That change was refused: \(VoxelOrigamiMirror.refusalText(code: result.code))."
    }
}
#endif
