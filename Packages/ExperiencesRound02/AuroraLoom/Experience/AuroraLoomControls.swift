// AuroraLoomControls — feature 303 (R02-G01-03) T-R02G0103-006 (FR-R02G0103-005; clarification Q5). The minimal control
// panel: one row per ribbon with a wave and a phase stepper (0 … 15) and undo and redo, each with an accessibility label;
// every change is a kernel move sent through the action port. Gestures, dials, anchors and the camera come in
// R02-G01-04; full accessibility in R02-G01-06. Feature 304 (R02-G01-04) T-R02G0104-004: a stepper selects its ribbon,
// "Reset view" returns the camera to the authored pose, the selection is announced and a refused move is shown.
// Feature 305 (R02-G01-05) T-R02G0105-005: the tutorial instruction with "Skip tutorial", the goal (allowance, best
// possible) and stars, a Hint button revealing the next hint level, the failure explanation with Undo and Retry, a
// picker of the open levels and the Daily, Practice and Campaign modes.
// Feature 306 (R02-G01-06) T-R02G0106-006: the panel scrolls, uses Dynamic Type text styles, wraps button rows that do
// not fit, keeps a 520-point readable width on iPad, labels every control with its value, routes every action through
// the presenter (refusals are announced and felt), steps with `adjust(ribbon:control:by:port:)` and has a Sound toggle;
// it reports appearing, disappearing and the scene phase for the ambient loop.
#if os(iOS)
import AuroraLoomCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Aurora Loom.
struct AuroraLoomControls: View {
    let port: ExperienceActionPort
    let mirror: AuroraLoomMirror
    /// The presenter: every action goes through it so refusals are announced and felt (feature 306).
    let presenter: AuroraLoomPresenter
    @Environment(\.scenePhase) private var scenePhase

    /// The mode's name.
    private var modeName: String {
        switch mirror.mode {
        case .campaign: "Campaign"
        case .practice: "Practice"
        case .daily: "Daily"
        }
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Level \(mirror.levelNumber) · band \(mirror.band) · \(modeName)")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text("Moves \(mirror.spent) of \(mirror.allowance) · best possible \(mirror.shortest)"
                     + (mirror.stars.map { " · \($0) of 3 stars" } ?? ""))
                    .font(.subheadline)
                if let instruction = mirror.instruction {
                    Text(instruction).font(.body)
                    Button("Skip tutorial") { presenter.send("tutorial.dismiss", port: port) }
                        .accessibilityLabel("Skip the tutorial")
                }
                Text("Ribbon \(mirror.selectedRibbon + 1) selected")
                    .font(.footnote)
                    .accessibilityLabel("Ribbon \(mirror.selectedRibbon + 1) selected")
                if let message = mirror.message {
                    Text(message).font(.footnote)
                }
                if let hint = mirror.hintText {
                    Text("Hint \(mirror.hintLevel) of 3: \(hint)")
                        .font(.body)
                        .accessibilityLabel("Hint \(mirror.hintLevel) of 3: \(hint)")
                }
                if let failure = mirror.failureText {
                    Text(failure).font(.body)
                    HStack(spacing: 16) {
                        Button("Undo") { presenter.send("play.undo", port: port) }
                            .accessibilityLabel("Undo the last move")
                        Button("Retry") { presenter.retry(port: port) }
                            .accessibilityLabel("Start this level again")
                    }
                }
                if let steps = mirror.steps {
                    ForEach(0..<3, id: \.self) { ribbon in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ribbon \(ribbon + 1)").font(.subheadline)
                            Stepper("Wave \(steps.wave[ribbon])",
                                    onIncrement: { presenter.adjust(ribbon: ribbon, control: 0, by: 1, port: port) },
                                    onDecrement: { presenter.adjust(ribbon: ribbon, control: 0, by: -1, port: port) })
                                .accessibilityLabel("Ribbon \(ribbon + 1) wave")
                                .accessibilityValue("\(steps.wave[ribbon])")
                            Stepper("Phase \(steps.phase[ribbon])",
                                    onIncrement: { presenter.adjust(ribbon: ribbon, control: 1, by: 1, port: port) },
                                    onDecrement: { presenter.adjust(ribbon: ribbon, control: 1, by: -1, port: port) })
                                .accessibilityLabel("Ribbon \(ribbon + 1) phase")
                                .accessibilityValue("\(steps.phase[ribbon])")
                        }
                    }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { playButtons }
                    VStack(alignment: .leading, spacing: 8) { playButtons }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { modeButtons }
                    VStack(alignment: .leading, spacing: 8) { modeButtons }
                }
                Toggle("Sound", isOn: Binding(get: { mirror.soundOn }, set: { presenter.setSound(on: $0) }))
                    .accessibilityLabel("Ambient sound")
                    .accessibilityValue(mirror.soundOn ? "On" : "Off")
            }
            .padding()
            .frame(maxWidth: Self.maximumWidth, alignment: .leading)
        }
        .onAppear { presenter.controlsAppeared() }
        .onDisappear { presenter.controlsDisappeared() }
        .onChange(of: scenePhase) { _, phase in presenter.sceneActive(phase == .active) }
    }

    /// The panel's readable width on iPad (clarification Q5).
    static let maximumWidth: CGFloat = 520

    /// Undo, redo, next level, reset view and hint.
    @ViewBuilder private var playButtons: some View {
        Button("Undo") { presenter.send("play.undo", port: port) }
            .accessibilityLabel("Undo the last move")
        Button("Redo") { presenter.send("play.redo", port: port) }
            .accessibilityLabel("Redo the move")
        Button("Next level") { presenter.send("level.next", port: port) }
            .accessibilityLabel("Go to the next level")
        Button("Reset view") { presenter.resetView() }
            .accessibilityLabel("Reset the camera view")
        Button("Hint") { presenter.showHint() }
            .disabled(mirror.stage != .playing)
            .accessibilityLabel("Show the next hint")
    }

    /// The level picker and the three modes.
    @ViewBuilder private var modeButtons: some View {
        Menu("Level") {
            ForEach(1...max(mirror.frontier, 1), id: \.self) { level in
                Button("Level \(level)") { presenter.send("level.select", [Double(level)], port: port) }
            }
        }
        .accessibilityLabel("Choose an open level")
        .accessibilityValue("Level \(mirror.levelNumber)")
        Button("Daily") { presenter.playDaily(port: port) }
            .accessibilityLabel("Play today's daily level")
        Button("Practice") { presenter.send("mode.practice", port: port) }
            .accessibilityLabel("Practice this level without a move limit")
        Button("Campaign") { presenter.send("mode.campaign", port: port) }
            .accessibilityLabel("Return to the campaign")
    }
}
#endif
