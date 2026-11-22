// NocturneGardenControls — feature 383 (R02-G09-03) T-R02G0903-006 (FR-R02G0903-005; clarification Q5). The minimal
// control panel: labelled pickers for the kind, the column, the row, the size and the bloom (presentation state only),
// plant, move, resize and remove (kernel actions through the action port), a sun picker (Sun − and +) with "Set sun"
// (feature 384: one move reaches any allowed elevation), undo, redo, next level and "Reset view", each with an
// accessibility label and value. Feature 385 (R02-G09-05) T-R02G0905-005: the tutorial instruction with Dismiss, Hint
// (each press reveals the next level), the failure explanation with Undo and Retry, the goal and stars, Campaign / Daily /
// Practice and a picker of the open levels; all as wrapping text in the panel, never over the garden. Dragging stems, pinching to scale and sliding the sun come in R02-G09-04;
// full accessibility in R02-G09-06.
#if os(iOS)
import NocturneGardenCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Nocturne Garden.
struct NocturneGardenControls: View {
    let port: ExperienceActionPort
    let mirror: NocturneGardenMirror
    /// The presenter (feature 385): hints, retry, undo and the daily level.
    let presenter: NocturneGardenPresenter
    /// Returns the camera to the authored view (feature 384).
    let resetView: () -> Void
    /// Sends a control the way the presenter does (refusals shown and logged).
    let sender: (String, [Double]) -> Void

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teaching
                pickRow
                bloomRow
                playRow
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
        Text(mirror.measureLabel).font(.footnote)
        Text(mirror.targetLabel).font(.footnote)
        if let preview = mirror.previewText {
            // Feature 384 convergence (T-R02G0904-014): the drag's exact preview in words.
            Text("Dragging: " + preview).font(.footnote)
                .accessibilityLabel("Drag preview")
                .accessibilityValue(preview)
        }
        if let message = mirror.message {
            Text(message).font(.footnote)
        }
    }

    /// The kind, column, row and size pickers and the plant button.
    @ViewBuilder private var pickRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Stepper(mirror.kindLabel,
                    onIncrement: { mirror.pickKind(1) },
                    onDecrement: { mirror.pickKind(-1) })
                .accessibilityLabel("Bloom kind to plant")
                .accessibilityValue(mirror.kindLabel)
            Stepper(mirror.columnLabel,
                    onIncrement: { mirror.stepColumn(1) },
                    onDecrement: { mirror.stepColumn(-1) })
                .accessibilityLabel("Column of the anchor cell")
                .accessibilityValue(mirror.columnLabel)
            Stepper(mirror.rowLabel,
                    onIncrement: { mirror.stepRow(1) },
                    onDecrement: { mirror.stepRow(-1) })
                .accessibilityLabel("Row of the anchor cell")
                .accessibilityValue(mirror.rowLabel)
            Stepper(mirror.sizeLabel,
                    onIncrement: { mirror.stepSize(1) },
                    onDecrement: { mirror.stepSize(-1) })
                .accessibilityLabel("Bloom size")
                .accessibilityValue(mirror.sizeLabel)
            Button("Plant") {
                send("bloom.plant", [Double(mirror.kind), Double(mirror.column), Double(mirror.row),
                                     Double(mirror.size)])
            }
            .accessibilityLabel("Plant the chosen bloom at the chosen cell")
            .accessibilityValue(mirror.kindLabel + ", " + mirror.columnLabel + ", " + mirror.rowLabel + ", "
                                + mirror.sizeLabel)
        }
    }

    /// The bloom picker with move, resize and remove.
    @ViewBuilder private var bloomRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Stepper(mirror.bloomLabel,
                    onIncrement: { mirror.pickBloom(1) },
                    onDecrement: { mirror.pickBloom(-1) })
                .accessibilityLabel("Planted bloom to change")
                .accessibilityValue(mirror.bloomLabel)
            HStack(spacing: 12) {
                Button("Move") {
                    send("bloom.move", [Double(mirror.bloom), Double(mirror.column), Double(mirror.row)])
                }
                .accessibilityLabel("Move the chosen bloom to the chosen cell")
                Button("Resize") { send("bloom.resize", [Double(mirror.bloom), Double(mirror.size)]) }
                    .accessibilityLabel("Give the chosen bloom the chosen size")
                Button("Remove") { send("bloom.remove", [Double(mirror.bloom)]) }
                    .accessibilityLabel("Remove the chosen bloom")
            }
        }
    }

    /// Sun − and +, undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Button("Sun −") { mirror.stepSun(-1) }
                    .accessibilityLabel("Pick a higher sun")
                    .accessibilityValue(mirror.sunPickLabel)
                Text(mirror.sunPickLabel).font(.footnote)
                Button("Sun +") { mirror.stepSun(1) }
                    .accessibilityLabel("Pick a lower sun")
                    .accessibilityValue(mirror.sunPickLabel)
                Button("Set sun") { send("sun.set", [Double(mirror.sunPick)]) }
                    .accessibilityLabel("Move the sun to the picked elevation")
                    .accessibilityValue(mirror.sunLabel + "; picked " + mirror.sunPickLabel)
            }
            HStack(spacing: 16) {
                Button("Undo") { send("play.undo") }
                    .accessibilityLabel("Undo the last move")
                Button("Redo") { send("play.redo") }
                    .accessibilityLabel("Redo the move")
                Button("Next level") { send("level.next") }
                    .accessibilityLabel("Go to the next level")
                Button("Reset view") { resetView() }
                    .accessibilityLabel("Return the camera to the authored view")
            }
        }
    }

    /// The tutorial instruction, the hint and the failure explanation (feature 385).
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
            Text("Goal: match in \(mirror.smallest) moves; budget \(mirror.budget)")
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

    /// The mode buttons and the picker of open levels with their bands and stars (feature 385).
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
        let band = NocturneGardenProgress.band(of: level)
        if let stars = mirror.stars[level] { return "Level \(level), band \(band), \(stars) stars" }
        return "Level \(level), band \(band)"
    }

    /// The mode's name: campaign, daily or practice.
    static func modeName(_ mode: NocturneGardenMode) -> String {
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
