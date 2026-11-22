// ChronoConstellatorControls — feature 353 (R02-G06-03) T-R02G0603-006 (FR-R02G0603-005; clarification Q5). The minimal
// control panel: a labelled star picker (previous and next star, named by number and shape), the picked star's start
// phase − and +, add and remove a hold (start 1, length 10 at the picked star), time steps of 1 and 10 ticks, run to
// the end (a step of the ticks left), rewind, undo, redo and next level, each with an accessibility label and value;
// every change is a kernel action sent through the action port. Timeline dragging and scrubbing come in R02-G06-04;
// full accessibility in R02-G06-06. Feature 354 (R02-G06-04) T-R02G0604-005 (FR-R02G0604-007): the panel gains "Reset
// view", which returns the camera to the authored view; refusals are shown and logged by the presenter. Feature 355
// (R02-G06-05) T-R02G0605-005 (FR-R02G0605-001 … 005): the tutorial instruction with Dismiss, Hint (each press reveals
// the next level), the failure explanation with Undo, Rewind and Retry, the goal and stars, Campaign / Daily / Practice
// and a picker of the open levels; all as wrapping text in the panel, never over the sky. Feature 356 (R02-G06-06)
// T-R02G0606-006 (FR-R02G0606-001, 005, 006; clarification Q5): every control has a label and a value, a summary
// element reads the tick, the edits left and every star, the star picker announces its pick, refusals appear in words,
// a Sound toggle (off by default) starts the ambient loop, rows become columns at accessibility text sizes, the panel
// keeps a readable width of 520 points on iPad, and the scene phase reaches the presenter so the loop stops in the
// background.
#if os(iOS)
import ChronoConstellatorCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Chrono Constellator.
struct ChronoConstellatorControls: View {
    let port: ExperienceActionPort
    let mirror: ChronoConstellatorMirror
    /// The presenter, for "Reset view" (feature 354) and refusals shown like the gestures' ones.
    let presenter: ChronoConstellatorPresenter

    /// The text size: rows become columns at accessibility sizes (feature 356).
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Whether the app's scene is active: the ambient loop plays only while it is.
    @Environment(\.scenePhase) private var scenePhase

    /// The widest the panel's content grows, padding included (clarification Q5).
    static let readableWidth: CGFloat = 520

    /// The start and length of the hold the panel adds and removes.
    static let holdStart = 1
    static let holdLength = 10

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teaching
                starRow
                holdRow
                timeRow
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

