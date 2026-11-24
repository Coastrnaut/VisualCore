// AcousticConstellatorControls — feature 423 (R02-G13-03) T-R02G1303-006 (FR-R02G1303-005; clarification Q5). The
// minimal control panel: labelled buttons for the chosen star (star − and +) and the chosen partner (partner − and +)
// (presentation state only; a level opens with star 0 and partner 1 chosen, both clamped to the level's stars), link
// and unlink (the chosen star and partner), nudge − and + (the chosen star's starting phase by one step) and listen
// (kernel actions through the action port), undo, redo and next level, each with an accessibility label, value and
// identifier; the header shows the actions left of the budget, the status (stage, or the failure in words), the progress
// description, the failure in words and a refused action in words. Feature 424 (R02-G13-04) adds "Reset view" (the
// authored camera) and sends through the presenter, which shows and logs refusals; full accessibility comes in
// R02-G13-06. Feature 425 (R02-G13-05) T-R02G1305-005: the tutorial instruction with Dismiss, Hint (each press
// reveals the next level), the failure explanation with Undo and Retry, the goal with the level's band and best stars,
// Campaign / Daily / Practice and a picker of the open levels with Play level; all as wrapping text in the panel, never
// over the stars. "Next level" stays; before a win it is refused in words.
#if os(iOS)
import AcousticConstellatorCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Acoustic Constellator.
struct AcousticConstellatorControls: View {
    /// The action port (its identifiers name the controls).
    let port: ExperienceActionPort
    /// What the panel shows and chooses.
    let mirror: AcousticConstellatorMirror
    /// The presenter (feature 425): hints, tutorial, retry, undo and the daily level.
    let presenter: AcousticConstellatorPresenter
    /// Returns the camera to the authored view (feature 424).
    let resetView: () -> Void
    /// Sends a control with its values through the presenter (which shows and logs a refusal).
    let sender: (String, [Double]) -> Void

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teaching
                choiceRows
                linkRow
                nudgeRow
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
    }

    /// The star and partner choice buttons.
    @ViewBuilder private var choiceRows: some View {
        HStack(spacing: 16) {
            Button("Star −") { mirror.stepStar(-1) }
                .accessibilityLabel("Choose the previous star")
                .accessibilityValue(mirror.starDetail)
                .accessibilityIdentifier(port.identifier("star-minus"))
            Text(mirror.starLabel)
                .accessibilityIdentifier(port.identifier("star"))
            Button("Star +") { mirror.stepStar(1) }
                .accessibilityLabel("Choose the next star")
                .accessibilityValue(mirror.starDetail)
                .accessibilityIdentifier(port.identifier("star-plus"))
        }
        HStack(spacing: 16) {
            Button("Partner −") { mirror.stepPartner(-1) }
                .accessibilityLabel("Choose the previous partner star")
                .accessibilityValue(mirror.partnerDetail)
                .accessibilityIdentifier(port.identifier("partner-minus"))
            Text(mirror.partnerLabel)
                .accessibilityIdentifier(port.identifier("partner"))
            Button("Partner +") { mirror.stepPartner(1) }
                .accessibilityLabel("Choose the next partner star")
                .accessibilityValue(mirror.partnerDetail)
                .accessibilityIdentifier(port.identifier("partner-plus"))
        }
        Text(mirror.choiceLabel).font(.footnote)
            .accessibilityIdentifier(port.identifier("choice"))
    }

    /// Link and unlink the chosen pair.
    @ViewBuilder private var linkRow: some View {
        HStack(spacing: 16) {
            Button("Link") { send("link.add", pairValues) }
                .accessibilityLabel("Link the chosen star to the partner")
                .accessibilityValue(mirror.choiceLabel)
                .accessibilityIdentifier(port.identifier("link"))
            Button("Unlink") { send("link.remove", pairValues) }
                .accessibilityLabel("Remove the link between the chosen star and the partner")
                .accessibilityValue(mirror.choiceLabel)
                .accessibilityIdentifier(port.identifier("unlink"))
        }
    }

    /// Nudge the chosen star's phase and listen.
    @ViewBuilder private var nudgeRow: some View {
        HStack(spacing: 16) {
            Button("Nudge −") { send("star.nudge", [Double(mirror.star), -1]) }
                .accessibilityLabel("Nudge the chosen star's phase back one step")
                .accessibilityValue(mirror.starDetail)
                .accessibilityIdentifier(port.identifier("nudge-minus"))
            Button("Nudge +") { send("star.nudge", [Double(mirror.star), 1]) }
                .accessibilityLabel("Nudge the chosen star's phase forward one step")
                .accessibilityValue(mirror.starDetail)
                .accessibilityIdentifier(port.identifier("nudge-plus"))
            Button("Listen") { send("constellation.listen") }
                .accessibilityLabel("Listen to the constellation")
                .accessibilityValue(mirror.measureLabel)
                .accessibilityIdentifier(port.identifier("listen"))
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

    /// The tutorial instruction, the hint, the goal and the failure's Undo and Retry (feature 425); the failure
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

    /// The mode buttons and the picker of open levels with their bands and stars (feature 425).
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
        let band: Int = AcousticConstellatorProgress.band(of: level)
        if let stars = mirror.stars[level] { return "Level \(level), band \(band), \(stars) stars" }
        return "Level \(level), band \(band)"
    }

    /// The mode's name: campaign, daily or practice.
    static func modeName(_ mode: AcousticConstellatorMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        }
    }

    /// The chosen star and partner as the values of `link.add` and `link.remove`.
    private var pairValues: [Double] { [Double(mirror.star), Double(mirror.partner)] }

    /// Sends `control` through the presenter.
    private func send(_ control: String, _ values: [Double] = []) {
        sender(control, values)
    }
}
#endif
