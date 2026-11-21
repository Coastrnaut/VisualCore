// HueCompassControls — feature 333 (R02-G04-03) T-R02G0403-006 (FR-R02G0403-005; clarification Q5). The minimal
// control panel: turn buttons (−4, −1, +1, +4 bearings), probe, a band picker (0 … 23, presentation only) with select
// (the current bearing with the picked band), undo, redo and next level, each with an accessibility label and value;
// every change is a kernel action sent through the action port. Swipe and orbit come in R02-G04-04; full accessibility
// in R02-G04-06.
// Feature 334 (R02-G04-04) T-R02G0404-005 (FR-R02G0404-004, 005; clarification Q4): the panel gains "Reset view",
// which returns the camera to the authored view (presentation only; no kernel action).
// Feature 335 (R02-G04-05) T-R02G0405-005 (FR-R02G0405-001 … 005; clarifications Q1–Q5): the tutorial instruction with
// Dismiss, a Hint button that reveals the next hint level, the failure explanation with Retry (probes and selections
// cannot be undone, so no Undo there), the goal (units allowed, fewest probes), the mode (Campaign, Daily, Practice) and
// a level picker of the open levels by band of 20 with their stars. The body is split into small sections so the type
// checker stays fast. Every text is plain panel text read by VoiceOver.
// Feature 336 (R02-G04-06) T-R02G0406-006 (FR-R02G0406-001, 005, 006; clarification Q5): every control carries a label
// and a value, a summary element reads the bearing, band, units and last clue, the band stepper announces its pick,
// button rows become columns at accessibility text sizes, texts wrap rather than truncate, the panel keeps a readable
// width of at most 520 points (padding included), a Sound toggle (off by default) drives the ambient loop, refusals show
// in words, and the panel tells the presenter when it is on screen and when the app's scene is active.
// Feature 337 (R02-G04-07) T-R02G0407-005: Replay best solution for a verified solved level, and during replay its
// position with Step and Stop, each with a label and a value.
#if os(iOS)
import HueCompassCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Hue Compass.
struct HueCompassControls: View {
    let port: ExperienceActionPort
    let mirror: HueCompassMirror
    /// The presenter (feature 335): hints, retry, the daily date and "Reset view" (feature 334).
    let presenter: HueCompassPresenter

    /// The turn steps of the four turn buttons, in order.
    static let turns: [Int] = [-4, -1, 1, 4]
    /// The button titles of the turn buttons.
    static let turnTitles: [String] = ["−4", "−1", "+1", "+4"]

    @Environment(\.dynamicTypeSize) private var typeSize
    /// Whether the app's scene is active (convergence task T-R02G0406-014): the ambient loop plays only while it is.
    @Environment(\.scenePhase) private var scenePhase

    /// The widest the panel's content grows, padding included (clarification Q5).
    static let readableWidth: CGFloat = 520

