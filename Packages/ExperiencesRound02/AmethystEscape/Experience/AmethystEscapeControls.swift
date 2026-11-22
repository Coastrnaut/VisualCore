// AmethystEscapeControls — feature 363 (R02-G07-03) T-R02G0703-006 (FR-R02G0703-005; clarification Q5). The minimal
// control panel: a labelled shell picker (previous and next shell, named in words), turn the picked shell − and +,
// advance the pearl, undo, redo and next level, each with an accessibility label and value; every change is a kernel
// action sent through the action port. Bezel dragging, tap to advance and layer isolation come in R02-G07-04; full
// accessibility in R02-G07-06. Feature 364 (R02-G07-04) T-R02G0704-006 (FR-R02G0704-007): the panel gains "Show all
// layers" (clears the isolation) and "Reset view" (returns the camera to the authored view); refusals are shown and
// logged by the presenter. Feature 365 (R02-G07-05) T-R02G0705-005 (FR-R02G0705-001 … 005): the tutorial instruction
// with Dismiss, Hint (each press reveals the next level), the failure explanation with Undo and Retry, the goal and
// stars, Campaign / Daily / Practice and a picker of the open levels; all as wrapping text in the panel, never over the
// crystal. Feature 366 (R02-G07-06) T-R02G0706-005 (FR-R02G0706-001, 005, 006; clarification Q5): every control has a
// label and a value; the shell picker is an adjustable element "Shell to turn" with the value "<Shell>, turned t of N"
// and announces its pick; the turn buttons name the picked shell; a summary element reads the moves left, the pearl,
// the exit gap and every shell; refusals appear in words; a Sound toggle (off by default) starts the ambient loop; rows
// become columns at accessibility text sizes and every text wraps; the panel keeps a readable width of 520 points on
// iPad; the scene phase reaches the presenter so the loop stops in the background.
// Feature 367 (R02-G07-07) T-R02G0707-005 (clarifications Q2, Q4, Q5): "Replay best solution" for a level with a
// verified stored solution, and during replay its position ("Replay: action k of n") with Step and Stop, each with a
// label and a value; the Sound toggle saves the choice through `settings.sound`.
// Feature 369 (R02-G07-09) T-R02G0709-003 (FR-R02G0709-001; clarification Q1): every control also carries the stable
// identifier `experience.r02-g07.amethyst-escape.<name>` (`port.identifier`), the names listed in ``identifierNames``.
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

    /// The text size: rows become columns at accessibility sizes (feature 366).
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Whether the app's scene is active: the ambient loop plays only while it is.
    @Environment(\.scenePhase) private var scenePhase

    /// The widest the panel's content grows, padding included (clarification Q5).
    static let readableWidth: CGFloat = 520

    /// Every control's identifier name (clarification Q1 of feature 369), each once; the identifier is
    /// `experience.r02-g07.amethyst-escape.<name>` (`port.identifier`).
    static let identifierNames: [String] = [
        "turn-down", "turn-up", "advance", "undo", "redo", "next-level", "show-all-layers", "reset-view", "hint",
        "dismiss-tutorial", "failure-undo", "retry", "campaign", "daily", "practice", "play-level", "replay",
        "replay-step", "replay-stop", "shell-picker", "level-picker", "sound", "summary",
    ]

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                shellRow
                playRow
                teaching
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

    /// A row of controls that becomes a column at accessibility text sizes (feature 366).
    @ViewBuilder private func row(@ViewBuilder _ content: () -> some View) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) { content() }
        } else {
            HStack(spacing: 12) { content() }
        }
    }

    /// The shell picker's accessibility label (clarification Q5).
    static let shellPickerLabel = "Shell to turn"

    /// The shell picker's value (clarification Q5): "<Shell>, turned t of N" ("Shell 4 (outer), turned 1 of 8").
    static func shellPickerValue(_ mirror: AmethystEscapeMirror) -> String { mirror.pickedShellValue }

    /// The label of the turn button of `step` (+1 clockwise, −1 anticlockwise), naming the picked shell: "Turn shell 1
    /// (inner) one sector clockwise".
    static func turnLabel(_ mirror: AmethystEscapeMirror, step: Int) -> String {
        let name: String = mirror.shellNames.indices.contains(mirror.pickedShell)
            ? mirror.shellNames[mirror.pickedShell] : "the picked shell"
        return "Turn \(name) one sector \(step > 0 ? "clockwise" : "anticlockwise")"
    }

    /// The value of the play buttons: the level and the moves left (feature 366): "Level n, m moves left".
    static func progressValue(_ mirror: AmethystEscapeMirror) -> String {
        "Level \(mirror.levelNumber), " + AmethystEscapeFeedbackPlan.movesLeft(max(0, mirror.budget - mirror.moves))
    }

    /// Replay of the best stored solution: Replay, or during replay its position with Step and Stop (feature 367).
    @ViewBuilder private var replaySection: some View {
        if mirror.replaying {
            Text(Self.replayPositionText(mirror)).font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            row {
                Button("Step") { presenter.stepReplay(port: port) }
                    .accessibilityIdentifier(port.identifier("replay-step"))
                    .accessibilityLabel("Play the next action of the replay")
                    .accessibilityValue("Action \(mirror.replayPosition) of \(mirror.replayLength)")
                Button("Stop") { presenter.stopReplay(port: port) }
                    .accessibilityIdentifier(port.identifier("replay-stop"))
                    .accessibilityLabel("Stop the replay")
                    .accessibilityValue("\(mirror.replayLength) actions")
            }
        } else if mirror.replayAvailable {
            Button("Replay best solution") { presenter.startReplay(port: port) }
                .accessibilityIdentifier(port.identifier("replay"))
                .accessibilityLabel("Replay your best solution of this level")
                .accessibilityValue("Level \(mirror.levelNumber)")
        }
    }

    /// The replay position line: "Replay: action k of n" (feature 367).
    static func replayPositionText(_ mirror: AmethystEscapeMirror) -> String {
        "Replay: action \(mirror.replayPosition) of \(mirror.replayLength)"
    }

    /// The Sound toggle (feature 366; off by default; saved through `settings.sound` since feature 367).
    @ViewBuilder private var soundToggle: some View {
        Toggle("Sound", isOn: Binding(get: { mirror.soundOn }, set: { presenter.saveSound(on: $0, port: port) }))
            .accessibilityIdentifier(port.identifier("sound"))
            .accessibilityLabel("Ambient sound")
            .accessibilityValue(mirror.soundOn ? "on" : "off")
    }

    /// The level, moves and stage lines, and the summary element (feature 366).
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · moves \(mirror.moves) of \(mirror.budget)")
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
        Text(mirror.status).font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Crystal")
            .accessibilityValue(mirror.summary)
            .accessibilityIdentifier(port.identifier("summary"))
        if let message = mirror.message {
            Text(message).font(.footnote).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The shell picker (adjustable, "Shell to turn") and the turn − and + buttons named by the picked shell.
    @ViewBuilder private var shellRow: some View {
        row {
            Stepper(mirror.pickedShellLabel,
                    onIncrement: { presenter.pickShell(1) },
                    onDecrement: { presenter.pickShell(-1) })
                .accessibilityIdentifier(port.identifier("shell-picker"))
                .accessibilityLabel(Self.shellPickerLabel)
                .accessibilityValue(Self.shellPickerValue(mirror))
            Button("Turn −") { send("shell.rotate", [Double(mirror.pickedShell), -1]) }
                .accessibilityIdentifier(port.identifier("turn-down"))
                .accessibilityLabel(Self.turnLabel(mirror, step: -1))
                .accessibilityValue(Self.shellPickerValue(mirror))
            Button("Turn +") { send("shell.rotate", [Double(mirror.pickedShell), 1]) }
                .accessibilityIdentifier(port.identifier("turn-up"))
                .accessibilityLabel(Self.turnLabel(mirror, step: 1))
                .accessibilityValue(Self.shellPickerValue(mirror))
        }
    }

    /// Advance, undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        row {
            Button("Advance") { send("pearl.advance") }
                .accessibilityIdentifier(port.identifier("advance"))
                .accessibilityLabel("Roll the pearl one pocket")
                .accessibilityValue(mirror.pearlLabel)
            Button("Undo") { send("play.undo") }
                .accessibilityIdentifier(port.identifier("undo"))
                .accessibilityLabel("Undo the last action")
                .accessibilityValue(Self.progressValue(mirror))
            Button("Redo") { send("play.redo") }
                .accessibilityIdentifier(port.identifier("redo"))
                .accessibilityLabel("Redo the action")
                .accessibilityValue(Self.progressValue(mirror))
            Button("Next level") { send("level.next") }
                .accessibilityIdentifier(port.identifier("next-level"))
                .accessibilityLabel("Go to the next level")
                .accessibilityValue("Level \(mirror.levelNumber)")
            Button("Show all layers") { presenter.showAllLayers() }
                .accessibilityIdentifier(port.identifier("show-all-layers"))
                .accessibilityLabel("Show every shell of the crystal")
                .accessibilityValue("layers")
            Button("Reset view") { presenter.resetView() }
                .accessibilityIdentifier(port.identifier("reset-view"))
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
                    .accessibilityIdentifier(port.identifier("dismiss-tutorial"))
                    .accessibilityLabel("Dismiss the tutorial")
                    .accessibilityValue(instruction)
            }
        }
        row {
            Button("Hint") { presenter.showHint() }
                .accessibilityIdentifier(port.identifier("hint"))
                .accessibilityLabel("Show a hint")
                .accessibilityValue(mirror.hintLevel == 0 ? "none shown" : "level \(mirror.hintLevel) of 3")
            Text("Goal: escape in \(mirror.budget) moves; best possible \(mirror.smallest)")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        if let hint = mirror.hintText {
            Text(hint).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
        if let failure = mirror.failureText {
            VStack(alignment: .leading, spacing: 4) {
                Text(failure).font(.callout).fixedSize(horizontal: false, vertical: true)
                row {
                    Button("Undo") { presenter.undoMove(port: port) }
                        .accessibilityIdentifier(port.identifier("failure-undo"))
                        .accessibilityLabel("Undo the last move")
                        .accessibilityValue(failure)
                    Button("Retry") { presenter.retry(port: port) }
                        .accessibilityIdentifier(port.identifier("retry"))
                        .accessibilityLabel("Start the level again")
                        .accessibilityValue("Level \(mirror.levelNumber)")
                }
            }
        }
    }

    /// The mode buttons and the picker of open levels with their bands and stars (feature 365).
    @ViewBuilder private var progressRows: some View {
        row {
            Button("Campaign") { send("mode.campaign") }
                .accessibilityIdentifier(port.identifier("campaign"))
                .accessibilityLabel("Play the campaign")
                .accessibilityValue(Self.modeName(mirror.mode) == "campaign" ? "selected" : "")
            Button("Daily") { presenter.playDaily(port: port) }
                .accessibilityIdentifier(port.identifier("daily"))
                .accessibilityLabel("Play today's daily level")
                .accessibilityValue(Self.modeName(mirror.mode) == "daily" ? "selected" : "")
            Button("Practice") { send("mode.practice") }
                .accessibilityIdentifier(port.identifier("practice"))
                .accessibilityLabel("Practise this level with a larger move budget")
                .accessibilityValue(Self.modeName(mirror.mode) == "practice" ? "selected" : "")
        }
        row {
            Stepper(levelLabel(mirror.pickedLevel),
                    onIncrement: { mirror.pickedLevel = min(mirror.pickedLevel + 1, mirror.frontier) },
                    onDecrement: { mirror.pickedLevel = max(mirror.pickedLevel - 1, 1) })
                .accessibilityIdentifier(port.identifier("level-picker"))
                .accessibilityLabel("Level to play")
                .accessibilityValue(levelLabel(mirror.pickedLevel))
            Button("Play level") { send("level.select", [Double(mirror.pickedLevel)]) }
                .accessibilityIdentifier(port.identifier("play-level"))
                .accessibilityLabel("Play the picked level")
                .accessibilityValue(levelLabel(mirror.pickedLevel))
        }
    }

    /// "Level n, band b" with its stars when won.
    private func levelLabel(_ level: Int) -> String {
        let band = AmethystEscapeProgress.band(of: level)
        if let stars = mirror.stars[level] { return "Level \(level), band \(band), \(stars) stars" }
        return "Level \(level), band \(band)"
    }

    /// The mode's name: campaign, daily, practice or replay.
    static func modeName(_ mode: AmethystEscapeMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        case .replay: "replay"
        }
    }

    /// Sends `control` through the presenter, which shows and logs a refusal.
    private func send(_ control: String, _ values: [Double] = []) {
        presenter.send(control, values, port: port)
    }
}
#endif
