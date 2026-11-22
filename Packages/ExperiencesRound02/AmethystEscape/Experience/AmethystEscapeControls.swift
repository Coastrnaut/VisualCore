// AmethystEscapeControls — feature 363 (R02-G07-03) T-R02G0703-006 (FR-R02G0703-005; clarification Q5). The minimal
// control panel: a labelled shell picker (previous and next shell, named in words), turn the picked shell − and +,
// advance the pearl, undo, redo and next level, each with an accessibility label and value; every change is a kernel
// action sent through the action port. Bezel dragging, tap to advance and layer isolation come in R02-G07-04; full
// accessibility in R02-G07-06. Feature 364 (R02-G07-04) T-R02G0704-006 (FR-R02G0704-007): the panel gains "Show all
// layers" (clears the isolation) and "Reset view" (returns the camera to the authored view); refusals are shown and
// logged by the presenter. Feature 365 (R02-G07-05) T-R02G0705-005 (FR-R02G0705-001 … 005): the tutorial instruction
// with Dismiss, Hint (each press reveals the next level), the failure explanation with Undo and Retry, the goal and
// stars, Campaign / Daily / Practice and a picker of the open levels; all as wrapping text in the panel, never over the
// crystal.
#if os(iOS)
import AmethystEscapeCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Amethyst Escape.
struct AmethystEscapeControls: View {
    let port: ExperienceActionPort
    let mirror: AmethystEscapeMirror
    /// The presenter, for "Show all layers", "Reset view" (feature 364) and refusals shown like the gestures' ones.
    let presenter: AmethystEscapePresenter

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                shellRow
                playRow
                teaching
                progressRows
            }
            .padding()
        }
    }

    /// The level, moves and stage lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · moves \(mirror.moves) of \(mirror.budget)")
            .font(.headline)
        Text(mirror.status).font(.subheadline)
        if let message = mirror.message {
            Text(message).font(.footnote)
        }
    }

    /// The shell picker and the turn − and + buttons.
    @ViewBuilder private var shellRow: some View {
        HStack(spacing: 12) {
            Stepper(mirror.pickedShellLabel,
                    onIncrement: { mirror.pickNext(1) },
                    onDecrement: { mirror.pickNext(-1) })
                .accessibilityLabel("Shell to turn")
                .accessibilityValue(mirror.pickedShellLabel)
            Button("Turn −") { send("shell.rotate", [Double(mirror.pickedShell), -1]) }
                .accessibilityLabel("Turn the picked shell one sector anticlockwise")
                .accessibilityValue(mirror.pickedOffsetLabel)
            Button("Turn +") { send("shell.rotate", [Double(mirror.pickedShell), 1]) }
                .accessibilityLabel("Turn the picked shell one sector clockwise")
                .accessibilityValue(mirror.pickedOffsetLabel)
        }
    }

    /// Advance, undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        HStack(spacing: 16) {
            Button("Advance") { send("pearl.advance") }
                .accessibilityLabel("Roll the pearl one pocket")
                .accessibilityValue(mirror.pearlLabel)
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last action")
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the action")
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
            Button("Show all layers") { presenter.showAllLayers() }
                .accessibilityLabel("Show every shell of the crystal")
                .accessibilityValue("layers")
            Button("Reset view") { presenter.resetView() }
                .accessibilityLabel("Return the camera to the starting view")
                .accessibilityValue("camera")
        }
    }

    /// The tutorial instruction, the hint and the failure explanation (feature 365).
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
            Text("Goal: escape in \(mirror.budget) moves; best possible \(mirror.smallest)")
                .font(.footnote)
        }
        if let hint = mirror.hintText {
            Text(hint).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
        if let failure = mirror.failureText {
            VStack(alignment: .leading, spacing: 4) {
                Text(failure).font(.callout).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Button("Undo") { presenter.undoMove(port: port) }
                        .accessibilityLabel("Undo the last move")
                    Button("Retry") { presenter.retry(port: port) }
                        .accessibilityLabel("Start the level again")
                }
            }
        }
    }

    /// The mode buttons and the picker of open levels with their bands and stars (feature 365).
    @ViewBuilder private var progressRows: some View {
        HStack(spacing: 12) {
            Button("Campaign") { send("mode.campaign") }
                .accessibilityLabel("Play the campaign")
                .accessibilityValue(Self.modeName(mirror.mode) == "campaign" ? "selected" : "")
            Button("Daily") { presenter.playDaily(port: port) }
                .accessibilityLabel("Play today's daily level")
                .accessibilityValue(Self.modeName(mirror.mode) == "daily" ? "selected" : "")
            Button("Practice") { send("mode.practice") }
                .accessibilityLabel("Practise this level with a larger move budget")
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
        let band = AmethystEscapeProgress.band(of: level)
        if let stars = mirror.stars[level] { return "Level \(level), band \(band), \(stars) stars" }
        return "Level \(level), band \(band)"
    }

    /// The mode's name: campaign, daily or practice.
    static func modeName(_ mode: AmethystEscapeMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        }
    }

    /// Sends `control` through the presenter, which shows and logs a refusal.
    private func send(_ control: String, _ values: [Double] = []) {
        presenter.send(control, values, port: port)
    }
}
#endif
