// EchoCartographerControls — feature 403 (R02-G11-03) T-R02G1103-006 (FR-R02G1103-005; clarification Q5). The minimal
// control panel: labelled steppers for the cursor's column and row (presentation state only), pulse, claim and mark at
// the cursor (kernel actions through the action port), undo, redo and next level, each with an accessibility label and
// value. Feature 404 (R02-G11-04) adds "Reset view" (the authored camera) and sends through the presenter, which shows
// and logs refusals; full accessibility comes in R02-G11-06. Feature 405 (R02-G11-05) T-R02G1105-005: the tutorial
// instruction with Dismiss, Hint (each press reveals the next level), the failure explanation with Undo and Retry, the
// goal with the level's band and best stars, Campaign / Daily / Practice and a picker of the open levels; all as
// wrapping text in the panel, never over the chamber. Feature 406 (R02-G11-06) T-R02G1106-005 (FR-R02G1106-001, 005,
// 006; clarification Q5): the summary element ("Chamber"), adjustable column and row steppers whose values name the
// cell and what is known of it, a value in words on every control, refusals in words, the Sound toggle (off by
// default), rows that become columns at accessibility text sizes, wrapping text and a 520-point readable width.
// Feature 407 (R02-G11-07) T-R02G1107-005 (clarifications Q2, Q4, Q5): "Replay best solution" for a level with a
// verified stored solution, and during replay its position ("Replay: action k of n") with Step and Stop, each with a
// label and a value; the Sound toggle saves the choice through `settings.sound`.
// Feature 409 (R02-G11-09) T-R02G1109-003 (FR-R02G1109-001; clarification Q1): every control also carries the stable
// identifier `experience.r02-g11.echo-cartographer.<name>` (`port.identifier`), the names listed in ``identifierNames``.
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
    /// The text size: rows become columns at accessibility sizes (feature 406).
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Whether the app's scene is active: the ambient loop plays only while it is.
    @Environment(\.scenePhase) private var scenePhase

    /// Every control's identifier name (clarification Q1 of feature 409), each once; the identifier is
    /// `experience.r02-g11.echo-cartographer.<name>` (`port.identifier`).
    static let identifierNames: [String] = [
        "pulse", "claim", "mark", "undo", "redo", "next-level", "reset-view", "hint", "dismiss-tutorial", "failure-undo",
        "retry", "campaign", "daily", "practice", "play-level", "replay", "replay-step", "replay-stop", "column-picker",
        "row-picker", "level-picker", "sound", "summary",
    ]

    /// The widest the panel's content grows, padding included (clarification Q5 of feature 406).
    static let readableWidth: CGFloat = 520

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teaching
                cursorRow
                cellRow
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

    /// A row of controls that becomes a column at accessibility text sizes (feature 406).
    @ViewBuilder private func row(@ViewBuilder _ content: () -> some View) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) { content() }
        } else {
            HStack(spacing: 12) { content() }
        }
    }

    /// The Sound toggle (feature 406; off by default; saved through `settings.sound` since feature 407).
    @ViewBuilder private var soundToggle: some View {
        Toggle("Sound", isOn: Binding(get: { mirror.soundOn }, set: { presenter.saveSound(on: $0, port: port) }))
            .accessibilityLabel("Ambient sound")
            .accessibilityIdentifier(port.identifier("sound"))
            .accessibilityValue(mirror.soundOn ? "on" : "off")
    }

    /// The level, energy and stage lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · energy \(mirror.energy) of \(mirror.budget)")
            .font(.headline)
        Text(mirror.status).font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Chamber")
            .accessibilityIdentifier(port.identifier("summary"))
            .accessibilityValue(mirror.summary)
        Text(mirror.measureLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
        Text(mirror.targetLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
        if let message = mirror.message {
            Text(message).font(.footnote).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The column and row steppers.
    @ViewBuilder private var cursorRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Stepper(mirror.columnLabel,
                    onIncrement: { mirror.stepColumn(1); presenter.refreshSummary() },
                    onDecrement: { mirror.stepColumn(-1); presenter.refreshSummary() })
                .accessibilityLabel("Column of the chosen cell")
                .accessibilityIdentifier(port.identifier("column-picker"))
                .accessibilityValue(mirror.cursorLabel)
            Stepper(mirror.rowLabel,
                    onIncrement: { mirror.stepRow(1); presenter.refreshSummary() },
                    onDecrement: { mirror.stepRow(-1); presenter.refreshSummary() })
                .accessibilityLabel("Row of the chosen cell")
                .accessibilityIdentifier(port.identifier("row-picker"))
                .accessibilityValue(mirror.cursorLabel)
        }
    }

    /// Pulse, claim and mark at the cursor.
    @ViewBuilder private var cellRow: some View {
        row {
            Button("Pulse") { send("cell.pulse", cursorValues) }
                .accessibilityLabel("Send a pulse from the chosen cell")
                .accessibilityIdentifier(port.identifier("pulse"))
                .accessibilityValue(mirror.cursorLabel)
            Button("Claim") { send("cell.claim", cursorValues) }
                .accessibilityLabel("Claim a beacon at the chosen cell")
                .accessibilityIdentifier(port.identifier("claim"))
                .accessibilityValue(mirror.cursorLabel)
            Button("Mark") { send("cell.mark", cursorValues) }
                .accessibilityLabel("Toggle a marker on the chosen cell")
                .accessibilityIdentifier(port.identifier("mark"))
                .accessibilityValue(mirror.cursorLabel)
        }
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        row {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last action")
                .accessibilityIdentifier(port.identifier("undo"))
                .accessibilityValue(Self.values(mirror).energy)
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the action")
                .accessibilityIdentifier(port.identifier("redo"))
                .accessibilityValue(Self.values(mirror).energy)
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
                .accessibilityIdentifier(port.identifier("next-level"))
                .accessibilityValue(Self.values(mirror).nextLevel)
            Button("Reset view") { resetView() }
                .accessibilityLabel("Return the camera to the authored view")
                .accessibilityIdentifier(port.identifier("reset-view"))
                .accessibilityValue(Self.viewValue(presenter.gestures.orbit == .authored))
        }
    }

    /// The tutorial instruction, the hint, the goal and the failure explanation (feature 405).
    @ViewBuilder private var teaching: some View {
        if let instruction = mirror.instruction {
            VStack(alignment: .leading, spacing: 4) {
                Text(instruction).font(.callout).fixedSize(horizontal: false, vertical: true)
                Button("Dismiss") { presenter.dismissTutorial(port: port) }
                    .accessibilityLabel("Dismiss the tutorial")
                    .accessibilityIdentifier(port.identifier("dismiss-tutorial"))
                    .accessibilityValue(instruction)
            }
        }
        row {
            Button("Hint") { presenter.showHint() }
                .accessibilityLabel("Show a hint")
                .accessibilityIdentifier(port.identifier("hint"))
                .accessibilityValue(mirror.hintLevel == 0 ? "none shown" : "level \(mirror.hintLevel) of 3")
            Text(mirror.goalLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
        }
        if let hint = mirror.hintText {
            Text(hint).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
        if let failure = mirror.failureText {
            VStack(alignment: .leading, spacing: 4) {
                Text(failure).font(.callout).fixedSize(horizontal: false, vertical: true)
                row {
                    Button("Undo") { presenter.undoAction(port: port) }
                        .accessibilityLabel("Undo the last action")
                        .accessibilityIdentifier(port.identifier("failure-undo"))
                        .accessibilityValue(Self.values(mirror).energy)
                    Button("Retry") { presenter.retry(port: port) }
                        .accessibilityLabel("Start the level again")
                        .accessibilityIdentifier(port.identifier("retry"))
                        .accessibilityValue(Self.values(mirror).retry)
                }
            }
        }
    }

    /// The mode buttons and the picker of open levels with their bands and stars (feature 405).
    @ViewBuilder private var progressRows: some View {
        row {
            Button("Campaign") { send("mode.campaign") }
                .accessibilityLabel("Play the campaign")
                .accessibilityIdentifier(port.identifier("campaign"))
                .accessibilityValue(Self.selectedValue(Self.modeName(mirror.mode) == "campaign"))
            Button("Daily") { presenter.playDaily(port: port) }
                .accessibilityLabel("Play today's daily level")
                .accessibilityIdentifier(port.identifier("daily"))
                .accessibilityValue(Self.selectedValue(Self.modeName(mirror.mode) == "daily"))
            Button("Practice") { send("mode.practice") }
                .accessibilityLabel("Practise this level with more energy")
                .accessibilityIdentifier(port.identifier("practice"))
                .accessibilityValue(Self.selectedValue(Self.modeName(mirror.mode) == "practice"))
        }
        row {
            Stepper(levelLabel(mirror.pickedLevel),
                    onIncrement: { mirror.pickedLevel = min(mirror.pickedLevel + 1, mirror.frontier) },
                    onDecrement: { mirror.pickedLevel = max(mirror.pickedLevel - 1, 1) })
                .accessibilityLabel("Level to play")
                .accessibilityIdentifier(port.identifier("level-picker"))
                .accessibilityValue(levelLabel(mirror.pickedLevel))
            Button("Play level") { send("level.select", [Double(mirror.pickedLevel)]) }
                .accessibilityLabel("Play the picked level")
                .accessibilityIdentifier(port.identifier("play-level"))
                .accessibilityValue(Self.values(mirror).playLevel)
        }
    }

    /// "Level n, band b" with its stars when won.
    private func levelLabel(_ level: Int) -> String {
        let band: Int = EchoCartographerProgress.band(of: level)
        if let stars = mirror.stars[level] { return "Level \(level), band \(band), \(stars) stars" }
        return "Level \(level), band \(band)"
    }

    /// Replay of the best stored solution: Replay, or during replay its position with Step and Stop (feature 407).
    @ViewBuilder private var replaySection: some View {
        if mirror.replaying {
            Text(Self.replayPositionText(mirror)).font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            row {
                Button("Step") { presenter.stepReplay(port: port) }
                    .accessibilityLabel("Play the next action of the replay")
                    .accessibilityIdentifier(port.identifier("replay-step"))
                    .accessibilityValue("Action \(mirror.replayPosition) of \(mirror.replayLength)")
                Button("Stop") { presenter.stopReplay(port: port) }
                    .accessibilityLabel("Stop the replay")
                    .accessibilityIdentifier(port.identifier("replay-stop"))
                    .accessibilityValue("\(mirror.replayLength) actions")
            }
        } else if mirror.replayAvailable {
            Button("Replay best solution") { presenter.startReplay(port: port) }
                .accessibilityLabel("Replay your best solution of this level")
                .accessibilityIdentifier(port.identifier("replay"))
                .accessibilityValue("Level \(mirror.levelNumber)")
        }
    }

    /// The replay position line: "Replay: action k of n" (feature 407).
    static func replayPositionText(_ mirror: EchoCartographerMirror) -> String {
        "Replay: action \(mirror.replayPosition) of \(mirror.replayLength)"
    }

    /// The mode's name: campaign, daily, practice or replay.
    static func modeName(_ mode: EchoCartographerMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        case .replay: "replay"
        }
    }

    /// The accessibility values in words of the controls that act on the play (feature 406, after feature 386's
    /// convergence lesson): every native control carries a value.
    struct Values: Equatable {
        /// Undo and redo: the energy left of the level's energy.
        let energy: String
        /// Next level: the next open level, or that none is open.
        let nextLevel: String
        /// Retry: the level and the mode.
        let retry: String
        /// Play level: the picked level.
        let playLevel: String
    }

    /// The button values of `mirror` (see ``Values``).
    static func values(_ mirror: EchoCartographerMirror) -> Values {
        let next: String = mirror.levelNumber < mirror.frontier ? "level \(mirror.levelNumber + 1)"
            : "no further level open"
        return Values(energy: "\(mirror.energy) of \(mirror.budget) energy left", nextLevel: next,
                      retry: "level \(mirror.levelNumber), " + modeName(mirror.mode),
                      playLevel: "level \(mirror.pickedLevel)")
    }

    /// The Reset view value: "authored view" or "orbited view".
    static func viewValue(_ authored: Bool) -> String { authored ? "authored view" : "orbited view" }

    /// A mode button's value: "selected" or "not selected".
    static func selectedValue(_ selected: Bool) -> String { selected ? "selected" : "not selected" }

    /// The cursor as the values of a `cell.*` control.
    private var cursorValues: [Double] { [Double(mirror.column), Double(mirror.row)] }

    /// Sends `control` through the presenter.
    private func send(_ control: String, _ values: [Double] = []) {
        sender(control, values)
    }
}
#endif
