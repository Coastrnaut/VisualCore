// FacetedForgeControls — feature 373 (R02-G08-03) T-R02G0803-006 (FR-R02G0803-005; clarification Q5). The minimal
// control panel: a labelled piece picker, a direction picker, depth − and + (the preview choice, presentation state
// only), cut (a kernel action through the action port), undo, redo and next level, each with an accessibility label and
// value. Dragging the cut plane's rim, the depth slider, tap to commit and orbit come in R02-G08-04; full accessibility
// in R02-G08-06. Feature 374 (R02-G08-04): "Reset view" returns the camera to the authored view; every action goes
// through the presenter, which shows and logs a refusal like a gesture's. Feature 375 (R02-G08-05) T-R02G0805-005
// (FR-R02G0805-001 … 005): the tutorial instruction with Dismiss, Hint (each press reveals the next level), the failure
// explanation with Undo and Retry, the goal and stars, Campaign / Daily / Practice and a picker of the open levels; all
// as wrapping text in the panel, never over the crystal. Feature 376 (R02-G08-06) T-R02G0806-005 (FR-R02G0806-001,
// 005, 006): the summary element ("Crystal"), adjustable piece, direction and depth pickers, the Sound toggle, rows
// that become columns at accessibility text sizes and a 520-point readable width. Feature 377 (R02-G08-07)
// T-R02G0807-005 (clarifications Q2, Q4, Q5): "Replay best solution" for a level with a verified stored solution, and
// during replay its position ("Replay: cut k of n") with Step and Stop, each with a label and a value; the Sound toggle
// saves the choice through `settings.sound`. Feature 379 (R02-G08-09) T-R02G0809-003 (FR-R02G0809-001; clarification
// Q1): every control also carries the stable identifier `experience.r02-g08.faceted-forge.<name>` (`port.identifier`),
// the names listed in ``identifierNames``.
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

    /// The text size: rows become columns at accessibility sizes (feature 376).
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Whether the app's scene is active: the ambient loop plays only while it is.
    @Environment(\.scenePhase) private var scenePhase

    /// Every control's identifier name (clarification Q1 of feature 379), each once; the identifier is
    /// `experience.r02-g08.faceted-forge.<name>` (`port.identifier`).
    static let identifierNames: [String] = [
        "cut", "undo", "redo", "next-level", "depth-down", "depth-up", "reset-view", "hint", "dismiss-tutorial",
        "failure-undo", "retry", "campaign", "daily", "practice", "play-level", "replay", "replay-step", "replay-stop",
        "piece-picker", "direction-picker", "depth-picker", "level-picker", "sound", "summary",
    ]

    /// The widest the panel's content grows, padding included (clarification Q5 of feature 376).
    static let readableWidth: CGFloat = 520

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teaching
                choiceRow
                playRow
                progressRows
                replaySection
                soundToggle
            }
            .padding()
            .frame(maxWidth: Self.readableWidth, alignment: .leading)
        }
        .onAppear { presenter.controlsAppeared() }
        .onDisappear { presenter.controlsDisappeared() }
        .onChange(of: scenePhase) { _, phase in presenter.sceneActive(phase == .active) }
    }

    /// A row of controls that becomes a column at accessibility text sizes (feature 376).
    @ViewBuilder private func row(@ViewBuilder _ content: () -> some View) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) { content() }
        } else {
            HStack(spacing: 12) { content() }
        }
    }

    /// Replay of the best stored solution: Replay, or during replay its position with Step and Stop (feature 377).
    @ViewBuilder private var replaySection: some View {
        if mirror.replaying {
            Text(Self.replayPositionText(mirror)).font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            row {
                Button("Step") { presenter.stepReplay(port: port) }
                    .accessibilityLabel("Play the next cut of the replay")
                    .accessibilityValue("Cut \(mirror.replayPosition) of \(mirror.replayLength)")
                    .accessibilityIdentifier(port.identifier("replay-step"))
                Button("Stop") { presenter.stopReplay(port: port) }
                    .accessibilityLabel("Stop the replay")
                    .accessibilityValue("\(mirror.replayLength) cuts")
                    .accessibilityIdentifier(port.identifier("replay-stop"))
            }
        } else if mirror.replayAvailable {
            Button("Replay best solution") { presenter.startReplay(port: port) }
                .accessibilityLabel("Replay your best solution of this level")
                .accessibilityValue("Level \(mirror.levelNumber)")
                .accessibilityIdentifier(port.identifier("replay"))
        }
    }

    /// The replay position line: "Replay: cut k of n" (feature 377).
    static func replayPositionText(_ mirror: FacetedForgeMirror) -> String {
        "Replay: cut \(mirror.replayPosition) of \(mirror.replayLength)"
    }

    /// The Sound toggle (feature 376; off by default; saved through `settings.sound` since feature 377).
    @ViewBuilder private var soundToggle: some View {
        Toggle("Sound", isOn: Binding(get: { mirror.soundOn }, set: { presenter.saveSound(on: $0, port: port) }))
            .accessibilityLabel("Ambient sound")
            .accessibilityValue(mirror.soundOn ? "on" : "off")
            .accessibilityIdentifier(port.identifier("sound"))
    }

    /// The level, cuts and stage lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · cuts \(mirror.cuts) of \(mirror.budget)")
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
        Text(mirror.status).font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Crystal")
            .accessibilityValue(mirror.summary)
            .accessibilityIdentifier(port.identifier("summary"))
        Text(mirror.targetLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
        if let message = mirror.message {
            Text(message).font(.footnote).fixedSize(horizontal: false, vertical: true)
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
                .accessibilityIdentifier(port.identifier("piece-picker"))
            Stepper(mirror.directionLabel,
                    onIncrement: { mirror.pickDirection(1) },
                    onDecrement: { mirror.pickDirection(-1) })
                .accessibilityLabel("Direction of the cut")
                .accessibilityValue(mirror.directionLabel)
                .accessibilityIdentifier(port.identifier("direction-picker"))
            Stepper(mirror.depthLabel,
                    onIncrement: { mirror.stepDepth(1) },
                    onDecrement: { mirror.stepDepth(-1) })
                .accessibilityLabel("Depth of the cut")
                .accessibilityValue(mirror.depthLabel)
                .accessibilityIdentifier(port.identifier("depth-picker"))
            row {
                Button("Depth −") { mirror.stepDepth(-1) }
                    .accessibilityLabel("Move the cut plane one step back")
                    .accessibilityIdentifier(port.identifier("depth-down"))
                    .accessibilityValue(mirror.depthLabel)
                Button("Depth +") { mirror.stepDepth(1) }
                    .accessibilityLabel("Move the cut plane one step forward")
                    .accessibilityIdentifier(port.identifier("depth-up"))
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
                    .accessibilityIdentifier(port.identifier("dismiss-tutorial"))
            }
        }
        row {
            Button("Hint") { presenter.showHint() }
                .accessibilityLabel("Show a hint")
                .accessibilityValue(mirror.hintLevel == 0 ? "none shown" : "level \(mirror.hintLevel) of 3")
                .accessibilityIdentifier(port.identifier("hint"))
            Text("Goal: match the target in \(mirror.smallest) cuts; budget \(mirror.budget)")
                .font(.footnote)
        }
        if let hint = mirror.hintText {
            Text(hint).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
        if let failure = mirror.failureText {
            VStack(alignment: .leading, spacing: 4) {
                Text(failure).font(.callout).fixedSize(horizontal: false, vertical: true)
                row {
                    Button("Undo") { presenter.undoCut(port: port) }
                        .accessibilityLabel("Undo the last cut")
                        .accessibilityIdentifier(port.identifier("failure-undo"))
                    Button("Retry") { presenter.retry(port: port) }
                        .accessibilityLabel("Start the level again")
                        .accessibilityIdentifier(port.identifier("retry"))
                }
            }
        }
    }

    /// The mode buttons and the picker of open levels with their bands and stars (feature 375).
    @ViewBuilder private var progressRows: some View {
        row {
            Button("Campaign") { send("mode.campaign") }
                .accessibilityLabel("Play the campaign")
                .accessibilityValue(Self.modeName(mirror.mode) == "campaign" ? "selected" : "")
                .accessibilityIdentifier(port.identifier("campaign"))
            Button("Daily") { presenter.playDaily(port: port) }
                .accessibilityLabel("Play today's daily level")
                .accessibilityValue(Self.modeName(mirror.mode) == "daily" ? "selected" : "")
                .accessibilityIdentifier(port.identifier("daily"))
            Button("Practice") { send("mode.practice") }
                .accessibilityLabel("Practise this level with a larger cut budget")
                .accessibilityValue(Self.modeName(mirror.mode) == "practice" ? "selected" : "")
                .accessibilityIdentifier(port.identifier("practice"))
        }
        row {
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
        let band = FacetedForgeProgress.band(of: level)
        if let stars = mirror.stars[level] { return "Level \(level), band \(band), \(stars) stars" }
        return "Level \(level), band \(band)"
    }

    /// The mode's name: campaign, daily, practice or replay.
    static func modeName(_ mode: FacetedForgeMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        case .replay: "replay"
        }
    }

    /// Cut, undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        row {
            Button("Cut") {
                let choice = mirror.choice
                send("piece.cut", [Double(choice.piece), Double(choice.direction), Double(choice.depth)])
            }
            .accessibilityLabel("Cut the chosen piece with the shown plane")
            .accessibilityValue(mirror.pieceLabel + ", " + mirror.directionLabel + ", " + mirror.depthLabel)
            .accessibilityIdentifier(port.identifier("cut"))
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last cut")
                .accessibilityIdentifier(port.identifier("undo"))
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the cut")
                .accessibilityIdentifier(port.identifier("redo"))
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
                .accessibilityIdentifier(port.identifier("next-level"))
            Button("Reset view") { presenter.resetView() }
                .accessibilityLabel("Return the camera to the authored view")
                .accessibilityIdentifier(port.identifier("reset-view"))
        }
    }

    /// Sends `control` and shows a refusal.
    private func send(_ control: String, _ values: [Double] = []) {
        presenter.send(control, values, port: port)
    }
}
#endif
