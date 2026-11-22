// ChronoConstellatorControls — feature 353 (R02-G06-03) T-R02G0603-006 (FR-R02G0603-005; clarification Q5). The minimal
// control panel: a labelled star picker (previous and next star, named by number and shape), the picked star's start
// phase − and +, add and remove a hold (start 1, length 10 at the picked star), time steps of 1 and 10 ticks, run to the
// end (a step of the ticks left), rewind, undo, redo and next level, each with an accessibility label and value; every
// change is a kernel action sent through the action port. Timeline dragging and scrubbing come in R02-G06-04; full
// accessibility in R02-G06-06. Feature 354 (R02-G06-04) T-R02G0604-005 (FR-R02G0604-007): the panel gains "Reset
// view", which returns the camera to the authored view; refusals are shown and logged by the presenter. Feature 355
// (R02-G06-05) T-R02G0605-005 (FR-R02G0605-001 … 005): the tutorial instruction with Dismiss, Hint (each press reveals
// the next level), the failure explanation with Undo, Rewind and Retry, the goal and stars, Campaign / Daily / Practice
// and a picker of the open levels; all as wrapping text in the panel, never over the sky.
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
            }
            .padding()
        }
    }

    /// The level, edits, tick and stage lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · edits left \(mirror.remaining) · tick \(mirror.tick) of \(mirror.tickLimit)")
            .font(.headline)
        Text(mirror.status).font(.subheadline)
        if let message = mirror.message {
            Text(message).font(.footnote)
        }
    }

    /// The tutorial instruction, the hint and the failure explanation (feature 355).
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
            Text("Goal: \(mirror.spent) of \(mirror.budget) edits; best possible \(mirror.smallest)")
                .font(.footnote)
        }
        if let hint = mirror.hintText {
            Text(hint).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
        if let failure = mirror.failureText {
            VStack(alignment: .leading, spacing: 4) {
                Text(failure).font(.callout).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Button("Undo") { presenter.undo(port: port) }
                        .accessibilityLabel("Undo the last change")
                    Button("Rewind") { presenter.rewind(port: port) }
                        .accessibilityLabel("Return to tick 0 keeping the timeline")
                    Button("Retry") { presenter.retry(port: port) }
                        .accessibilityLabel("Start the level again")
                }
            }
        }
    }

    /// The mode buttons and the picker of open levels with their bands and stars (feature 355).
    @ViewBuilder private var progressRows: some View {
        HStack(spacing: 12) {
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
        HStack(spacing: 12) {
            Stepper(mirror.pickedStarLabel,
                    onIncrement: { mirror.pickNext(1) },
                    onDecrement: { mirror.pickNext(-1) })
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
        HStack(spacing: 12) {
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
        HStack(spacing: 12) {
            Button("Step 1") { send("time.step", [1]) }
                .accessibilityLabel("Replay one tick")
            Button("Step 10") { send("time.step", [10]) }
                .accessibilityLabel("Replay ten ticks")
            Button("Run") { send("time.step", [Double(max(1, min(1_200, mirror.tickLimit - mirror.tick)))]) }
                .accessibilityLabel("Replay to the end")
                .accessibilityValue("\(max(0, mirror.tickLimit - mirror.tick)) ticks left")
            Button("Rewind") { send("time.rewind") }
                .accessibilityLabel("Return to tick 0 keeping the timeline")
        }
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        HStack(spacing: 16) {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last action")
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the action")
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
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
