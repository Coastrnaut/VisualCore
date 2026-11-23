// BackwardsAuroraControls — feature 393 (R02-G10-03) T-R02G1003-006 (FR-R02G1003-005; clarification Q5). The minimal
// control panel: labelled steppers for the section's start and end (presentation state only), reverse (the kernel
// action through the action port), undo, redo and next level, each with an accessibility label and value. Tapping
// segment ends, swiping to reverse and the timeline freeze preview come in R02-G10-04 (feature 394 adds "Reset view"
// and the preview line); full accessibility in R02-G10-06. Feature 395 (R02-G10-05) T-R02G1005-005: the tutorial
// instruction with Dismiss, Hint (each press reveals the next level), the failure explanation with Undo and Retry, the
// goal with the level's band and best stars, Campaign / Daily / Practice and a picker of the open levels; all as
// wrapping text in the panel, never over the aurora.
#if os(iOS)
import BackwardsAuroraCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Backwards Aurora.
struct BackwardsAuroraControls: View {
    let port: ExperienceActionPort
    let mirror: BackwardsAuroraMirror
    /// The presenter (feature 395): hints, retry, undo and the daily level.
    let presenter: BackwardsAuroraPresenter
    /// Returns the camera to the authored view (feature 394).
    let resetView: () -> Void
    /// Sends a control the way the presenter does (refusals shown and logged).
    let sender: (String, [Double]) -> Void

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teaching
                sectionRow
                playRow
                progressRows
            }
            .padding()
        }
    }

    /// The level, reversals and stage lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · reversals \(mirror.spent) of \(mirror.budget)")
            .font(.headline)
        Text(mirror.status).font(.subheadline)
        Text(mirror.measureLabel).font(.footnote)
        Text(mirror.targetLabel).font(.footnote)
        if let preview = mirror.previewText {
            Text(preview).font(.footnote)
        }
        if let message = mirror.message {
            Text(message).font(.footnote)
        }
    }

    /// The start and end steppers and the reverse button.
    @ViewBuilder private var sectionRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Stepper(mirror.startLabel,
                    onIncrement: { mirror.stepStart(1) },
                    onDecrement: { mirror.stepStart(-1) })
                .accessibilityLabel("Start of the section to reverse")
                .accessibilityValue(mirror.startLabel)
            Stepper(mirror.endLabel,
                    onIncrement: { mirror.stepEnd(1) },
                    onDecrement: { mirror.stepEnd(-1) })
                .accessibilityLabel("End of the section to reverse")
                .accessibilityValue(mirror.endLabel)
            Button("Reverse") { send("wave.reverse", [Double(mirror.start), Double(mirror.end)]) }
                .accessibilityLabel("Reverse the chosen section in time")
                .accessibilityValue(mirror.sectionLabel)
        }
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        HStack(spacing: 16) {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last reversal")
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the reversal")
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
            Button("Reset view") { resetView() }
                .accessibilityLabel("Return the camera to the authored view")
        }
    }

    /// The tutorial instruction, the hint, the goal and the failure explanation (feature 395).
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
                    Button("Undo") { presenter.undoReversal(port: port) }
                        .accessibilityLabel("Undo the last reversal")
                    Button("Retry") { presenter.retry(port: port) }
                        .accessibilityLabel("Start the level again")
                }
            }
        }
    }

    /// The mode buttons and the picker of open levels with their bands and stars (feature 395).
    @ViewBuilder private var progressRows: some View {
        HStack(spacing: 12) {
            Button("Campaign") { send("mode.campaign") }
                .accessibilityLabel("Play the campaign")
                .accessibilityValue(Self.modeName(mirror.mode) == "campaign" ? "selected" : "")
            Button("Daily") { presenter.playDaily(port: port) }
                .accessibilityLabel("Play today's daily level")
                .accessibilityValue(Self.modeName(mirror.mode) == "daily" ? "selected" : "")
            Button("Practice") { send("mode.practice") }
                .accessibilityLabel("Practise this level with a larger reversal budget")
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
        let band = BackwardsAuroraProgress.band(of: level)
        if let stars = mirror.stars[level] { return "Level \(level), band \(band), \(stars) stars" }
        return "Level \(level), band \(band)"
    }

    /// The mode's name: campaign, daily or practice.
    static func modeName(_ mode: BackwardsAuroraMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        }
    }

    /// Sends `control` through the presenter, which shows and logs a refusal.
    private func send(_ control: String, _ values: [Double] = []) {
        sender(control, values)
    }
}
#endif
