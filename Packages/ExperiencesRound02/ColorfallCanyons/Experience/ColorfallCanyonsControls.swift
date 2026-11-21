// ColorfallCanyonsControls — feature 343 (R02-G05-03) T-R02G0503-006 (FR-R02G0503-005; clarification Q5). The minimal
// control panel: a cell picker (previous and next carvable cell) with carve, one valve button per spring, time steps of 1
// and 10 ticks, run to the end (a step of the ticks left, at most 600), undo, redo and next level, each with an
// accessibility label and value; every change is a kernel action sent through the action port. Dragging sluice edits,
// tapping valves and orbit come in R02-G05-04; full accessibility in R02-G05-06. Feature 344 (R02-G05-04) T-R02G0504-005
// (FR-R02G0504-006): the panel gains "Reset view", which returns the camera to the authored view. Feature 345
// (R02-G05-05) T-R02G0505-005 (FR-R02G0505-001 … 005): the tutorial instruction with Dismiss, Hint (each press reveals
// the next level), the failure explanation with Undo and Retry, the goal and stars, Campaign / Daily / Practice and a
// picker of the open levels; all as wrapping text in the panel, never over the canyon. Feature 346 (R02-G05-06)
// T-R02G0506-006 (FR-R02G0506-001, 005, 006; clarification Q5): every control has a label and a value, a summary element
// reads the tick, the actions left and every basin against its target, the cell picker announces its pick, refusals
// show in words, button rows become columns at accessibility text sizes, the panel keeps a 520-point readable width,
// a Sound toggle (off by default) and the scene phase drive the ambient loop.
#if os(iOS)
import ColorfallCanyonsCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Colorfall Canyons.
struct ColorfallCanyonsControls: View {
    let port: ExperienceActionPort
    let mirror: ColorfallCanyonsMirror
    /// The presenter: reset view, hints, retry and the daily date (feature 345), feedback and sound (feature 346).
    let presenter: ColorfallCanyonsPresenter
    /// The text size: rows become columns at accessibility sizes (feature 346).
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Whether the app's scene is active: the ambient loop plays only while it is.
    @Environment(\.scenePhase) private var scenePhase

    /// The widest the panel's content grows, padding included (clarification Q5).
    static let readableWidth: CGFloat = 520

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

