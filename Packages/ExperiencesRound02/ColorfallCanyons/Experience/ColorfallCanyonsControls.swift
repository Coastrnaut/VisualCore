// ColorfallCanyonsControls — feature 343 (R02-G05-03) T-R02G0503-006 (FR-R02G0503-005; clarification Q5). The minimal
// control panel: a cell picker (previous and next carvable cell) with carve, one valve button per spring, time steps of 1
// and 10 ticks, run to the end (a step of the ticks left, at most 600), undo, redo and next level, each with an
// accessibility label and value; every change is a kernel action sent through the action port. Dragging sluice edits,
// tapping valves and orbit come in R02-G05-04; full accessibility in R02-G05-06. Feature 344 (R02-G05-04) T-R02G0504-005
// (FR-R02G0504-006): the panel gains "Reset view", which returns the camera to the authored view. Feature 345
// (R02-G05-05) T-R02G0505-005 (FR-R02G0505-001 … 005): the tutorial instruction with Dismiss, Hint (each press reveals
// the next level), the failure explanation with Undo and Retry, the goal and stars, Campaign / Daily / Practice and a
// picker of the open levels; all as wrapping text in the panel, never over the canyon.
#if os(iOS)
import ColorfallCanyonsCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Colorfall Canyons.
struct ColorfallCanyonsControls: View {
    let port: ExperienceActionPort
    let mirror: ColorfallCanyonsMirror
    /// The presenter: reset view, hints, retry and the daily date (feature 345).
    let presenter: ColorfallCanyonsPresenter

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teaching
                carveRow
                valveRow
                timeRow
                playRow
                progressRows
            }
            .padding()
        }
    }

    /// The level, actions, tick and stage lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · actions left \(mirror.remaining) · tick \(mirror.tick) of \(mirror.tickLimit)")
            .font(.headline)
        Text(mirror.status).font(.subheadline)
        if let message = mirror.message {
            Text(message).font(.footnote)
        }
    }

    /// The tutorial instruction, the hint and the failure explanation (feature 345).
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
            Text("Goal: \(mirror.spent) of \(mirror.budget) actions; best possible \(mirror.smallest)")
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
                    Button("Retry") { presenter.retry(port: port) }
                        .accessibilityLabel("Start the level again")
                }
            }
        }
    }

    /// The mode buttons and the picker of open levels with their bands and stars (feature 345).
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
        let band = ColorfallCanyonsProgress.band(of: level)
        if let stars = mirror.stars[level] { return "Level \(level), band \(band), \(stars) stars" }
        return "Level \(level), band \(band)"
    }

    /// The mode's name: campaign, daily or practice.
    static func modeName(_ mode: ColorfallCanyonsMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        }
    }

    /// The cell picker and the carve button.
    @ViewBuilder private var carveRow: some View {
        HStack(spacing: 12) {
            Stepper("Cell \(mirror.pickedCellLabel)",
                    onIncrement: { mirror.pickNext(1) },
                    onDecrement: { mirror.pickNext(-1) })
                .accessibilityLabel("Cell to carve")
                .accessibilityValue(mirror.pickedCellLabel)
            Button("Carve") {
                if let cell = mirror.pickedCell { send("canyon.carve", [Double(cell)]) }
            }
            .accessibilityLabel("Carve the picked cell one step lower")
            .accessibilityValue(mirror.pickedCellLabel)
        }
    }

    /// One valve button per spring.
    @ViewBuilder private var valveRow: some View {
        HStack(spacing: 12) {
            ForEach(0..<mirror.springNames.count, id: \.self) { index in
                Button(mirror.springNames[index]) { send("canyon.valve", [Double(index)]) }
                    .accessibilityLabel("Toggle the valve of the \(mirror.springNames[index]) spring")
                    .accessibilityValue(mirror.springStates.indices.contains(index) ? mirror.springStates[index] : "")
            }
        }
    }

    /// Time steps of 1 and 10 ticks and run to the end.
    @ViewBuilder private var timeRow: some View {
        HStack(spacing: 12) {
            Button("Step 1") { send("time.step", [1]) }
                .accessibilityLabel("Let the fluid run one tick")
            Button("Step 10") { send("time.step", [10]) }
                .accessibilityLabel("Let the fluid run ten ticks")
            Button("Run") { send("time.step", [Double(max(1, min(600, mirror.tickLimit - mirror.tick)))]) }
                .accessibilityLabel("Let the fluid run to the end")
                .accessibilityValue("\(max(0, mirror.tickLimit - mirror.tick)) ticks left")
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
        }
    }

    /// Sends `control` and shows a refusal.
    private func send(_ control: String, _ values: [Double] = []) {
        let result = port.send(control, values)
        mirror.message = result.isAccepted ? nil : "That change was refused: \(result.code)"
    }
}
#endif
