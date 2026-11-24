// MoonlitMechanismControls — feature 433 (R02-G14-03) T-R02G1403-006 (FR-R02G1403-005; clarification Q5). The minimal
// control panel: labelled buttons for the handle (turn − and +), the chosen gear (gear − and +; presentation state
// only, a level opens with gear 1 chosen, clamped to the level's gears), re-seating the chosen gear (re-seat − and +,
// `gear.reseat [gear, ±1]`), the lamp (lamp − and +), the shown key frame (key frame − and +, `frame.show [k]`), run,
// undo, redo and next level (kernel actions through the action port), each with an accessibility label, value and
// identifier; the header shows the actions left of the budget, the status (stage, or the failure in words), the
// progress description, the failure in words and a refused action in words. Since feature 434 (R02-G14-04) the panel
// shows the pending turn or lamp steps of a canvas drag and has "Reset view". Feature 435 (R02-G14-05) T-R02G1405-005:
// the tutorial instruction with Dismiss, Hint (each press reveals the next level), the failure explanation with Undo and
// Retry, the goal with the level's band and best stars, Campaign / Daily / Practice and a picker of the open levels
// with Play level; all as wrapping text in the panel, never over the clockwork. "Next level" stays; before a win it is
// refused in words. Feature 436 (R02-G14-06) T-R02G1406-005 (FR-R02G1406-001, 005, 006; clarification Q5): the summary
// element ("Clockwork", identifier `summary`), the adjustable gear and key frame (`accessibilityAdjustableAction`; the
// gear's value is the gear as the level words it with its teeth, phase and mesh, the key frame's its coverage), a value
// in words on every control (Turn and Run the progress, Re-seat the chosen gear, Lamp the height, Undo and Redo the
// actions made, Next level the next open level, Retry the level and mode, Play level the picked level, Reset view
// "authored" or "orbited", Dismiss the instruction, Campaign / Daily / Practice "selected" or "not selected", Hint the
// level shown, Sound "on" or "off"), refusals in the feedback plan's words, the Sound toggle (off by default, identifier
// `sound`), rows that become columns at accessibility text sizes, wrapping text and a 520-point readable width (iPad).
#if os(iOS)
import MoonlitMechanismCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Moonlit Mechanism.
struct MoonlitMechanismControls: View {
    /// Where actions are sent.
    let port: ExperienceActionPort
    /// What the panel shows and chooses.
    let mirror: MoonlitMechanismMirror
    /// The presenter (feature 435): hints, tutorial, retry, undo and the daily level.
    let presenter: MoonlitMechanismPresenter
    /// Returns the camera to the authored view (feature 434; presentation only).
    var resetView: () -> Void = {}
    /// Sends a control and shows a refusal in words (the presenter's `send`, feature 434); nil sends through the port
    /// directly.
    var sender: ((String, [Double]) -> Void)? = nil
    /// The text size: rows become columns at accessibility sizes (feature 436).
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Whether the app's scene is active: the sound plays only while it is (feature 436).
    @Environment(\.scenePhase) private var scenePhase

