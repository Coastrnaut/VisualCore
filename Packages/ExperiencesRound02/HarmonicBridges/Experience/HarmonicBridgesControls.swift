// HarmonicBridgesControls — feature 413 (R02-G12-03) T-R02G1203-006 (FR-R02G1203-005; clarification Q5). The minimal
// control panel: labelled steppers for the chosen string and peg (presentation state only; a level opens with string 0
// chosen at its current peg, both clamped), tune (the chosen string to the chosen peg) and test (kernel actions
// through the action port), undo, redo and next level, each with an accessibility label, value and identifier; the
// header shows the actions left of the budget, the stage, the failure in words and a refused action in words. Feature
// 414 (R02-G12-04) adds "Reset view" (the authored camera) and sends through the presenter, which shows and logs
// refusals; full accessibility comes in R02-G12-06. Feature 415 (R02-G12-05) T-R02G1205-005: the tutorial
// instruction with Dismiss, Hint (each press reveals the next level), the failure explanation with Undo and Retry, the
// goal with the level's band and best stars, Campaign / Daily / Practice and a picker of the open levels with Play
// level; all as wrapping text in the panel, never over the bridges. "Next level" stays; before a win it is refused in words.
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
    /// The presenter (feature 415): hints, tutorial, retry, undo and the daily level.
    let presenter: HarmonicBridgesPresenter
    /// Returns the camera to the authored view.
    let resetView: () -> Void
    /// Sends a control with its values through the presenter (which shows and logs a refusal).
    let sender: (String, [Double]) -> Void

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teaching
                choiceRow
                actionRow
                playRow
                progressRows
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

    /// The tutorial instruction, the hint, the goal and the failure's Undo and Retry (feature 415); the failure
    /// explanation itself is the header's failure line.
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
        if mirror.failureText != nil {
            HStack(spacing: 12) {
                Button("Undo") { presenter.undoAction(port: port) }
                    .accessibilityLabel("Undo the last action")
                    .accessibilityIdentifier(port.identifier("failure-undo"))
                Button("Retry") { presenter.retry(port: port) }
                    .accessibilityLabel("Start the level again")
                    .accessibilityIdentifier(port.identifier("retry"))
            }
        }
    }

    /// The mode buttons and the picker of open levels with their bands and stars (feature 415).
    @ViewBuilder private var progressRows: some View {
        HStack(spacing: 12) {
            Button("Campaign") { send("mode.campaign") }
                .accessibilityLabel("Play the campaign")
                .accessibilityValue(Self.modeName(mirror.mode) == "campaign" ? "selected" : "")
                .accessibilityIdentifier(port.identifier("campaign"))
            Button("Daily") { presenter.playDaily(port: port) }
                .accessibilityLabel("Play today's daily level")
                .accessibilityValue(Self.modeName(mirror.mode) == "daily" ? "selected" : "")
                .accessibilityIdentifier(port.identifier("daily"))
            Button("Practice") { send("mode.practice") }
                .accessibilityLabel("Practise this level with more actions")
                .accessibilityValue(Self.modeName(mirror.mode) == "practice" ? "selected" : "")
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
        let band: Int = HarmonicBridgesProgress.band(of: level)
        if let stars = mirror.stars[level] { return "Level \(level), band \(band), \(stars) stars" }
        return "Level \(level), band \(band)"
    }

    /// The mode's name: campaign, daily or practice.
    static func modeName(_ mode: HarmonicBridgesMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
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
