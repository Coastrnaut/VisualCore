// AcousticConstellatorControls — feature 423 (R02-G13-03) T-R02G1303-006 (FR-R02G1303-005; clarification Q5). The
// minimal control panel: labelled buttons for the chosen star (star − and +) and the chosen partner (partner − and +)
// (presentation state only; a level opens with star 0 and partner 1 chosen, both clamped to the level's stars), link
// and unlink (the chosen star and partner), nudge − and + (the chosen star's starting phase by one step) and listen
// (kernel actions through the action port), undo, redo and next level, each with an accessibility label, value and
// identifier; the header shows the actions left of the budget, the status (stage, or the failure in words), the progress
// description, the failure in words and a refused action in words. Touching stars on the canvas and full
// accessibility come in later features of R02-G13.
#if os(iOS)
import AcousticConstellatorCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Acoustic Constellator.
struct AcousticConstellatorControls: View {
    /// Where actions are sent.
    let port: ExperienceActionPort
    /// What the panel shows and chooses.
    let mirror: AcousticConstellatorMirror

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                choiceRows
                linkRow
                nudgeRow
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
        }
    }

    /// The chosen star and partner as the values of `link.add` and `link.remove`.
    private var pairValues: [Double] { [Double(mirror.star), Double(mirror.partner)] }

    /// Sends `control` and shows a refusal in words.
    private func send(_ control: String, _ values: [Double] = []) {
        let result = port.send(control, values)
        mirror.message = result.isAccepted
            ? nil : "That change was refused: \(AcousticConstellatorMirror.refusalText(code: result.code))."
    }
}
#endif