    /// A row of controls that becomes a column at accessibility text sizes (feature 346).
    @ViewBuilder private func row(@ViewBuilder _ content: () -> some View) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) { content() }
        } else {
            HStack(spacing: 12) { content() }
        }
    }

    /// The value of the play buttons: the level, the tick and the actions left.
    static func progressValue(_ mirror: ColorfallCanyonsMirror) -> String {
        "Level \(mirror.levelNumber), tick \(mirror.tick) of \(mirror.tickLimit), \(mirror.remaining) actions left"
    }

    /// Replay of the best stored solution: Replay, or during replay its position with Step and Stop (feature 347).
    @ViewBuilder private var replaySection: some View {
        if mirror.replaying {
            Text("Replay: action \(mirror.replayPosition) of \(mirror.replayLength)").font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            row {
                Button("Step") { presenter.stepReplay(port: port) }
                    .accessibilityLabel("Play the next action of the replay")
                    .accessibilityValue("Action \(mirror.replayPosition) of \(mirror.replayLength)")
                Button("Stop") { presenter.stopReplay(port: port) }
                    .accessibilityLabel("Stop the replay")
                    .accessibilityValue("\(mirror.replayLength) actions")
            }
        } else if mirror.replayAvailable {
            Button("Replay best solution") { presenter.startReplay(port: port) }
                .accessibilityLabel("Replay your best solution of this level")
                .accessibilityValue("Level \(mirror.levelNumber)")
        }
    }

    /// The Sound toggle (feature 346; off by default; saved through `settings.sound` since feature 347).
    @ViewBuilder private var soundToggle: some View {
        Toggle("Sound", isOn: Binding(get: { mirror.soundOn }, set: { presenter.saveSound(on: $0, port: port) }))
            .accessibilityLabel("Ambient sound")
            .accessibilityValue(mirror.soundOn ? "on" : "off")
    }

    /// The level, actions, tick and stage lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · actions left \(mirror.remaining) · tick \(mirror.tick) of \(mirror.tickLimit)")
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
        Text(mirror.status).font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Canyon")
            .accessibilityValue(mirror.summary)
        if let message = mirror.message {
            Text(message).font(.footnote).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The tutorial instruction, the hint and the failure explanation (feature 345).
    @ViewBuilder private var teaching: some View {
        if let instruction = mirror.instruction {
            VStack(alignment: .leading, spacing: 4) {
                Text(instruction).font(.callout).fixedSize(horizontal: false, vertical: true)
                Button("Dismiss") { presenter.dismissTutorial(port: port) }
                    .accessibilityLabel("Dismiss the tutorial")
                    .accessibilityValue("tutorial shown")
            }
        }
        row {
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
                row {
                    Button("Undo") { presenter.undo(port: port) }
                        .accessibilityLabel("Undo the last change")
                        .accessibilityValue(Self.progressValue(mirror))
                    Button("Retry") { presenter.retry(port: port) }
                        .accessibilityLabel("Start the level again")
                        .accessibilityValue(Self.progressValue(mirror))
                }
            }
        }
    }

    /// The mode buttons and the picker of open levels with their bands and stars (feature 345).
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
                .accessibilityValue("level \(mirror.pickedLevel)")
        }
    }

    /// "Level n, band b" with its stars when won.
    private func levelLabel(_ level: Int) -> String {
        let band = ColorfallCanyonsProgress.band(of: level)
        if let stars = mirror.stars[level] { return "Level \(level), band \(band), \(stars) stars" }
        return "Level \(level), band \(band)"
    }

    /// The mode's name: campaign, daily, practice or replay.
    static func modeName(_ mode: ColorfallCanyonsMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        case .replay: "replay"
        }
    }

    /// The cell picker and the carve button.
    @ViewBuilder private var carveRow: some View {
        row {
            Stepper("Cell \(mirror.pickedCellLabel)",
                    onIncrement: { presenter.pickCell(1) },
                    onDecrement: { presenter.pickCell(-1) })
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
        row {
            ForEach(0..<mirror.springNames.count, id: \.self) { index in
                Button(mirror.springNames[index]) { send("canyon.valve", [Double(index)]) }
                    .accessibilityLabel("\(mirror.springNames[index].capitalized) valve")
                    .accessibilityValue(mirror.springStates.indices.contains(index) ? mirror.springStates[index] : "")
            }
        }
    }

    /// Time steps of 1 and 10 ticks and run to the end.
    @ViewBuilder private var timeRow: some View {
        row {
            Button("Step 1") { send("time.step", [1]) }
                .accessibilityLabel("Let the fluid run one tick")
                .accessibilityValue("tick \(mirror.tick) of \(mirror.tickLimit)")
            Button("Step 10") { send("time.step", [10]) }
                .accessibilityLabel("Let the fluid run ten ticks")
                .accessibilityValue("tick \(mirror.tick) of \(mirror.tickLimit)")
            Button("Run") { send("time.step", [Double(max(1, min(600, mirror.tickLimit - mirror.tick)))]) }
                .accessibilityLabel("Let the fluid run to the end")
                .accessibilityValue("\(max(0, mirror.tickLimit - mirror.tick)) ticks left")
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
                .accessibilityValue("level \(mirror.levelNumber)")
            Button("Reset view") { presenter.resetView() }
                .accessibilityLabel("Return the camera to the starting view")
                .accessibilityValue("camera")
        }
    }

    /// Sends `control` and shows a refusal.
    private func send(_ control: String, _ values: [Double] = []) {
        presenter.send(control, values, port: port)
    }
}
#endif
