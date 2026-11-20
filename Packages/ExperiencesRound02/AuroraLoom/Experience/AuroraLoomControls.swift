// AuroraLoomControls — feature 303 (R02-G01-03) T-R02G0103-006 (FR-R02G0103-005; clarification Q5). The minimal control
// panel: one row per ribbon with a wave and a phase stepper (0 … 15) and undo and redo, each with an accessibility label;
// every change is a kernel move sent through the action port. Gestures, dials, anchors and the camera come in
// R02-G01-04; full accessibility in R02-G01-06. Feature 304 (R02-G01-04) T-R02G0104-004: a stepper selects its ribbon,
// "Reset view" returns the camera to the authored pose, the selection is announced and a refused move is shown.
// Feature 305 (R02-G01-05) T-R02G0105-005: the tutorial instruction with "Skip tutorial", the goal (allowance, best
// possible) and stars, a Hint button revealing the next hint level, the failure explanation with Undo and Retry, a
// picker of the open levels and the Daily, Practice and Campaign modes.
#if os(iOS)
import AuroraLoomCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Aurora Loom.
struct AuroraLoomControls: View {
    let port: ExperienceActionPort
    let mirror: AuroraLoomMirror
    /// Returns the camera to the authored pose.
    let resetView: () -> Void
    /// Selects a ribbon.
    let select: (Int) -> Void
    /// Reveals the next hint level.
    let showHint: () -> Void
    /// Starts the level again in its mode.
    let retry: () -> Void
    /// Plays today's daily level.
    let playDaily: () -> Void

    /// The mode's name.
    private var modeName: String {
        switch mirror.mode {
        case .campaign: "Campaign"
        case .practice: "Practice"
        case .daily: "Daily"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Level \(mirror.levelNumber) · band \(mirror.band) · \(modeName)")
                .font(.headline)
            Text("Moves \(mirror.spent) of \(mirror.allowance) · best possible \(mirror.shortest)"
                 + (mirror.stars.map { " · \($0) of 3 stars" } ?? ""))
                .font(.subheadline)
            if let instruction = mirror.instruction {
                HStack {
                    Text(instruction)
                    Button("Skip tutorial") { _ = port.send("tutorial.dismiss") }
                        .accessibilityLabel("Skip the tutorial")
                }
            }
            if let hint = mirror.hintText {
                Text("Hint \(mirror.hintLevel) of 3: \(hint)")
                    .accessibilityLabel("Hint \(mirror.hintLevel) of 3: \(hint)")
            }
            if let failure = mirror.failureText {
                VStack(alignment: .leading, spacing: 4) {
                    Text(failure)
                    HStack(spacing: 16) {
                        Button("Undo") { _ = port.send("play.undo") }
                            .accessibilityLabel("Undo the last move")
                        Button("Retry") { retry() }
                            .accessibilityLabel("Start this level again")
                    }
                }
            }
            Text("Ribbon \(mirror.selectedRibbon + 1) selected")
                .accessibilityLabel("Ribbon \(mirror.selectedRibbon + 1) selected")
            if let message = mirror.message {
                Text(message).font(.footnote)
            }
            if let steps = mirror.steps {
                ForEach(0..<3, id: \.self) { ribbon in
                    HStack(spacing: 12) {
                        Text("Ribbon \(ribbon + 1)").frame(minWidth: 72, alignment: .leading)
                        Stepper("Wave \(steps.wave[ribbon])",
                                onIncrement: { move(ribbon, control: 0, to: steps.wave[ribbon] + 1) },
                                onDecrement: { move(ribbon, control: 0, to: steps.wave[ribbon] - 1) })
                            .accessibilityLabel("Ribbon \(ribbon + 1) wave")
                            .accessibilityValue("\(steps.wave[ribbon])")
                        Stepper("Phase \(steps.phase[ribbon])",
                                onIncrement: { move(ribbon, control: 1, to: steps.phase[ribbon] + 1) },
                                onDecrement: { move(ribbon, control: 1, to: steps.phase[ribbon] - 1) })
                            .accessibilityLabel("Ribbon \(ribbon + 1) phase")
                            .accessibilityValue("\(steps.phase[ribbon])")
                    }
                }
            }
            HStack(spacing: 16) {
                Button("Undo") { _ = port.send("play.undo") }
                    .accessibilityLabel("Undo the last move")
                Button("Redo") { _ = port.send("play.redo") }
                    .accessibilityLabel("Redo the move")
                Button("Next level") { _ = port.send("level.next") }
                    .accessibilityLabel("Go to the next level")
                Button("Reset view") { resetView() }
                    .accessibilityLabel("Reset the camera view")
            }
            HStack(spacing: 16) {
                Button("Hint") { showHint() }
                    .disabled(mirror.stage != .playing)
                    .accessibilityLabel("Show the next hint")
                Menu("Level") {
                    ForEach(1...max(mirror.frontier, 1), id: \.self) { level in
                        Button("Level \(level)") { _ = port.send("level.select", [Double(level)]) }
                    }
                }
                .accessibilityLabel("Choose an open level")
                Button("Daily") { playDaily() }
                    .accessibilityLabel("Play today's daily level")
                Button("Practice") { _ = port.send("mode.practice") }
                    .accessibilityLabel("Practice this level without a move limit")
                Button("Campaign") { _ = port.send("mode.campaign") }
                    .accessibilityLabel("Return to the campaign")
            }
        }
        .padding()
    }

    /// Sends a move of `ribbon`'s control to `step`, wrapping 0 … 15.
    private func move(_ ribbon: Int, control: Int, to step: Int) {
        select(ribbon)
        let wrapped = (step % 16 + 16) % 16
        _ = port.send("ribbon.move", [Double(ribbon), Double(control), Double(wrapped)])
    }
}
#endif
