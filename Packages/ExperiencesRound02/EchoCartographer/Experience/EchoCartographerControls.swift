// EchoCartographerControls — feature 403 (R02-G11-03) T-R02G1103-006 (FR-R02G1103-005; clarification Q5). The minimal
// control panel: labelled steppers for the cursor's column and row (presentation state only), pulse, claim and mark at
// the cursor (kernel actions through the action port), undo, redo and next level, each with an accessibility label and
// value. Feature 404 (R02-G11-04) adds "Reset view" (the authored camera) and sends through the presenter, which shows
// and logs refusals; full accessibility comes in R02-G11-06. Feature 405 (R02-G11-05) T-R02G1105-005: the tutorial
// instruction with Dismiss, Hint (each press reveals the next level), the failure explanation with Undo and Retry, the
// goal with the level's band and best stars, Campaign / Daily / Practice and a picker of the open levels; all as
// wrapping text in the panel, never over the chamber.
#if os(iOS)
import EchoCartographerCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Echo Cartographer.
struct EchoCartographerControls: View {
    let mirror: EchoCartographerMirror
    /// The presenter (feature 405): hints, retry, undo and the daily level.
    let presenter: EchoCartographerPresenter
    /// The action port the presenter sends through (feature 405).
    let port: ExperienceActionPort
    /// Returns the camera to the authored view.
    let resetView: () -> Void
    /// Sends a control with its values through the presenter (which shows and logs a refusal).
    let sender: (String, [Double]) -> Void

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teaching
                cursorRow
                cellRow
                playRow
                progressRows
            }
            .padding()
        }
    }

    /// The level, energy and stage lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · energy \(mirror.energy) of \(mirror.budget)")
            .font(.headline)
        Text(mirror.status).font(.subheadline)
        Text(mirror.measureLabel).font(.footnote)
        Text(mirror.targetLabel).font(.footnote)
        if let message = mirror.message {
            Text(message).font(.footnote)
        }
    }

    /// The column and row steppers.
    @ViewBuilder private var cursorRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Stepper(mirror.columnLabel,
                    onIncrement: { mirror.stepColumn(1) },
                    onDecrement: { mirror.stepColumn(-1) })
                .accessibilityLabel("Column of the chosen cell")
                .accessibilityValue(mirror.columnLabel)
            Stepper(mirror.rowLabel,
                    onIncrement: { mirror.stepRow(1) },
                    onDecrement: { mirror.stepRow(-1) })
                .accessibilityLabel("Row of the chosen cell")
                .accessibilityValue(mirror.rowLabel)
        }
    }

    /// Pulse, claim and mark at the cursor.
    @ViewBuilder private var cellRow: some View {
        HStack(spacing: 16) {
            Button("Pulse") { send("cell.pulse", cursorValues) }
                .accessibilityLabel("Send a pulse from the chosen cell")
                .accessibilityValue(mirror.cursorLabel)
            Button("Claim") { send("cell.claim", cursorValues) }
                .accessibilityLabel("Claim a beacon at the chosen cell")
                .accessibilityValue(mirror.cursorLabel)
            Button("Mark") { send("cell.mark", cursorValues) }
                .accessibilityLabel("Toggle a marker on the chosen cell")
                .accessibilityValue(mirror.cursorLabel)
        }
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        HStack(spacing: 16) {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last action")
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the action")
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
            Button("Reset view") { resetView() }
                .accessibilityLabel("Return the camera to the authored view")
        }
    }

    /// The tutorial instruction, the hint, the goal and the failure explanation (feature 405).
    @ViewBuilder private var teaching: some View {
        if let instruction = mirror.instruction {
            VStack(alignment: .leading, spacing: 4) {
                Text(instruction).font(.callout).fixedSize(horizontal: false, vertical: true)
                Button("Dismiss") { presenter.dismissTutorial(port: port) }
                    .accessibilityLabel("Dismiss the tutorial")
            }
        }
        HStack(spacing: 12) {
            Button("Hint") { presenter.showHint() }
                .accessibilityLabel("Show a hint")
                .accessibilityValue(mirror.hintLevel == 0 ? "none shown" : "level \(mirror.hintLevel) of 3")
            Text(mirror.goalLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
        }
        if let hint = mirror.hintText {
            Text(hint).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
        if let failure = mirror.failureText {
            VStack(alignment: .leading, spacing: 4) {
                Text(failure).font(.callout).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Button("Undo") { presenter.undoAction(port: port) }
                        .accessibilityLabel("Undo the last action")
                    Button("Retry") { presenter.retry(port: port) }
                        .accessibilityLabel("Start the level again")
                }
            }
        }
    }

    /// The mode buttons and the picker of open levels with their bands and stars (feature 405).
    @ViewBuilder private var progressRows: some View {
        HStack(spacing: 12) {
            Button("Campaign") { send("mode.campaign") }
                .accessibilityLabel("Play the campaign")
                .accessibilityValue(Self.modeName(mirror.mode) == "campaign" ? "selected" : "")
            Button("Daily") { presenter.playDaily(port: port) }
                .accessibilityLabel("Play today's daily level")
                .accessibilityValue(Self.modeName(mirror.mode) == "daily" ? "selected" : "")
            Button("Practice") { send("mode.practice") }
                .accessibilityLabel("Practise this level with more energy")
                .accessibilityValue(Self.modeName(mirror.mode) == "practice" ? "selected" : "")
        }
        HStack(spacing: 12) {
            Stepper(levelLabel(mirror.pickedLevel),
                    onIncrement: { mirror.pickedLevel = min(mirror.pickedLevel + 1, mirror.frontier) },
                    onDecrement: { mirror.pickedLevel = max(mirror.pickedLevel - 1, 1) })
                .accessibilityLabel("Level to play")
                .accessibilityValue(levelLabel(mirror.pickedLevel))
            Button("Play level") { send("level.select", [Double(mirror.pickedLevel)]) }
                .accessibilityLabel("Play the picked level")
        }
    }

    /// "Level n, band b" with its stars when won.
    private func levelLabel(_ level: Int) -> String {
        let band: Int = EchoCartographerProgress.band(of: level)
        if let stars = mirror.stars[level] { return "Level \(level), band \(band), \(stars) stars" }
        return "Level \(level), band \(band)"
    }

    /// The mode's name: campaign, daily or practice.
    static func modeName(_ mode: EchoCartographerMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        }
    }

    /// The cursor as the values of a `cell.*` control.
    private var cursorValues: [Double] { [Double(mirror.column), Double(mirror.row)] }

    /// Sends `control` through the presenter.
    private func send(_ control: String, _ values: [Double] = []) {
        sender(control, values)
    }
}
#endif