    /// A row of controls that becomes a column at accessibility text sizes (feature 356).
    @ViewBuilder private func row(@ViewBuilder _ content: () -> some View) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) { content() }
        } else {
            HStack(spacing: 12) { content() }
        }
    }

    /// The value of the play buttons: the level, the tick and the edits left (feature 356).
    static func progressValue(_ mirror: ChronoConstellatorMirror) -> String {
        "Level \(mirror.levelNumber), tick \(mirror.tick) of \(mirror.tickLimit), \(mirror.remaining) edits left"
    }

    /// The Sound toggle (feature 356; off by default).
    @ViewBuilder private var soundToggle: some View {
        Toggle("Sound", isOn: Binding(get: { mirror.soundOn }, set: { presenter.setSound(on: $0) }))
            .accessibilityLabel("Ambient sound")
            .accessibilityValue(mirror.soundOn ? "on" : "off")
    }

    /// The level, edits, tick and stage lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · edits left \(mirror.remaining) · tick \(mirror.tick) of \(mirror.tickLimit)")
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
        Text(mirror.status).font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Sky")
            .accessibilityValue(mirror.summary)
        if let message = mirror.message {
            Text(message).font(.footnote).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The tutorial instruction, the hint and the failure explanation (feature 355).
    @ViewBuilder private var teaching: some View {
        if let instruction = mirror.instruction {
            VStack(alignment: .leading, spacing: 4) {
                Text(instruction).font(.callout).fixedSize(horizontal: false, vertical: true)
                Button("Dismiss") { presenter.dismissTutorial(port: port) }
                    .accessibilityLabel("Dismiss the tutorial")
                    .accessibilityValue(instruction)
            }
        }
        row {
            Button("Hint") { presenter.showHint() }
                .accessibilityLabel("Show a hint")
                .accessibilityValue(mirror.hintLevel == 0 ? "none shown" : "level \(mirror.hintLevel) of 3")
            Text("Goal: \(mirror.spent) of \(mirror.budget) edits; best possible \(mirror.smallest)")
                .font(.footnote)
        }
        if let hint = mirror.hintText {
            Text(hint).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
        if let failure = mirror.failureText {
            VStack(alignment: .leading, spacing: 4) {
                Text(failure).font(.callout).fixedSize(horizontal: false, vertical: true)
                row {
                    Button("Undo") { presenter.undo(port: port) }
                        .accessibilityLabel("Undo the last change")
                        .accessibilityValue(failure)
                    Button("Rewind") { presenter.rewind(port: port) }
                        .accessibilityLabel("Return to tick 0 keeping the timeline")
                        .accessibilityValue(Self.progressValue(mirror))
                    Button("Retry") { presenter.retry(port: port) }
                        .accessibilityLabel("Start the level again")
                        .accessibilityValue("Level \(mirror.levelNumber)")
                }
            }
        }
    }

    /// The mode buttons and the picker of open levels with their bands and stars (feature 355).
    @ViewBuilder private var progressRows: some View {
        row {
            Button("Campaign") { send("mode.campaign") }
                .accessibilityLabel("Play the campaign")
                .accessibilityValue(Self.modeName(mirror.mode) == "campaign" ? "selected" : "")
            Button("Daily") { presenter.playDaily(port: port) }
                .accessibilityLabel("Play today's daily level")
                .accessibilityValue(Self.modeName(mirror.mode) == "daily" ? "selected" : "")
            Button("Practice") { send("mode.practice") }
                .accessibilityLabel("Practise this level with a larger budget")
                .accessibilityValue(Self.modeName(mirror.mode) == "practice" ? "selected" : "")
        }
        row {
            Stepper(levelLabel(mirror.pickedLevel),
                    onIncrement: { mirror.pickedLevel = min(mirror.pickedLevel + 1, mirror.frontier) },
                    onDecrement: { mirror.pickedLevel = max(mirror.pickedLevel - 1, 1) })
                .accessibilityLabel("Level to play")
                .accessibilityValue(levelLabel(mirror.pickedLevel))
            Button("Play level") { send("level.select", [Double(mirror.pickedLevel)]) }
                .accessibilityLabel("Play the picked level")
                .accessibilityValue(levelLabel(mirror.pickedLevel))
        }
    }

    /// "Level n, band b" with its stars when won.
    private func levelLabel(_ level: Int) -> String {
        let band = ChronoConstellatorProgress.band(of: level)
        if let stars = mirror.stars[level] { return "Level \(level), band \(band), \(stars) stars" }
        return "Level \(level), band \(band)"
    }

    /// The mode's name: campaign, daily or practice.
    static func modeName(_ mode: ChronoConstellatorMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        }
    }

    /// The star picker and the phase − and + buttons.
    @ViewBuilder private var starRow: some View {
        row {
            Stepper(mirror.pickedStarLabel,
                    onIncrement: { presenter.pickStar(1) },
                    onDecrement: { presenter.pickStar(-1) })
                .accessibilityLabel("Star to edit")
                .accessibilityValue(mirror.pickedStarLabel)
            Button("Phase −") { sendPhase(-1) }
                .accessibilityLabel("Start the picked star one cell earlier on its loop")
                .accessibilityValue(mirror.pickedPhaseLabel)
            Button("Phase +") { sendPhase(1) }
                .accessibilityLabel("Start the picked star one cell later on its loop")
                .accessibilityValue(mirror.pickedPhaseLabel)
        }
    }

    /// Add and remove the panel's hold at the picked star.
    @ViewBuilder private var holdRow: some View {
        row {
            Button("Add hold") {
                send("star.hold", [Double(mirror.pickedStar), Double(Self.holdStart), Double(Self.holdLength)])
            }
            .accessibilityLabel("Hold the picked star for \(Self.holdLength) ticks from tick \(Self.holdStart)")
            .accessibilityValue(mirror.pickedHoldsLabel)
            Button("Remove hold") { send("star.release", [Double(mirror.pickedStar), Double(Self.holdStart)]) }
                .accessibilityLabel("Remove the picked star's hold that starts at tick \(Self.holdStart)")
                .accessibilityValue(mirror.pickedHoldsLabel)
        }
    }

    /// Time steps of 1 and 10 ticks, run to the end and rewind.
    @ViewBuilder private var timeRow: some View {
        row {
            Button("Step 1") { send("time.step", [1]) }
                .accessibilityLabel("Replay one tick")
                .accessibilityValue(Self.progressValue(mirror))
            Button("Step 10") { send("time.step", [10]) }
                .accessibilityLabel("Replay ten ticks")
                .accessibilityValue(Self.progressValue(mirror))
            Button("Run") { send("time.step", [Double(max(1, min(1_200, mirror.tickLimit - mirror.tick)))]) }
                .accessibilityLabel("Replay to the end")
                .accessibilityValue("\(max(0, mirror.tickLimit - mirror.tick)) ticks left")
            Button("Rewind") { send("time.rewind") }
                .accessibilityLabel("Return to tick 0 keeping the timeline")
                .accessibilityValue(Self.progressValue(mirror))
        }
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        row {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last action")
                .accessibilityValue(Self.progressValue(mirror))
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the action")
                .accessibilityValue(Self.progressValue(mirror))
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
                .accessibilityValue("Level \(mirror.levelNumber)")
            Button("Reset view") { presenter.resetView() }
                .accessibilityLabel("Return the camera to the starting view")
                .accessibilityValue("camera")
        }
    }

    /// Sends a phase change of the picked star by `delta` cells round its loop.
    private func sendPhase(_ delta: Int) {
        guard let next = mirror.phase(after: delta) else { return }
        send("star.phase", [Double(mirror.pickedStar), Double(next)])
    }

    /// Sends `control` through the presenter, which shows and logs a refusal.
    private func send(_ control: String, _ values: [Double] = []) {
        presenter.send(control, values, port: port)
    }
}
#endif
