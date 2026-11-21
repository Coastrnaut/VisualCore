// LissajousLabyrinthControls — feature 313 (R02-G02-03) T-R02G0203-006 (FR-R02G0203-005; clarification Q5). The minimal
// control panel: a stepper for each of the four dials (frequency A and B 1 … 9, phase A and C 0 … 15), undo, redo and
// next level, each with an accessibility label and value. Feature 314 (R02-G02-04) T-R02G0204-005 (FR-R02G0204-005,
// 006; clarification Q4): the steppers set pending values (no action; the value shown is the pending one, the title adds
// the current one) and select their dial; Apply sends each pending change as one action in the planner's order and Clear
// drops them, both shown only while something is pending; "Reset view" returns the camera to the authored view.
// Feature 315 (R02-G02-05) T-R02G0205-005 (FR-R02G0205-001 … 005): the tutorial instruction with Dismiss, a Hint button
// that reveals the next hint level, the failure explanation with Undo and Retry, the goal (actions allowed, best
// possible), the mode (Campaign, Daily, Practice) and a level picker of the open levels by band with their stars. Every
// text is plain panel text read by VoiceOver; full accessibility comes in R02-G02-06.
#if os(iOS)
import LissajousLabyrinthCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Lissajous Labyrinth.
struct LissajousLabyrinthControls: View {
    let port: ExperienceActionPort
    let mirror: LissajousLabyrinthMirror
    let presenter: LissajousLabyrinthPresenter

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Level \(mirror.levelNumber) · actions \(mirror.spent) of \(mirror.allowance)")
                    .font(.headline)
                Text(Self.goal(mirror)).font(.subheadline)
                if let instruction = mirror.instruction {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(instruction).font(.callout)
                        Button("Dismiss") { presenter.dismissTutorial(port: port) }
                            .accessibilityLabel("Dismiss the tutorial")
                    }
                }
                if let failure = mirror.failureText {
                    Text(failure).font(.callout)
                    HStack(spacing: 16) {
                        Button("Undo") { presenter.send("play.undo", port: port) }
                            .accessibilityLabel("Undo the last change")
                        Button("Retry") { presenter.retry(port: port) }
                            .accessibilityLabel("Retry the level")
                    }
                }
                HStack(spacing: 12) {
                    Button("Hint") { presenter.showHint(port: port) }
                        .accessibilityLabel("Show a hint")
                        .accessibilityValue(mirror.hintLevel == 0 ? "none shown" : "level \(mirror.hintLevel) of 3")
                    if let hint = mirror.hintText { Text(hint).font(.callout) }
                }
                if let message = mirror.message {
                    Text(message).font(.footnote)
                }
                if let dials = mirror.dials {
                    ForEach(0..<4, id: \.self) { index in
                        let dial: LissajousLabyrinthDial = LissajousLabyrinthDial.allCases[index]
                        let current: Int = dials[dial]
                        let shown: Int = mirror.pending.values[dial] ?? current
                        Stepper(Self.title(dial, shown: shown, current: current),
                                onIncrement: { presenter.stepPending(dial, by: 1) },
                                onDecrement: { presenter.stepPending(dial, by: -1) })
                            .accessibilityLabel(LissajousLabyrinthPresenter.title(dial))
                            .accessibilityValue(shown == current ? "\(shown)" : "\(shown), pending; now \(current)")
                    }
                    if !mirror.pending.isEmpty {
                        HStack(spacing: 16) {
                            Button("Apply") { presenter.applyPending(port: port) }
                                .accessibilityLabel("Apply the pending dial values")
                            Button("Clear") { presenter.clearPending() }
                                .accessibilityLabel("Clear the pending dial values")
                        }
                    }
                }
                HStack(spacing: 16) {
                    Button("Undo") { presenter.send("play.undo", port: port) }
                        .accessibilityLabel("Undo the last change")
                    Button("Redo") { presenter.send("play.redo", port: port) }
                        .accessibilityLabel("Redo the change")
                    Button("Next level") { presenter.send("level.next", port: port) }
                        .accessibilityLabel("Go to the next level")
                    Button("Reset view") { presenter.resetView() }
                        .accessibilityLabel("Return the camera to the authored view")
                }
                HStack(spacing: 16) {
                    Button("Campaign") { presenter.send("mode.campaign", port: port) }
                        .accessibilityLabel("Play the campaign")
                        .accessibilityAddTraits(mirror.mode == .campaign ? .isSelected : [])
                    Button("Daily") { presenter.playDaily(port: port) }
                        .accessibilityLabel("Play today's daily level")
                        .accessibilityAddTraits(Self.isDaily(mirror.mode) ? .isSelected : [])
                    Button("Practice") { presenter.send("mode.practice", port: port) }
                        .accessibilityLabel("Practise this level with more actions")
                        .accessibilityAddTraits(mirror.mode == .practice ? .isSelected : [])
                }
                Menu("Levels") {
                    ForEach(0..<5, id: \.self) { band in
                        Section("Band \(band + 1)") {
                            ForEach((band * 20 + 1)...(band * 20 + 20), id: \.self) { level in
                                if level <= mirror.frontier {
                                    Button(Self.levelTitle(level, stars: mirror.stars[level])) {
                                        presenter.send("level.select", [Double(level)], port: port)
                                    }
                                }
                            }
                        }
                    }
                }
                .accessibilityLabel("Choose an open level")
            }
            .padding()
        }
    }

    /// The goal line: actions allowed, the best possible and the mode.
    static func goal(_ mirror: LissajousLabyrinthMirror) -> String {
        let mode: String
        switch mirror.mode {
        case .campaign: mode = "Campaign"
        case .practice: mode = "Practice"
        case .daily: mode = "Daily level"
        }
        return "\(mode) · goal: \(mirror.allowance) actions allowed, best possible \(mirror.shortest)"
    }

    /// Whether `mode` is daily.
    static func isDaily(_ mode: LissajousLabyrinthMode) -> Bool {
        if case .daily = mode { return true }
        return false
    }

    /// A level picker entry: "Level 7 · 3 stars", or "Level 7" when unsolved.
    static func levelTitle(_ level: Int, stars: Int?) -> String {
        guard let stars else { return "Level \(level)" }
        return "Level \(level) · \(stars) \(stars == 1 ? "star" : "stars")"
    }

    /// A stepper's title: "Phase C 12" when nothing is pending for it, "Phase C 3 (now 12)" when the pending value
    /// differs.
    static func title(_ dial: LissajousLabyrinthDial, shown: Int, current: Int) -> String {
        let name = LissajousLabyrinthPresenter.title(dial)
        return shown == current ? "\(name) \(shown)" : "\(name) \(shown) (now \(current))"
    }
}
#endif
