// StarlitCartoucheControls — feature 453 (R02-G16-03) T-R02G1603-006 (FR-R02G1603-005; clarification Q5). The minimal
// control panel: labelled buttons for the chosen destination (destination − and +, skipping the ship's star) and wait
// (wait − and +, 0 … 8), both `route.choose [star, wait]` (presentation state of the adapter; a level opens, and every
// leg ends, with the other end of the lowest-index corridor from the ship's star and wait 0), flying the chosen leg
// (`route.fly [star, wait]`), undo, redo and next level (kernel actions through the action port), each with an
// accessibility label, value and identifier; the header shows the actions left of the budget, the status (stage, or the
// failure in words), the progress description, the failure in words and a refused action in words. Tapping stars on
// the canvas, the time slider and the route preview arrive in feature 454 (R02-G16-04), which adds the pending leg of
// a ship drag and "Reset view" to the panel. Feature 455 (R02-G16-05) T-R02G1605-005: the tutorial instruction with
// Dismiss, Hint (each press reveals the next level), the failure explanation with Undo and Retry, the goal with the
// level's band and best stars, Campaign / Daily / Practice and a picker of the open levels with Play level; all as
// wrapping text in the panel, never over the chart. "Next level" stays; before a win it is refused in words.
// Feature 456 (R02-G16-06) T-R02G1606-005 (FR-R02G1606-001, 005, 006; clarification Q5): the summary element ("Chart",
// identifier `summary`), the adjustable destination and wait (`accessibilityAdjustableAction`, sending `route.choose`
// like the buttons; their value is the chosen leg as the level words it: the star, the corridor or that none joins
// them, and the wait), a value in words on every control (Fly the chosen leg, Undo and Redo the actions made, Next
// level the next open level, Retry the level and mode, Play level the picked level, Reset view "authored" or
// "orbited", Dismiss the instruction, Campaign / Daily / Practice "selected" or "not selected", Hint the level shown,
// Sound "on" or "off"), refusals in the feedback plan's words, the Sound toggle (off by default, identifier `sound`),
// rows that become columns at accessibility text sizes, wrapping text and a 520-point readable width (iPad).
// Feature 457 (R02-G16-07) T-R02G1607-005 (clarifications Q2, Q4, Q5): "Replay best solution" (identifier `replay`,
// value the level) for a level with a verified stored solution, and during replay its position ("Replay: leg k of n",
// identifier `replay-position`) with Step (identifier `replay-step`, value "Leg k of n") and Stop (identifier
// `replay-stop`, value the trace's legs), each with a label; the Sound toggle saves the choice through
// `settings.sound`; the mode's name includes "replay".
#if os(iOS)
import StarlitCartoucheCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Starlit Cartouche.
struct StarlitCartoucheControls: View {
    /// Where actions are sent.
    let port: ExperienceActionPort
    /// What the panel shows.
    let mirror: StarlitCartoucheMirror
    /// The presenter (feature 455): hints, tutorial, retry, undo and the daily level.
    let presenter: StarlitCartouchePresenter
    /// Returns the camera to the authored view (feature 454; presentation only).
    var resetView: () -> Void = {}
    /// Sends a control and shows a refusal in words (the presenter's `send`, feature 454); nil sends through the port
    /// directly.
    var sender: ((String, [Double]) -> Void)? = nil
    /// The text size: rows become columns at accessibility sizes (feature 456).
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Whether the app's scene is active: the sound plays only while it is (feature 456).
    @Environment(\.scenePhase) private var scenePhase

    /// The widest the panel's content grows, padding included (clarification Q5 of feature 456).
    static let readableWidth: CGFloat = 520

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teaching
                destinationRow
                waitRow
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

