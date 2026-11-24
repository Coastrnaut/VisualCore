// VoxelOrigamiControls — feature 443 (R02-G15-03) T-R02G1503-006 (FR-R02G1503-005; clarification Q5). The minimal
// control panel: labelled buttons for the chosen hinge (hinge − and +, `hinge.choose [h]`; presentation state of the
// adapter, a level opens with its first turnable hinge chosen, clamped to the level's hinges), turning it (turn − and
// +, `hinge.turn [h, ±1]`), undo, redo and next level (kernel actions through the action port), each with an
// accessibility label, value and identifier; the header shows the actions left of the budget, the status (stage, or the
// failure in words), the progress description, the failure in words and a refused action in words. Since feature 444
// (R02-G15-04) the panel shows the pending turn of a canvas drag and has "Reset view". Feature 445 (R02-G15-05)
// T-R02G1505-005: the tutorial instruction with Dismiss, Hint (each press reveals the next level), the failure
// explanation with Undo and Retry, the goal with the level's band and best stars, Campaign / Daily / Practice and a
// picker of the open levels with Play level; all as wrapping text in the panel, never over the solid. "Next level"
// stays; before a win it is refused in words. Feature 446 (R02-G15-06) T-R02G1506-005 (FR-R02G1506-001, 005, 006;
// clarification Q5): the summary element ("Solid", identifier `summary`), the adjustable hinge
// (`accessibilityAdjustableAction`; its value is the hinge as the level words it with its turn, whether it can turn and
// the cube it swings), a value in words on every control (Turn the chosen hinge, Undo and Redo the actions made, Next
// level the next open level, Retry the level and mode, Play level the picked level, Reset view "authored" or "orbited",
// Dismiss the instruction, Campaign / Daily / Practice "selected" or "not selected", Hint the level shown, Sound "on" or
// "off"), refusals in the feedback plan's words, the Sound toggle (off by default, identifier `sound`), rows that become
// columns at accessibility text sizes, wrapping text and a 520-point readable width (iPad).
#if os(iOS)
import SwiftUI
import VisualCoreExperienceHost
import VoxelOrigamiCore

/// The control panel of Voxel Origami.
struct VoxelOrigamiControls: View {
    /// Where actions are sent.
    let port: ExperienceActionPort
    /// What the panel shows.
    let mirror: VoxelOrigamiMirror
    /// The presenter (feature 445): hints, tutorial, retry, undo and the daily level.
    let presenter: VoxelOrigamiPresenter
    /// Returns the camera to the authored view (feature 444; presentation only).
    var resetView: () -> Void = {}
    /// Sends a control and shows a refusal in words (the presenter's `send`, feature 444); nil sends through the port
    /// directly.
    var sender: ((String, [Double]) -> Void)? = nil
    /// The text size: rows become columns at accessibility sizes (feature 446).
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Whether the app's scene is active: the sound plays only while it is (feature 446).
    @Environment(\.scenePhase) private var scenePhase

    /// The widest the panel's content grows, padding included (clarification Q5 of feature 446).
    static let readableWidth: CGFloat = 520

