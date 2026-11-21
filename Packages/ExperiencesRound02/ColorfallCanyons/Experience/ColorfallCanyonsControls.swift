// ColorfallCanyonsControls — feature 343 (R02-G05-03) T-R02G0503-006 (FR-R02G0503-005; clarification Q5). The minimal
// control panel: a cell picker (previous and next carvable cell) with carve, one valve button per spring, time steps of 1
// and 10 ticks, run to the end (a step of the ticks left, at most 600), undo, redo and next level, each with an
// accessibility label and value; every change is a kernel action sent through the action port. Dragging sluice edits,
// tapping valves and orbit come in R02-G05-04; full accessibility in R02-G05-06.
#if os(iOS)
import ColorfallCanyonsCore
import SwiftUI
import VisualCoreExperienceHost

/// The control panel of Colorfall Canyons.
struct ColorfallCanyonsControls: View {
    let port: ExperienceActionPort
    let mirror: ColorfallCanyonsMirror

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                header
                carveRow
                valveRow
                timeRow
                playRow
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
        }
    }

    /// Sends `control` and shows a refusal.
    private func send(_ control: String, _ values: [Double] = []) {
        let result = port.send(control, values)
        mirror.message = result.isAccepted ? nil : "That change was refused: \(result.code)"
    }
}
#endif
