// WaveKnotKeeperControls — feature 323 (R02-G03-03) T-R02G0303-006 (FR-R02G0303-005; clarification Q5). The minimal
// control panel: a point picker (selects a control point, presentation only), six direction buttons that move the
// selected point one lattice step, undo, redo and next level, each with an accessibility label and value; every change
// is a kernel action sent through the action port. Dragging handles, orbit and gestures come in R02-G03-04; full
// accessibility in R02-G03-06.
// Feature 325 (R02-G03-05) T-R02G0305-005 (FR-R02G0305-001 … 005): the tutorial instruction with Dismiss, a Hint button
// that reveals the next hint level, the failure explanation with Undo and Retry, the goal (moves allowed, best
// possible), the mode (Campaign, Daily, Practice) and a level picker of the open levels by band with their stars. The
// body is split into small sections so the type checker stays fast. Every text is plain panel text read by VoiceOver.
#if os(iOS)
import SwiftUI
import VisualCoreExperienceHost
import WaveKnotKeeperCore

/// The control panel of Wave Knot Keeper.
struct WaveKnotKeeperControls: View {
    let port: ExperienceActionPort
    let mirror: WaveKnotKeeperMirror
    /// The presenter (feature 325): hints, retry, the daily date and "Reset view" (feature 324).
    let presenter: WaveKnotKeeperPresenter

    /// The button titles and spoken names of the six directions, in `WaveKnotKeeperDirection.allCases` order.
    static let titles: [String] = ["+x", "−x", "+y", "−y", "Over", "Under"]
    static let spoken: [String] = ["right", "left", "up", "down", "towards you (over)", "away from you (under)"]

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                teachingSection
                failureSection
                hintRow
                pointPicker
                directionRow
                playRow
                modeRow
                levelMenu
            }
            .padding()
        }
    }

    /// The level, moves and signature lines.
    @ViewBuilder private var header: some View {
        Text("Level \(mirror.levelNumber) · moves \(mirror.spent) of \(mirror.allowance)")
            .font(.headline)
        Text("Crossings \(mirror.crossings), writhe \(mirror.writhe) · target \(mirror.targetCrossings), \(mirror.targetWrithe)")
            .font(.subheadline)
        if let message = mirror.message {
            Text(message).font(.footnote)
        }
    }

    /// The goal line and the tutorial instruction with Dismiss (feature 325).
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

    /// The failure explanation with Undo and Retry (feature 325).
    @ViewBuilder private var failureSection: some View {
        if let failure = mirror.failureText {
            Text(failure).font(.callout)
            HStack(spacing: 16) {
                Button("Undo") { send("play.undo") }
                    .accessibilityLabel("Undo the last move")
                Button("Retry") { presenter.retry(port: port) }
                    .accessibilityLabel("Retry the level")
            }
        }
    }

    /// The Hint button and the hint revealed so far (feature 325).
    @ViewBuilder private var hintRow: some View {
        HStack(spacing: 12) {
            Button("Hint") { presenter.showHint(port: port) }
                .accessibilityLabel("Show a hint")
                .accessibilityValue(mirror.hintLevel == 0 ? "none shown" : "level \(mirror.hintLevel) of 3")
            if let hint = mirror.hintText { Text(hint).font(.callout) }
        }
    }

    /// Campaign, Daily and Practice (feature 325).
    @ViewBuilder private var modeRow: some View {
        HStack(spacing: 16) {
            Button("Campaign") { send("mode.campaign") }
                .accessibilityLabel("Play the campaign")
                .accessibilityAddTraits(mirror.mode == .campaign ? .isSelected : [])
            Button("Daily") { presenter.playDaily(port: port) }
                .accessibilityLabel("Play today's daily level")
                .accessibilityAddTraits(Self.isDaily(mirror.mode) ? .isSelected : [])
            Button("Practice") { send("mode.practice") }
                .accessibilityLabel("Practise this level with more moves")
                .accessibilityAddTraits(mirror.mode == .practice ? .isSelected : [])
        }
    }

    /// The level picker: the open levels by band of 20, with their stars (feature 325).
    @ViewBuilder private var levelMenu: some View {
        Menu("Levels") {
            ForEach(0..<5, id: \.self) { band in
                Section("Band \(band + 1)") {
                    ForEach((band * 20 + 1)...(band * 20 + 20), id: \.self) { level in
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

    /// The goal line: moves allowed, the best possible and the mode.
    static func goal(_ mirror: WaveKnotKeeperMirror) -> String {
        let mode: String
        switch mirror.mode {
        case .campaign: mode = "Campaign"
        case .practice: mode = "Practice"
        case .daily: mode = "Daily level"
        }
        return "\(mode) · goal: \(mirror.allowance) moves allowed, best possible \(mirror.shortest)"
    }

    /// Whether `mode` is daily.
    static func isDaily(_ mode: WaveKnotKeeperMode) -> Bool {
        if case .daily = mode { return true }
        return false
    }

    /// A level picker entry: "Level 7 · 3 stars", or "Level 7" when unsolved.
    static func levelTitle(_ level: Int, stars: Int?) -> String {
        guard let stars else { return "Level \(level)" }
        return "Level \(level) · \(stars) \(stars == 1 ? "star" : "stars")"
    }

    /// The point picker: previous and next point.
    @ViewBuilder private var pointPicker: some View {
        if mirror.pointCount > 0 {
            Stepper("Point \(mirror.selected + 1) of \(mirror.pointCount)",
                    onIncrement: { select((mirror.selected + 1) % mirror.pointCount) },
                    onDecrement: { select((mirror.selected + mirror.pointCount - 1) % mirror.pointCount) })
                .accessibilityLabel("Selected point")
                .accessibilityValue("\(mirror.selected + 1) of \(mirror.pointCount)")
        }
    }

    /// One button per direction, moving the selected point one step.
    @ViewBuilder private var directionRow: some View {
        HStack(spacing: 12) {
            ForEach(0..<WaveKnotKeeperDirection.allCases.count, id: \.self) { index in
                Button(Self.titles[index]) { send("point.move", [Double(mirror.selected), Double(index)]) }
                    .accessibilityLabel("Move the selected point \(Self.spoken[index])")
                    .accessibilityValue("Point \(mirror.selected + 1)")
            }
        }
    }

    /// Undo, redo and next level.
    @ViewBuilder private var playRow: some View {
        HStack(spacing: 16) {
            Button("Undo") { send("play.undo") }
                .accessibilityLabel("Undo the last move")
            Button("Redo") { send("play.redo") }
                .accessibilityLabel("Redo the move")
            Button("Next level") { send("level.next") }
                .accessibilityLabel("Go to the next level")
            Button("Reset view") { presenter.resetView() }
                .accessibilityLabel("Return the camera to the authored view")
        }
    }

    /// Selects point `index` (no move).
    private func select(_ index: Int) {
        send("point.select", [Double(index)])
    }

    /// Sends `control` and shows a refusal.
    private func send(_ control: String, _ values: [Double] = []) {
        presenter.send(control, values, port: port)
    }
}
#endif
