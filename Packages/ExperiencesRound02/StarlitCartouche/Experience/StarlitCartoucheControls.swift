// StarlitCartoucheControls — feature 453 (R02-G16-03) T-R02G1603-006 (FR-R02G1603-005; clarification Q5). The minimal
// control panel: labelled buttons for the chosen destination (destination − and +, skipping the ship's star) and wait
// (wait − and +, 0 … 8), both `route.choose [star, wait]` (presentation state of the adapter; a level opens, and every
// leg ends, with the other end of the lowest-index corridor from the ship's star and wait 0), flying the chosen leg
// (`route.fly [star, wait]`), undo, redo and next level (kernel actions through the action port), each with an
// accessibility label, value and identifier; the header shows the actions left of the budget, the status (stage, or the
// failure in words), the progress description, the failure in words and a refused action in words. Tapping stars on
// the canvas, the time slider and the route preview arrive in feature 454 (R02-G16-04), which adds the pending leg of
// a ship drag and "Reset view" to the panel. Feature 455 (R02-G16-05) T-R02G1605-005: the tutorial instruction with
// Dismiss, Hint (each press reveals the next level), the failure explanation with Undo and Retry, the goal with the
// level's band and best stars, Campaign / Daily / Practice and a picker of the open levels with Play level; all as
// wrapping text in the panel, never over the chart. "Next level" stays; before a win it is refused in words. Full
// accessibility comes in a later feature of R02-G16.
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
    /// The presenter (feature 455): hints, tutorial, retry, undo and the daily level.
    let presenter: StarlitCartouchePresenter
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
                teaching
                destinationRow
                waitRow
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

    /// The tutorial instruction, the hint, the goal and the failure's explanation with Undo and Retry (feature 455).
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
                    .accessibilityLabel("Undo the last leg")
                    .accessibilityIdentifier(port.identifier("failure-undo"))
                Button("Retry") { presenter.retry(port: port) }
                    .accessibilityLabel("Start the level again")
                    .accessibilityIdentifier(port.identifier("retry"))
            }
        }
    }

    /// The mode buttons and the picker of open levels with their bands and stars (feature 455).
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
        let band: Int = StarlitCartoucheProgress.band(of: level)
        if let stars = mirror.stars[level] { return "Level \(level), band \(band), \(stars) stars" }
        return "Level \(level), band \(band)"
    }

    /// The mode's name: campaign, daily or practice.
    static func modeName(_ mode: StarlitCartoucheMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
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
