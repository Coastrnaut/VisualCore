// ChronoConstellatorControls — feature 353 (R02-G06-03) T-R02G0603-006 (FR-R02G0603-005; clarification Q5). The minimal
// control panel: a labelled star picker (previous and next star, named by number and shape), the picked star's start
// phase − and +, add and remove a hold (start 1, length 10 at the picked star), time steps of 1 and 10 ticks, run to the
// end (a step of the ticks left), rewind, undo, redo and next level, each with an accessibility label and value; every
// change is a kernel action sent through the action port. Timeline dragging and scrubbing come in R02-G06-04; full
// accessibility in R02-G06-06.
#if os(iOS)
import ChronoConstellatorCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Chrono Constellator.
struct ChronoConstellatorControls: View {
    let port: ExperienceActionPort
    let mirror: ChronoConstellatorMirror

    /// The start and length of the hold the panel adds and removes.
    static let holdStart = 1
    static let holdLength = 10

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                starRow
                holdRow
                timeRow
                playRow
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
        }
    }

    /// Sends a phase change of the picked star by `delta` cells round its loop.
    private func sendPhase(_ delta: Int) {
        guard let next = mirror.phase(after: delta) else { return }
        send("star.phase", [Double(mirror.pickedStar), Double(next)])
    }

    /// Sends `control` and shows a refusal.
    private func send(_ control: String, _ values: [Double] = []) {
        let result = port.send(control, values)
        mirror.message = result.isAccepted ? nil : "That change was refused: \(result.code)"
    }
}
#endif
