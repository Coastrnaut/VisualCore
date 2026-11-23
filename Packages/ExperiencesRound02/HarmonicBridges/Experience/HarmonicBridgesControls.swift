// HarmonicBridgesControls — feature 413 (R02-G12-03) T-R02G1203-006 (FR-R02G1203-005; clarification Q5). The minimal
// control panel: labelled steppers for the chosen string and peg (presentation state only; a level opens with string 0
// chosen at its current peg, both clamped), tune (the chosen string to the chosen peg) and test (kernel actions
// through the action port), undo, redo and next level, each with an accessibility label, value and identifier; the
// header shows the actions left of the budget, the stage, the failure in words and a refused action in words. Feature
// 414 (R02-G12-04) adds "Reset view" (the authored camera) and sends through the presenter, which shows and logs
// refusals; full accessibility comes in R02-G12-06. Feature 415 (R02-G12-05) T-R02G1205-005: the tutorial
// instruction with Dismiss, Hint (each press reveals the next level), the failure explanation with Undo and Retry, the
// goal with the level's band and best stars, Campaign / Daily / Practice and a picker of the open levels with Play
// level; all as wrapping text in the panel, never over the bridges. "Next level" stays; before a win it is refused in words.
// Feature 416 (R02-G12-06) T-R02G1206-005 (FR-R02G1206-001, 005, 006; clarification Q5): the summary element
// ("Crossing", identifier `summary`), the adjustable string and peg (steppers with `accessibilityAdjustableAction`;
// the string's value is the string as the level words it, with its current peg and lock), a value in words on every
// control (``Values``: Tune the chosen string and peg, Test the steps reached, Undo and Redo the actions made, Next
// level the next open level, Retry the level and mode, Play level the picked level; Reset view "authored view" or
// "orbited view", Dismiss the instruction, Campaign / Daily / Practice "selected" or "not selected", Hint the level
// shown, Sound "on" or "off"), refusals in words, the Sound toggle (off by default, identifier `sound`), rows that
// become columns at accessibility text sizes, wrapping text and a 520-point readable width (iPad).
// Feature 417 (R02-G12-07) T-R02G1207-005 (clarifications Q2, Q4, Q5): "Replay best solution" (identifier `replay`,
// value the level) for a level with a verified stored solution, and during replay its position ("Replay: action k of
// n", identifier `replay-position`) with Step (identifier `replay-step`, value "Action k of n") and Stop (identifier
// `replay-stop`, value the trace's actions), each with a label; the Sound toggle saves the choice through
// `settings.sound`; the mode's name includes "replay".
#if os(iOS)
import HarmonicBridgesCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Harmonic Bridges.
struct HarmonicBridgesControls: View {
    /// The action port (its identifiers name the controls).
    let port: ExperienceActionPort
    /// What the panel shows and chooses.
    let mirror: HarmonicBridgesMirror
    /// The presenter (feature 415): hints, tutorial, retry, undo and the daily level; sound and summary (feature 416).
    let presenter: HarmonicBridgesPresenter
    /// Returns the camera to the authored view.
    let resetView: () -> Void
    /// Sends a control with its values through the presenter (which shows and logs a refusal).
    let sender: (String, [Double]) -> Void
    /// The text size: rows become columns at accessibility sizes (feature 416).
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Whether the app's scene is active: the sound plays only while it is (feature 416).
    @Environment(\.scenePhase) private var scenePhase

    /// The widest the panel's content grows, padding included (clarification Q5 of feature 416).
    static let readableWidth: CGFloat = 520

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teaching
                choiceRow
                actionRow
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