    /// The spoken name of a turn of `steps` bearings (positive: counter-clockwise, the kernel's angle direction).
    static func turnLabel(_ steps: Int) -> String {
        let count: Int = abs(steps)
        let unit: String = count == 1 ? "bearing" : "bearings"
        let way: String = steps < 0 ? "clockwise" : "counter-clockwise"
        return "Turn the needle \(count) \(unit) \(way)"
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teachingSection
                failureSection
                hintRow
                turnRow
                bandPicker
                probeRow
                playRow
                modeRow
                levelMenu
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

    /// A row of controls that becomes a column at accessibility text sizes (feature 336).
    @ViewBuilder private func row(@ViewBuilder _ content: () -> some View) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) { content() }
        } else {
            HStack(spacing: 16) { content() }
        }
    }

    /// Replay of the best stored solution: Replay, or during replay its position with Step and Stop (feature 337).
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

    /// The Sound toggle (feature 336; off by default).
    @ViewBuilder private var soundToggle: some View {
        Toggle("Sound", isOn: Binding(get: { mirror.soundOn }, set: { presenter.setSound(on: $0) }))
            .accessibilityLabel("Ambient sound")
            .accessibilityValue(mirror.soundOn ? "on" : "off")
    }

    /// The value of the play buttons: the level and the units spent.
    static func progressValue(_ mirror: HueCompassMirror) -> String {
        "Level \(mirror.levelNumber), units \(mirror.spent) of \(mirror.allowance)"
    }

    /// The level, units and bearing lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · units \(mirror.spent) of \(mirror.allowance)")
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
        Text("Bearing \(mirror.bearing) · band \(mirror.bandUnderNeedle + 1) · clues \(mirror.clueCount)")
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Compass")
            .accessibilityValue(mirror.summary)
        if let message = mirror.message {
            Text(message).font(.footnote).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The goal line and the tutorial instruction with Dismiss (feature 335).
    @ViewBuilder private var teachingSection: some View {
        Text(Self.goal(mirror)).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        if let instruction = mirror.instruction {
            Text(instruction).font(.callout).fixedSize(horizontal: false, vertical: true)
            Button("Dismiss") { presenter.dismissTutorial(port: port) }
                .accessibilityLabel("Dismiss the tutorial")
                .accessibilityValue("Level \(mirror.levelNumber)")
        }
    }

    /// The failure explanation with Retry (feature 335; probes and selections cannot be undone).
    @ViewBuilder private var failureSection: some View {
        if let failure = mirror.failureText {
            Text(failure).font(.callout).fixedSize(horizontal: false, vertical: true)
            Button("Retry") { presenter.retry(port: port) }
                .accessibilityLabel("Retry the level")
                .accessibilityValue("Level \(mirror.levelNumber)")
        }
    }

    /// The Hint button and the hint revealed so far (feature 335).
    @ViewBuilder private var hintRow: some View {
        Button("Hint") { presenter.showHint(port: port) }
            .accessibilityLabel("Show a hint")
            .accessibilityValue(mirror.hintLevel == 0 ? "none shown" : "level \(mirror.hintLevel) of 3")
        if let hint = mirror.hintText { Text(hint).font(.callout).fixedSize(horizontal: false, vertical: true) }
    }

    /// Campaign, Daily and Practice (feature 335).
    @ViewBuilder private var modeRow: some View {
        row {
            Button("Campaign") { send("mode.campaign") }
                .accessibilityLabel("Play the campaign")
                .accessibilityValue(mirror.mode == .campaign ? "playing" : "not playing")
                .accessibilityAddTraits(mirror.mode == .campaign ? .isSelected : [])
            Button("Daily") { presenter.playDaily(port: port) }
                .accessibilityLabel("Play today's daily level")
                .accessibilityValue(Self.isDaily(mirror.mode) ? "playing" : "not playing")
                .accessibilityAddTraits(Self.isDaily(mirror.mode) ? .isSelected : [])
            Button("Practice") { send("mode.practice") }
                .accessibilityLabel("Practise this level with more units")
                .accessibilityValue(mirror.mode == .practice ? "playing" : "not playing")
                .accessibilityAddTraits(mirror.mode == .practice ? .isSelected : [])
        }
    }

    /// The level picker: the open levels by band of 20, with their stars (feature 335).
    @ViewBuilder private var levelMenu: some View {
        Menu("Levels") {
            ForEach(0..<HueCompassProgress.bands.count, id: \.self) { band in
                Section("Band \(band + 1)") {
                    ForEach(Self.levels(inBand: band), id: \.self) { level in
                        if level <= mirror.frontier {
                            Button(Self.levelTitle(level, stars: mirror.stars[level])) {
                                send("level.select", [Double(level)])
                            }
                        }
                    }
                }
            }
        }
        .accessibilityLabel("Choose an open level")
        .accessibilityValue("Level \(mirror.levelNumber); levels 1 to \(mirror.frontier) open")
    }

    /// The level numbers of band `band` (0 … 4): 20 band + 1 … 20 band + 20.
    static func levels(inBand band: Int) -> [Int] {
        let size: Int = HueCompassProgress.levelsPerBand
        return Array((band * size + 1)...(band * size + size))
    }

    /// The goal line: units allowed, the fewest probes and the mode.
    static func goal(_ mirror: HueCompassMirror) -> String {
        let mode: String
        switch mirror.mode {
        case .campaign: mode = "Campaign"
        case .practice: mode = "Practice"
        case .daily: mode = "Daily level"
        case .replay: mode = "Replay"
        }
        return "\(mode) · goal: \(mirror.allowance) units allowed, fewest probes \(mirror.smallest)"
    }

    /// Whether `mode` is daily.
    static func isDaily(_ mode: HueCompassMode) -> Bool {
        if case .daily = mode { return true }
        return false
    }

    /// A level picker entry: "Level 7 · 3 stars", or "Level 7" when not won.
    static func levelTitle(_ level: Int, stars: Int?) -> String {
        guard let stars else { return "Level \(level)" }
        return "Level \(level) · \(stars) \(stars == 1 ? "star" : "stars")"
    }

    /// One button per turn step.
    @ViewBuilder private var turnRow: some View {
        row {
            ForEach(0..<Self.turns.count, id: \.self) { index in
                Button(Self.turnTitles[index]) { send("compass.turn", [Double(Self.turns[index])]) }
                    .accessibilityLabel(Self.turnLabel(Self.turns[index]))
                    .accessibilityValue("Bearing \(mirror.bearing) of 96")
            }
        }
    }

    /// The band picker for the next selection: previous and next band.
    @ViewBuilder private var bandPicker: some View {
        Stepper("Band \(mirror.pickedBand + 1) of 24",
                onIncrement: { presenter.pickBand((mirror.pickedBand + 1) % 24) },
                onDecrement: { presenter.pickBand((mirror.pickedBand + 23) % 24) })
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Hue band to select")
            .accessibilityValue("band \(mirror.pickedBand + 1) of 24")
    }

    /// Probe and select.
    @ViewBuilder private var probeRow: some View {
        row {
            Button("Probe") { send("compass.probe") }
                .accessibilityLabel("Probe the bearing under the needle")
                .accessibilityValue("Bearing \(mirror.bearing), \(mirror.allowance - mirror.spent) units left")
            Button("Select") { send("compass.select", [Double(mirror.bearing), Double(mirror.pickedBand)]) }
                .accessibilityLabel("Select the bearing under the needle with the picked band")
                .accessibilityValue("Bearing \(mirror.bearing), band \(mirror.pickedBand + 1)")
        }
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        row {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last turn")
                .accessibilityValue(Self.progressValue(mirror))
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the turn")
                .accessibilityValue(Self.progressValue(mirror))
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
                .accessibilityValue(Self.progressValue(mirror))
            Button("Reset view") { presenter.resetView() }
                .accessibilityLabel("Return the camera to the authored view")
                .accessibilityValue("Bearing \(mirror.bearing) of 96")
        }
    }

    /// Sends `control`; a refusal is shown and announced in words.
    private func send(_ control: String, _ values: [Double] = []) {
        presenter.send(control, values, port: port)
    }
}
#endif
