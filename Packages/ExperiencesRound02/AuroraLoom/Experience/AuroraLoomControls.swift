// AuroraLoomControls — feature 303 (R02-G01-03) T-R02G0103-006 (FR-R02G0103-005; clarification Q5). The minimal control
// panel: one row per ribbon with a wave and a phase stepper (0 … 15) and undo and redo, each with an accessibility label;
// every change is a kernel move sent through the action port. Gestures, dials, anchors and the camera come in
// R02-G01-04; full accessibility in R02-G01-06.
#if os(iOS)
import AuroraLoomCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Aurora Loom.
struct AuroraLoomControls: View {
    let port: ExperienceActionPort
    let mirror: AuroraLoomMirror

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Level \(mirror.levelNumber) · moves \(mirror.spent) of \(mirror.allowance)")
                .font(.headline)
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
            }
        }
        .padding()
    }

    /// Sends a move of `ribbon`'s control to `step`, wrapping 0 … 15.
    private func move(_ ribbon: Int, control: Int, to step: Int) {
        let wrapped = (step % 16 + 16) % 16
        _ = port.send("ribbon.move", [Double(ribbon), Double(control), Double(wrapped)])
    }
}
#endif