    /// The panel.
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teaching
                hingeRow
                turnRow
                playRow
                progressRows
                soundToggle
            }
            .padding()
            .frame(maxWidth: Self.readableWidth, alignment: .leading)
        }
        .onAppear { presenter.controlsAppeared() }
        .onDisappear { presenter.controlsDisappeared() }
        .onChange(of: scenePhase) { _, phase in presenter.sceneActive(phase == .active) }
    }

    /// A row of controls that becomes a column at accessibility text sizes (feature 446).
    @ViewBuilder private func row(@ViewBuilder _ content: () -> some View) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) { content() }
        } else {
            HStack(spacing: 12) { content() }
        }
    }

    /// The Sound toggle (feature 446; off by default; presentation only).
    @ViewBuilder private var soundToggle: some View {
        Toggle("Sound", isOn: Binding(get: { mirror.soundOn }, set: { presenter.setSound(on: $0) }))
            .accessibilityLabel("Sound of the solid")
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
            .accessibilityLabel("Solid")
            .accessibilityValue(mirror.summary)
            .accessibilityIdentifier(port.identifier("summary"))
        Text(mirror.targetLabel).font(.footnote).fixedSize(horizontal: false, vertical: true)
        if let message = mirror.message {
            Text(message).font(.footnote)
                .accessibilityIdentifier(port.identifier("message"))
        }
        if let pending = mirror.pending {
            Text(pending).font(.footnote)
                .accessibilityIdentifier(port.identifier("pending"))
        }
    }

    /// Choose the previous or next hinge.
    @ViewBuilder private var hingeRow: some View {
        row {
            Button("Hinge −") { send("hinge.choose", [Double(mirror.clampedHinge(mirror.hinge - 1))]) }
                .accessibilityLabel("Choose the previous hinge")
                .accessibilityValue(mirror.hingeDetail)
                .accessibilityIdentifier(port.identifier("hinge-minus"))
            Text(mirror.hingeLabel)
                .accessibilityIdentifier(port.identifier("hinge"))
            Button("Hinge +") { send("hinge.choose", [Double(mirror.clampedHinge(mirror.hinge + 1))]) }
                .accessibilityLabel("Choose the next hinge")
                .accessibilityValue(mirror.hingeDetail)
                .accessibilityIdentifier(port.identifier("hinge-plus"))
        }
        Text(mirror.hingeDetail).font(.footnote).fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Chosen hinge")
            .accessibilityValue(mirror.hingeDetail)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: send("hinge.choose", [Double(mirror.clampedHinge(mirror.hinge + 1))])
                case .decrement: send("hinge.choose", [Double(mirror.clampedHinge(mirror.hinge - 1))])
                @unknown default: break
                }
            }
            .accessibilityIdentifier(port.identifier("hinge-detail"))
    }

    /// Turn the chosen hinge a quarter turn back or forward.
    @ViewBuilder private var turnRow: some View {
        row {
            Button("Turn −") { send("hinge.turn", [Double(mirror.hinge), -1]) }
                .accessibilityLabel("Turn the chosen hinge a quarter turn back")
                .accessibilityValue(mirror.hingeDetail)
                .accessibilityIdentifier(port.identifier("turn-minus"))
            Button("Turn +") { send("hinge.turn", [Double(mirror.hinge), 1]) }
                .accessibilityLabel("Turn the chosen hinge a quarter turn forward")
                .accessibilityValue(mirror.hingeDetail)
                .accessibilityIdentifier(port.identifier("turn-plus"))
        }
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        row {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last turn")
                .accessibilityValue(actionsMade)
                .accessibilityIdentifier(port.identifier("undo"))
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the turn")
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

    /// The tutorial instruction, the hint, the goal and the failure's explanation with Undo and Retry (feature 445).
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
                    .accessibilityLabel("Undo the last turn")
                    .accessibilityValue(actionsMade)
                    .accessibilityIdentifier(port.identifier("failure-undo"))
                Button("Retry") { presenter.retry(port: port) }
                    .accessibilityLabel("Start the level again")
                    .accessibilityValue("level \(mirror.levelNumber), " + Self.modeName(mirror.mode))
                    .accessibilityIdentifier(port.identifier("retry"))
            }
        }
    }

    /// The mode buttons and the picker of open levels with their bands and stars (feature 445).
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
        let band: Int = VoxelOrigamiProgress.band(of: level)
        if let stars = mirror.stars[level] { return "Level \(level), band \(band), \(stars) stars" }
        return "Level \(level), band \(band)"
    }

    /// The mode's name: campaign, daily or practice.
    static func modeName(_ mode: VoxelOrigamiMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        }
    }

    /// Sends `control` and shows a refusal in words.
    private func send(_ control: String, _ values: [Double] = []) {
        if let sender {
            sender(control, values)
            return
        }
        let result = port.send(control, values)
        mirror.message = result.isAccepted ? nil : VoxelOrigamiMirror.refusalText(code: result.code)
    }

    /// Undo and Redo's value (feature 446): the actions made of the budget, "k actions made of B".
    private var actionsMade: String {
        let made: Int = max(mirror.budget - mirror.actionsLeft, 0)
        return (made == 1 ? "1 action made" : "\(made) actions made") + " of \(mirror.budget)"
    }
}
#endif