    /// A row of controls that becomes a column at accessibility text sizes (feature 416).
    @ViewBuilder private func row(@ViewBuilder _ content: () -> some View) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) { content() }
        } else {
            HStack(spacing: 12) { content() }
        }
    }

    /// The Sound toggle (feature 416; off by default; saved through `settings.sound` since feature 417).
    @ViewBuilder private var soundToggle: some View {
        Toggle("Sound", isOn: Binding(get: { mirror.soundOn }, set: { presenter.saveSound(on: $0, port: port) }))
            .accessibilityLabel("Sound of the strings")
            .accessibilityValue(Self.soundValue(mirror.soundOn))
            .accessibilityIdentifier(port.identifier("sound"))
    }

    /// The level, actions, stage (the summary element), failure and refusal lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · \(mirror.actionsLeft) of \(mirror.budget) actions left")
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(port.identifier("actions"))
        Text(mirror.status).font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(port.identifier("status"))
        Text(mirror.summary).font(.footnote)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Crossing")
            .accessibilityValue(mirror.summary)
            .accessibilityIdentifier(port.identifier("summary"))
        if let failure = mirror.failureText {
            Text(failure).font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("failure"))
        }
        Text(mirror.measureLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
        Text(mirror.targetLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
        if let message = mirror.message {
            Text(message).font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("message"))
        }
    }

    /// The adjustable string and peg (feature 416: swipe up or down steps them; the summary follows).
    @ViewBuilder private var choiceRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Stepper(mirror.stringLabel,
                    onIncrement: { stepString(1) },
                    onDecrement: { stepString(-1) })
                .accessibilityLabel("Chosen string")
                .accessibilityValue(mirror.stringWords)
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: stepString(1)
                    case .decrement: stepString(-1)
                    @unknown default: break
                    }
                }
                .accessibilityIdentifier(port.identifier("string"))
            Stepper(mirror.pegLabel,
                    onIncrement: { stepPeg(1) },
                    onDecrement: { stepPeg(-1) })
                .accessibilityLabel("Peg to tune the chosen string to")
                .accessibilityValue(mirror.pegWords)
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: stepPeg(1)
                    case .decrement: stepPeg(-1)
                    @unknown default: break
                    }
                }
                .accessibilityIdentifier(port.identifier("peg"))
        }
    }

    /// Tune the chosen string and test the crossing.
    @ViewBuilder private var actionRow: some View {
        row {
            Button("Tune") { send("string.tune", choiceValues) }
                .accessibilityLabel("Tune the chosen string to the chosen peg")
                .accessibilityValue(Self.values(mirror).tune)
                .accessibilityIdentifier(port.identifier("tune"))
            Button("Test") { send("crossing.test") }
                .accessibilityLabel("Test the crossing in every step")
                .accessibilityValue(Self.values(mirror).test)
                .accessibilityIdentifier(port.identifier("test"))
        }
    }

    /// Undo, redo, next level and reset view.
    @ViewBuilder private var playRow: some View {
        row {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last action")
                .accessibilityValue(Self.values(mirror).actions)
                .accessibilityIdentifier(port.identifier("undo"))
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the action")
                .accessibilityValue(Self.values(mirror).actions)
                .accessibilityIdentifier(port.identifier("redo"))
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
                .accessibilityValue(Self.values(mirror).nextLevel)
                .accessibilityIdentifier(port.identifier("next-level"))
            Button("Reset view") { resetView() }
                .accessibilityLabel("Return the camera to the authored view")
                .accessibilityValue(Self.viewValue(presenter.gestures.orbit == .authored))
                .accessibilityIdentifier(port.identifier("reset-view"))
        }
    }

    /// The tutorial instruction, the hint, the goal and the failure's Undo and Retry (feature 415); the failure
    /// explanation itself is the header's failure line.
    @ViewBuilder private var teaching: some View {
        if let instruction = mirror.instruction {
            VStack(alignment: .leading, spacing: 4) {
                Text(instruction).font(.callout).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(port.identifier("instruction"))
                Button("Dismiss") { presenter.dismissTutorial(port: port) }
                    .accessibilityLabel("Dismiss the tutorial")
                    .accessibilityValue(instruction)
                    .accessibilityIdentifier(port.identifier("dismiss-tutorial"))
            }
        }
        row {
            Button("Hint") { presenter.showHint() }
                .accessibilityLabel("Show a hint")
                .accessibilityValue(Self.hintValue(mirror.hintLevel))
                .accessibilityIdentifier(port.identifier("hint"))
            Text(mirror.goalLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("goal"))
        }
        if let hint = mirror.hintText {
            Text(hint).font(.callout).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("hint-text"))
        }
        if mirror.failureText != nil {
            row {
                Button("Undo") { presenter.undoAction(port: port) }
                    .accessibilityLabel("Undo the last action")
                    .accessibilityValue(Self.values(mirror).actions)
                    .accessibilityIdentifier(port.identifier("failure-undo"))
                Button("Retry") { presenter.retry(port: port) }
                    .accessibilityLabel("Start the level again")
                    .accessibilityValue(Self.values(mirror).retry)
                    .accessibilityIdentifier(port.identifier("retry"))
            }
        }
    }

    /// The mode buttons and the picker of open levels with their bands and stars (feature 415).
    @ViewBuilder private var progressRows: some View {
        row {
            Button("Campaign") { send("mode.campaign") }
                .accessibilityLabel("Play the campaign")
                .accessibilityValue(Self.selectedValue(Self.modeName(mirror.mode) == "campaign"))
                .accessibilityIdentifier(port.identifier("campaign"))
            Button("Daily") { presenter.playDaily(port: port) }
                .accessibilityLabel("Play today's daily level")
                .accessibilityValue(Self.selectedValue(Self.modeName(mirror.mode) == "daily"))
                .accessibilityIdentifier(port.identifier("daily"))
            Button("Practice") { send("mode.practice") }
                .accessibilityLabel("Practise this level with more actions")
                .accessibilityValue(Self.selectedValue(Self.modeName(mirror.mode) == "practice"))
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
                .accessibilityValue(Self.values(mirror).playLevel)
                .accessibilityIdentifier(port.identifier("play-level"))
        }
    }

    /// "Level n, band b" with its stars when won.
    private func levelLabel(_ level: Int) -> String {
        let band: Int = HarmonicBridgesProgress.band(of: level)
        if let stars = mirror.stars[level] { return "Level \(level), band \(band), \(stars) stars" }
        return "Level \(level), band \(band)"
    }

    /// Replay of the best stored solution: Replay, or during replay its position with Step and Stop (feature 417).
    @ViewBuilder private var replaySection: some View {
        if mirror.replaying {
            Text(Self.replayPositionText(mirror)).font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("replay-position"))
            row {
                Button("Step") { presenter.stepReplay(port: port) }
                    .accessibilityLabel("Play the next action of the replay")
                    .accessibilityValue(Self.replayStepValue(mirror))
                    .accessibilityIdentifier(port.identifier("replay-step"))
                Button("Stop") { presenter.stopReplay(port: port) }
                    .accessibilityLabel("Stop the replay")
                    .accessibilityValue(Self.replayStopValue(mirror))
                    .accessibilityIdentifier(port.identifier("replay-stop"))
            }
        } else if mirror.replayAvailable {
            Button("Replay best solution") { presenter.startReplay(port: port) }
                .accessibilityLabel("Replay your best solution of this level")
                .accessibilityValue("Level \(mirror.levelNumber)")
                .accessibilityIdentifier(port.identifier("replay"))
        }
    }

    /// The replay position line: "Replay: action k of n" (feature 417).
    static func replayPositionText(_ mirror: HarmonicBridgesMirror) -> String {
        "Replay: action \(mirror.replayPosition) of \(mirror.replayLength)"
    }

    /// Step's value: "Action k of n" (feature 417).
    static func replayStepValue(_ mirror: HarmonicBridgesMirror) -> String {
        "Action \(mirror.replayPosition) of \(mirror.replayLength)"
    }

    /// Stop's value: the trace's actions, "n actions" ("1 action" for one) (feature 417).
    static func replayStopValue(_ mirror: HarmonicBridgesMirror) -> String {
        mirror.replayLength == 1 ? "1 action" : "\(mirror.replayLength) actions"
    }

    /// The mode's name: campaign, daily, practice or replay.
    static func modeName(_ mode: HarmonicBridgesMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        case .replay: "replay"
        }
    }

    /// The accessibility values in words of the controls that act on the play (feature 416, after feature 386's
    /// convergence lesson): every native control carries a value.
    struct Values: Equatable {
        /// Tune: the chosen string and peg (`HarmonicBridgesMirror.choiceLabel`).
        let tune: String
        /// Test: the steps reached (`HarmonicBridgesMirror.reachedLabel`).
        let test: String
        /// Undo and redo: the actions made of the budget, "k actions made of B" ("1 action made of B" for one).
        let actions: String
        /// Next level: the next open level, or that none is open.
        let nextLevel: String
        /// Retry: the level and the mode.
        let retry: String
        /// Play level: the picked level.
        let playLevel: String
    }

    /// The button values of `mirror` (see ``Values``).
    static func values(_ mirror: HarmonicBridgesMirror) -> Values {
        let made: Int = max(mirror.budget - mirror.actionsLeft, 0)
        let actions: String = (made == 1 ? "1 action made" : "\(made) actions made") + " of \(mirror.budget)"
        let next: String = mirror.levelNumber < mirror.frontier ? "level \(mirror.levelNumber + 1)"
            : "no further level open"
        return Values(tune: mirror.choiceLabel, test: mirror.reachedLabel, actions: actions, nextLevel: next,
                      retry: "level \(mirror.levelNumber), " + modeName(mirror.mode),
                      playLevel: "level \(mirror.pickedLevel)")
    }

    /// The Reset view value: "authored view" or "orbited view".
    static func viewValue(_ authored: Bool) -> String { authored ? "authored view" : "orbited view" }

    /// A mode button's value: "selected" or "not selected".
    static func selectedValue(_ selected: Bool) -> String { selected ? "selected" : "not selected" }

    /// The Sound toggle's value: "on" or "off".
    static func soundValue(_ on: Bool) -> String { on ? "on" : "off" }

    /// The Hint button's value: "none shown" or "level h of 3".
    static func hintValue(_ level: Int) -> String { level == 0 ? "none shown" : "level \(level) of 3" }

    /// Steps the chosen string by `delta` and refreshes the summary.
    private func stepString(_ delta: Int) {
        mirror.stepString(delta)
        presenter.refreshSummary()
    }

    /// Steps the chosen peg by `delta` and refreshes the summary.
    private func stepPeg(_ delta: Int) {
        mirror.stepPeg(delta)
        presenter.refreshSummary()
    }

    /// The choice as the values of `string.tune`.
    private var choiceValues: [Double] { [Double(mirror.string), Double(mirror.peg)] }

    /// Sends `control` through the presenter.
    private func send(_ control: String, _ values: [Double] = []) {
        sender(control, values)
    }
}
#endif