    /// The widest the panel's content grows, padding included (clarification Q5 of feature 436).
    static let readableWidth: CGFloat = 520

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teaching
                progressRows
                turnRow
                gearRows
                lampRow
                frameRow
                playRow
                soundToggle
            }
            .padding()
            .frame(maxWidth: Self.readableWidth, alignment: .leading)
        }
        .onAppear { presenter.controlsAppeared() }
        .onDisappear { presenter.controlsDisappeared() }
        .onChange(of: scenePhase) { _, phase in presenter.sceneActive(phase == .active) }
    }

    /// A row of controls that becomes a column at accessibility text sizes (feature 436).
    @ViewBuilder private func row(@ViewBuilder _ content: () -> some View) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) { content() }
        } else {
            HStack(spacing: 12) { content() }
        }
    }

    /// The Sound toggle (feature 436; off by default; presentation only).
    @ViewBuilder private var soundToggle: some View {
        Toggle("Sound", isOn: Binding(get: { mirror.soundOn }, set: { presenter.setSound(on: $0) }))
            .accessibilityLabel("Sound of the clockwork")
            .accessibilityValue(mirror.soundOn ? "on" : "off")
            .accessibilityIdentifier(port.identifier("sound"))
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
        Text(mirror.measureLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(port.identifier("progress"))
        Text(mirror.summary).font(.footnote)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Clockwork")
            .accessibilityValue(mirror.summary)
            .accessibilityIdentifier(port.identifier("summary"))
        Text(mirror.targetLabel).font(.footnote)
        if let pending = mirror.pending {
            Text(pending).font(.footnote)
                .accessibilityIdentifier(port.identifier("pending"))
        }
        if let message = mirror.message {
            Text(message).font(.footnote)
                .accessibilityIdentifier(port.identifier("message"))
        }
    }

    /// The tutorial instruction, the hint, the goal and the failure's explanation with Undo and Retry (feature 435).
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
                    .accessibilityLabel("Undo the last action")
                    .accessibilityValue(actionsMade)
                    .accessibilityIdentifier(port.identifier("failure-undo"))
                Button("Retry") { presenter.retry(port: port) }
                    .accessibilityLabel("Start the level again")
                    .accessibilityValue("level \(mirror.levelNumber), " + Self.modeName(mirror.mode))
                    .accessibilityIdentifier(port.identifier("retry"))
            }
        }
    }

    /// The mode buttons and the picker of open levels with their bands and stars (feature 435).
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
        let band: Int = MoonlitMechanismProgress.band(of: level)
        if let stars = mirror.stars[level] { return "Level \(level), band \(band), \(stars) stars" }
        return "Level \(level), band \(band)"
    }

    /// The mode's name: campaign, daily or practice.
    static func modeName(_ mode: MoonlitMechanismMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        }
    }

    /// Turn the handle back or forward one tooth.
    @ViewBuilder private var turnRow: some View {
        row {
            Button("Turn −") { send("handle.turn", [-1]) }
                .accessibilityLabel("Turn the handle back one tooth")
                .accessibilityValue(mirror.measureLabel)
                .accessibilityIdentifier(port.identifier("turn-minus"))
            Button("Turn +") { send("handle.turn", [1]) }
                .accessibilityLabel("Turn the handle forward one tooth")
                .accessibilityValue(mirror.measureLabel)
                .accessibilityIdentifier(port.identifier("turn-plus"))
        }
    }

    /// Choose a gear and re-seat it.
    @ViewBuilder private var gearRows: some View {
        row {
            Button("Gear −") { presenter.chooseGear(mirror.gear - 1) }
                .accessibilityLabel("Choose the previous gear")
                .accessibilityValue(mirror.gearDetail)
                .accessibilityIdentifier(port.identifier("gear-minus"))
            Text(mirror.gearLabel)
                .accessibilityLabel("Chosen gear")
                .accessibilityValue(mirror.gearDetail)
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: presenter.chooseGear(mirror.gear + 1)
                    case .decrement: presenter.chooseGear(mirror.gear - 1)
                    @unknown default: break
                    }
                }
                .accessibilityIdentifier(port.identifier("gear"))
            Button("Gear +") { presenter.chooseGear(mirror.gear + 1) }
                .accessibilityLabel("Choose the next gear")
                .accessibilityValue(mirror.gearDetail)
                .accessibilityIdentifier(port.identifier("gear-plus"))
        }
        Text(mirror.gearDetail).font(.footnote)
            .accessibilityIdentifier(port.identifier("gear-detail"))
        row {
            Button("Re-seat −") { send("gear.reseat", [Double(mirror.gear), -1]) }
                .accessibilityLabel("Re-seat the chosen gear back one tooth")
                .accessibilityValue(mirror.gearDetail)
                .accessibilityIdentifier(port.identifier("reseat-minus"))
            Button("Re-seat +") { send("gear.reseat", [Double(mirror.gear), 1]) }
                .accessibilityLabel("Re-seat the chosen gear forward one tooth")
                .accessibilityValue(mirror.gearDetail)
                .accessibilityIdentifier(port.identifier("reseat-plus"))
        }
    }

    /// Lower or raise the lamp.
    @ViewBuilder private var lampRow: some View {
        row {
            Button("Lamp −") { send("lamp.step", [-1]) }
                .accessibilityLabel("Lower the lamp one height")
                .accessibilityValue(mirror.lampLabel)
                .accessibilityIdentifier(port.identifier("lamp-minus"))
            Text(mirror.lampLabel)
                .accessibilityIdentifier(port.identifier("lamp"))
            Button("Lamp +") { send("lamp.step", [1]) }
                .accessibilityLabel("Raise the lamp one height")
                .accessibilityValue(mirror.lampLabel)
                .accessibilityIdentifier(port.identifier("lamp-plus"))
        }
    }

    /// Show the previous or next key frame (presentation only).
    @ViewBuilder private var frameRow: some View {
        row {
            Button("Key frame −") { send("frame.show", [Double(mirror.clampedFrame(mirror.shownFrame - 1))]) }
                .accessibilityLabel("Show the previous key frame")
                .accessibilityValue(mirror.frameLabel)
                .accessibilityIdentifier(port.identifier("frame-minus"))
            Button("Key frame +") { send("frame.show", [Double(mirror.clampedFrame(mirror.shownFrame + 1))]) }
                .accessibilityLabel("Show the next key frame")
                .accessibilityValue(mirror.frameLabel)
                .accessibilityIdentifier(port.identifier("frame-plus"))
        }
        Text(mirror.frameLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Shown key frame")
            .accessibilityValue(mirror.frameLabel)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: send("frame.show", [Double(mirror.clampedFrame(mirror.shownFrame + 1))])
                case .decrement: send("frame.show", [Double(mirror.clampedFrame(mirror.shownFrame - 1))])
                @unknown default: break
                }
            }
            .accessibilityIdentifier(port.identifier("frame"))
    }

    /// Run, undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        row {
            Button("Run") { send("machine.run") }
                .accessibilityLabel("Run the machine through its key frames")
                .accessibilityValue(mirror.measureLabel)
                .accessibilityIdentifier(port.identifier("run"))
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last action")
                .accessibilityValue(actionsMade)
                .accessibilityIdentifier(port.identifier("undo"))
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the action")
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

    /// Sends `control` and shows a refusal in words.
    private func send(_ control: String, _ values: [Double] = []) {
        if let sender {
            sender(control, values)
            return
        }
        let result = port.send(control, values)
        mirror.message = result.isAccepted ? nil : MoonlitMechanismMirror.refusalText(code: result.code)
    }

    /// Undo and Redo's value (feature 436): the actions made of the budget, "k actions made of B".
    private var actionsMade: String {
        let made: Int = max(mirror.budget - mirror.actionsLeft, 0)
        return (made == 1 ? "1 action made" : "\(made) actions made") + " of \(mirror.budget)"
    }
}
#endif
