// FacetedForgeControls — feature 373 (R02-G08-03) T-R02G0803-006 (FR-R02G0803-005; clarification Q5). The minimal
// control panel: a labelled piece picker, a direction picker, depth − and + (the preview choice, presentation state
// only), cut (a kernel action through the action port), undo, redo and next level, each with an accessibility label and
// value. Dragging the cut plane's rim, the depth slider, tap to commit and orbit come in R02-G08-04; full accessibility
// in R02-G08-06. Feature 374 (R02-G08-04): "Reset view" returns the camera to the authored view; every action goes
// through the presenter, which shows and logs a refusal like a gesture's. Feature 375 (R02-G08-05) T-R02G0805-005
// (FR-R02G0805-001 … 005): the tutorial instruction with Dismiss, Hint (each press reveals the next level), the failure
// explanation with Undo and Retry, the goal and stars, Campaign / Daily / Practice and a picker of the open levels; all
// as wrapping text in the panel, never over the crystal.
#if os(iOS)
import FacetedForgeCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Faceted Forge.
struct FacetedForgeControls: View {
    let port: ExperienceActionPort
    let mirror: FacetedForgeMirror
    /// The presenter, for "Reset view" (feature 374) and refusals shown and logged like the gestures' ones.
    let presenter: FacetedForgePresenter

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teaching
                choiceRow
                playRow
                progressRows
            }
            .padding()
        }
    }

    /// The level, cuts and stage lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · cuts \(mirror.cuts) of \(mirror.budget)")
            .font(.headline)
        Text(mirror.status).font(.subheadline)
        Text(mirror.targetLabel).font(.footnote)
        if let message = mirror.message {
            Text(message).font(.footnote)
        }
    }

    /// The piece and direction pickers and the depth − and + buttons.
    @ViewBuilder private var choiceRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Stepper(mirror.pieceLabel,
                    onIncrement: { mirror.pickPiece(1) },
                    onDecrement: { mirror.pickPiece(-1) })
                .accessibilityLabel("Piece to cut")
                .accessibilityValue(mirror.pieceLabel)
            Stepper(mirror.directionLabel,
                    onIncrement: { mirror.pickDirection(1) },
                    onDecrement: { mirror.pickDirection(-1) })
                .accessibilityLabel("Direction of the cut")
                .accessibilityValue(mirror.directionLabel)
            HStack(spacing: 12) {
                Button("Depth −") { mirror.stepDepth(-1) }
                    .accessibilityLabel("Move the cut plane one step back")
                    .accessibilityValue(mirror.depthLabel)
                Text(mirror.depthLabel).font(.footnote)
                Button("Depth +") { mirror.stepDepth(1) }
                    .accessibilityLabel("Move the cut plane one step forward")
                    .accessibilityValue(mirror.depthLabel)
            }
        }
    }

    /// The tutorial instruction, the hint and the failure explanation (feature 375).
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
            Text("Goal: match the target in \(mirror.smallest) cuts; budget \(mirror.budget)")
                .font(.footnote)
        }
        if let hint = mirror.hintText {
            Text(hint).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
        if let failure = mirror.failureText {
            VStack(alignment: .leading, spacing: 4) {
                Text(failure).font(.callout).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Button("Undo") { presenter.undoCut(port: port) }
                        .accessibilityLabel("Undo the last cut")
                    Button("Retry") { presenter.retry(port: port) }
                        .accessibilityLabel("Start the level again")
                }
            }
        }
    }

    /// The mode buttons and the picker of open levels with their bands and stars (feature 375).
    @ViewBuilder private var progressRows: some View {
        HStack(spacing: 12) {
            Button("Campaign") { send("mode.campaign") }
                .accessibilityLabel("Play the campaign")
                .accessibilityValue(Self.modeName(mirror.mode) == "campaign" ? "selected" : "")
            Button("Daily") { presenter.playDaily(port: port) }
                .accessibilityLabel("Play today's daily level")
                .accessibilityValue(Self.modeName(mirror.mode) == "daily" ? "selected" : "")
            Button("Practice") { send("mode.practice") }
                .accessibilityLabel("Practise this level with a larger cut budget")
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
        let band = FacetedForgeProgress.band(of: level)
        if let stars = mirror.stars[level] { return "Level \(level), band \(band), \(stars) stars" }
        return "Level \(level), band \(band)"
    }

    /// The mode's name: campaign, daily or practice.
    static func modeName(_ mode: FacetedForgeMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        }
    }

    /// Cut, undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        HStack(spacing: 16) {
            Button("Cut") {
                let choice = mirror.choice
                send("piece.cut", [Double(choice.piece), Double(choice.direction), Double(choice.depth)])
            }
            .accessibilityLabel("Cut the chosen piece with the shown plane")
            .accessibilityValue(mirror.pieceLabel + ", " + mirror.directionLabel + ", " + mirror.depthLabel)
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last cut")
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the cut")
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
            Button("Reset view") { presenter.resetView() }
                .accessibilityLabel("Return the camera to the authored view")
        }
    }

    /// Sends `control` and shows a refusal.
    private func send(_ control: String, _ values: [Double] = []) {
        presenter.send(control, values, port: port)
    }
}
#endif
