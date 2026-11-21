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
            }
            .padding()
        }
    }

    /// The level, units and bearing lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · units \(mirror.spent) of \(mirror.allowance)")
            .font(.headline)
        Text("Bearing \(mirror.bearing) · band \(mirror.bandUnderNeedle + 1) · clues \(mirror.clueCount)")
            .font(.subheadline)
        if let message = mirror.message {
            Text(message).font(.footnote)
        }
    }

    /// The goal line and the tutorial instruction with Dismiss (feature 335).
    @ViewBuilder private var teachingSection: some View {
        Text(Self.goal(mirror)).font(.subheadline)
        if let instruction = mirror.instruction {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(instruction).font(.callout)
                Button("Dismiss") { presenter.dismissTutorial(port: port) }
                    .accessibilityLabel("Dismiss the tutorial")
            }
        }
    }

    /// The failure explanation with Retry (feature 335; probes and selections cannot be undone).
    @ViewBuilder private var failureSection: some View {
        if let failure = mirror.failureText {
            Text(failure).font(.callout)
            Button("Retry") { presenter.retry(port: port) }
                .accessibilityLabel("Retry the level")
        }
    }

    /// The Hint button and the hint revealed so far (feature 335).
    @ViewBuilder private var hintRow: some View {
        HStack(spacing: 12) {
            Button("Hint") { presenter.showHint(port: port) }
                .accessibilityLabel("Show a hint")
                .accessibilityValue(mirror.hintLevel == 0 ? "none shown" : "level \(mirror.hintLevel) of 3")
            if let hint = mirror.hintText { Text(hint).font(.callout) }
        }
    }

    /// Campaign, Daily and Practice (feature 335).
    @ViewBuilder private var modeRow: some View {
        HStack(spacing: 16) {
            Button("Campaign") { send("mode.campaign") }
                .accessibilityLabel("Play the campaign")
                .accessibilityAddTraits(mirror.mode == .campaign ? .isSelected : [])
            Button("Daily") { presenter.playDaily(port: port) }
                .accessibilityLabel("Play today's daily level")
                .accessibilityAddTraits(Self.isDaily(mirror.mode) ? .isSelected : [])
            Button("Practice") { send("mode.practice") }
                .accessibilityLabel("Practise this level with more units")
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
        HStack(spacing: 12) {
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
                onIncrement: { mirror.pickedBand = (mirror.pickedBand + 1) % 24 },
                onDecrement: { mirror.pickedBand = (mirror.pickedBand + 23) % 24 })
            .accessibilityLabel("Hue band to select")
            .accessibilityValue("Band \(mirror.pickedBand + 1) of 24")
    }

    /// Probe and select.
    @ViewBuilder private var probeRow: some View {
        HStack(spacing: 16) {
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
        HStack(spacing: 16) {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last turn")
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the turn")
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
            Button("Reset view") { presenter.resetView() }
                .accessibilityLabel("Return the camera to the authored view")
        }
    }

    /// Sends `control` and shows a refusal.
    private func send(_ control: String, _ values: [Double] = []) {
        presenter.send(control, values, port: port)
    }
}
#endif