    /// A row of controls that becomes a column at accessibility text sizes (feature 456).
    @ViewBuilder private func row(@ViewBuilder _ content: () -> some View) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) { content() }
        } else {
            HStack(spacing: 12) { content() }
        }
    }

    /// The Sound toggle (feature 456; off by default; since feature 457 saved through `settings.sound`).
    @ViewBuilder private var soundToggle: some View {
        Toggle("Sound", isOn: Binding(get: { mirror.soundOn }, set: { presenter.saveSound(on: $0, port: port) }))
            .accessibilityLabel("Sound of the chart")
            .accessibilityValue(mirror.soundOn ? "on" : "off")
            .accessibilityIdentifier(port.identifier("sound"))
    }

    /// The level, actions, status, failure and refusal lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · \(mirror.actionsLeft) of \(mirror.budget) actions left")
            .font(.headline)
            .accessibilityIdentifier(port.identifier("actions"))
        Text(mirror.status).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(port.identifier("status"))
        if let failure = mirror.failureText {
            Text(failure).font(.footnote).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("failure"))
        }
        Text(mirror.measureLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(port.identifier("progress"))
        Text(mirror.summary).font(.footnote)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Chart")
            .accessibilityValue(mirror.summary)
            .accessibilityIdentifier(port.identifier("summary"))
        Text(mirror.targetLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
        if let message = mirror.message {
            Text(message).font(.footnote).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("message"))
        }
        if let pending = mirror.pending {
            Text(pending).font(.footnote).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("pending"))
        }
    }

    /// The tutorial instruction, the hint, the goal and the failure's explanation with Undo and Retry (feature 455).
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
                .accessibilityValue(mirror.hintLevel == 0 ? "none shown" : "level \(mirror.hintLevel) of 3")
                .accessibilityIdentifier(port.identifier("hint"))
            Text(mirror.goalLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("goal"))
        }
        if let hint = mirror.hintText {
            Text(hint).font(.callout).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("hint-text"))
        }
        if let explanation = mirror.explanation {
            Text(explanation).font(.callout).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("explanation"))
            row {
                Button("Undo") { presenter.undoAction(port: port) }
                    .accessibilityLabel("Undo the last leg")
                    .accessibilityValue(actionsMade)
                    .accessibilityIdentifier(port.identifier("failure-undo"))
                Button("Retry") { presenter.retry(port: port) }
                    .accessibilityLabel("Start the level again")
                    .accessibilityValue("level \(mirror.levelNumber), " + Self.modeName(mirror.mode))
                    .accessibilityIdentifier(port.identifier("retry"))
            }
        }
    }

    /// The mode buttons and the picker of open levels with their bands and stars (feature 455).
    @ViewBuilder private var progressRows: some View {
        row {
            Button("Campaign") { send("mode.campaign") }
                .accessibilityLabel("Play the campaign")
                .accessibilityValue(Self.modeName(mirror.mode) == "campaign" ? "selected" : "not selected")
                .accessibilityIdentifier(port.identifier("campaign"))
            Button("Daily") { presenter.playDaily(port: port) }
                .accessibilityLabel("Play today's daily level")
                .accessibilityValue(Self.modeName(mirror.mode) == "daily" ? "selected" : "not selected")
                .accessibilityIdentifier(port.identifier("daily"))
            Button("Practice") { send("mode.practice") }
                .accessibilityLabel("Practise this level with more actions")
                .accessibilityValue(Self.modeName(mirror.mode) == "practice" ? "selected" : "not selected")
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
                .accessibilityValue("level \(mirror.pickedLevel)")
                .accessibilityIdentifier(port.identifier("play-level"))
        }
    }

    /// "Level n, band b" with its stars when won.
    private func levelLabel(_ level: Int) -> String {
        let band: Int = StarlitCartoucheProgress.band(of: level)
        if let stars = mirror.stars[level] { return "Level \(level), band \(band), \(stars) stars" }
        return "Level \(level), band \(band)"
    }

    /// Replay of the best stored solution: Replay, or during replay its position with Step and Stop (feature 457).
    @ViewBuilder private var replaySection: some View {
        if mirror.replaying {
            Text(Self.replayPositionText(mirror)).font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("replay-position"))
            row {
                Button("Step") { presenter.stepReplay(port: port) }
                    .accessibilityLabel("Fly the next leg of the replay")
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

    /// The replay position line: "Replay: leg k of n" (feature 457).
    static func replayPositionText(_ mirror: StarlitCartoucheMirror) -> String {
        "Replay: leg \(mirror.replayPosition) of \(mirror.replayLength)"
    }

    /// Step's value: "Leg k of n", the legs played of the trace (feature 457).
    static func replayStepValue(_ mirror: StarlitCartoucheMirror) -> String {
        "Leg \(mirror.replayPosition) of \(mirror.replayLength)"
    }

    /// Stop's value: the trace's legs (feature 457).
    static func replayStopValue(_ mirror: StarlitCartoucheMirror) -> String {
        mirror.replayLength == 1 ? "1 leg" : "\(mirror.replayLength) legs"
    }

    /// The mode's name: campaign, daily, practice or replay (feature 457).
    static func modeName(_ mode: StarlitCartoucheMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        case .replay: "replay"
        }
    }

    /// Choose the previous or next destination star.
    @ViewBuilder private var destinationRow: some View {
        row {
            Button("Star −") { send("route.choose", [Double(mirror.nextDestination(-1)), Double(mirror.wait)]) }
                .accessibilityLabel("Choose the previous destination star")
                .accessibilityValue(mirror.legLabel)
                .accessibilityIdentifier(port.identifier("star-minus"))
            Text("star \(mirror.destination)")
                .accessibilityLabel("Chosen destination")
                .accessibilityValue(mirror.legLabel)
                .accessibilityAdjustableAction { direction in adjustDestination(direction) }
                .accessibilityIdentifier(port.identifier("star"))
            Button("Star +") { send("route.choose", [Double(mirror.nextDestination(1)), Double(mirror.wait)]) }
                .accessibilityLabel("Choose the next destination star")
                .accessibilityValue(mirror.legLabel)
                .accessibilityIdentifier(port.identifier("star-plus"))
        }
        Text(mirror.legLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(port.identifier("leg-detail"))
    }

    /// Choose a shorter or longer wait before launching.
    @ViewBuilder private var waitRow: some View {
        row {
            Button("Wait −") { choose(wait: mirror.wait - 1) }
                .accessibilityLabel("Wait one beat less before launching")
                .accessibilityValue(mirror.legLabel)
                .accessibilityIdentifier(port.identifier("wait-minus"))
            Text("wait \(mirror.wait)")
                .accessibilityLabel("Chosen wait")
                .accessibilityValue(mirror.legLabel)
                .accessibilityAdjustableAction { direction in adjustWait(direction) }
                .accessibilityIdentifier(port.identifier("wait"))
            Button("Wait +") { choose(wait: mirror.wait + 1) }
                .accessibilityLabel("Wait one beat more before launching")
                .accessibilityValue(mirror.legLabel)
                .accessibilityIdentifier(port.identifier("wait-plus"))
            Button("Fly") { send("route.fly", [Double(mirror.destination), Double(mirror.wait)]) }
                .accessibilityLabel("Fly the chosen leg")
                .accessibilityValue(mirror.legLabel)
                .accessibilityIdentifier(port.identifier("fly"))
        }
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        row {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last leg")
                .accessibilityValue(actionsMade)
                .accessibilityIdentifier(port.identifier("undo"))
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the leg")
                .accessibilityValue(actionsMade)
                .accessibilityIdentifier(port.identifier("redo"))
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
                .accessibilityValue(mirror.levelNumber < mirror.frontier ? "level \(mirror.levelNumber + 1)"
                                    : "no further level open")
                .accessibilityIdentifier(port.identifier("next-level"))
        }
        Button("Reset view") { resetView() }
            .accessibilityLabel("Return the camera to the authored view")
            .accessibilityValue(presenter.gestures.orbit == .authored ? "authored" : "orbited")
            .accessibilityIdentifier(port.identifier("reset-view"))
    }

    /// The destination's adjustable action (feature 456): increment and decrement choose the next and previous
    /// destination like Star + and Star − (`route.choose`).
    private func adjustDestination(_ direction: AccessibilityAdjustmentDirection) {
        switch direction {
        case .increment: send("route.choose", [Double(mirror.nextDestination(1)), Double(mirror.wait)])
        case .decrement: send("route.choose", [Double(mirror.nextDestination(-1)), Double(mirror.wait)])
        @unknown default: break
        }
    }

    /// The wait's adjustable action (feature 456): increment and decrement choose one beat more or less like Wait +
    /// and Wait − (`route.choose`, clamped to 0 … 8).
    private func adjustWait(_ direction: AccessibilityAdjustmentDirection) {
        switch direction {
        case .increment: choose(wait: mirror.wait + 1)
        case .decrement: choose(wait: mirror.wait - 1)
        @unknown default: break
        }
    }

    /// Undo and Redo's value (feature 456): the actions made of the budget, "k actions made of B".
    private var actionsMade: String {
        let made: Int = max(mirror.budget - mirror.actionsLeft, 0)
        return (made == 1 ? "1 action made" : "\(made) actions made") + " of \(mirror.budget)"
    }

    /// Chooses wait `wait` (clamped to 0 … 8) with the current destination.
    private func choose(wait: Int) {
        send("route.choose", [Double(mirror.destination), Double(mirror.clampedWait(wait))])
    }

    /// Sends `control` and shows a refusal in words.
    private func send(_ control: String, _ values: [Double] = []) {
        if let sender {
            sender(control, values)
            return
        }
        let result = port.send(control, values)
        mirror.message = result.isAccepted ? nil : StarlitCartoucheMirror.refusalText(code: result.code)
    }
}
#endif
