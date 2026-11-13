// FluidArtControls — feature 193 (UA-F07) T-U07-021 (FR-U07-002, FR-U07-020, FR-U07-022; rule E-12). The native
// controls of Fluid Art Playground inside the one app: splash (the control alternative to swiping), pause, step,
// reset, capture, and the adjust panel's palette, brush, motion, quality, edges and detail. Every change is an action
// through the port; the view reads the state from the presenter's mirror. Every control has a VoiceOver label and a
// hit area of at least 44 by 44 points, and its text wraps at the largest sizes.
import CoreTransferable
import FluidArtPlaygroundCore
import SwiftUI
import UniformTypeIdentifiers
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreScenes

/// A PNG made by capture, offered to the system's share interface without a file of the app's own.
struct FluidCapture: Transferable {
    /// The PNG data.
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
    }
}

/// The controls of Fluid Art Playground.
struct FluidArtControls: View {
    let port: ExperienceActionPort
    let mirror: FluidArtMirror

    /// The long edge of a capture in pixels, as the standalone app's `CaptureModel.longEdge`.
    static let captureLongEdge = 2048

    @Environment(\.experienceStillRenderer) private var still
    @State private var captured: FluidCapture?
    @State private var captureError: String?

    var body: some View {
        Group {
            if let core = mirror.core {
                content(core)
            } else {
                ProgressView().accessibilityLabel(Text(verbatim: "Loading"))
            }
        }
    }

    @ViewBuilder private func content(_ core: FluidArtCore) -> some View {
        let control = SimulationControl(paused: core.paused)
        VStack(alignment: .leading, spacing: 16) {
            section("Canvas") {
                button("Splash", identifier: "splash", hint: "Adds a burst of dye in the middle") { port.send("splash") }
                button(control.pauseLabel, identifier: "pause") { port.send(core.paused ? "resume" : "pause") }
                button("Step", identifier: "step", hint: control.stepHint) { port.send("step") }
                    .disabled(!control.stepEnabled)
                button("Reset", identifier: "reset", hint: "Back to the starting picture") { port.send("reset") }
            }
            section("Palette") {
                ForEach(Array(FluidPalette.all.enumerated()), id: \.offset) { index, palette in
                    choice(palette.name, selected: core.configuration.paletteID == palette.id,
                           identifier: "palette." + palette.id) { port.send("palette", [Double(index)]) }
                }
            }
            section("Brush") {
                slider("Brush size", identifier: "brush", value: core.configuration.brushRadius,
                       range: FluidConfiguration.brushRadiusRange,
                       text: "\(Int((core.configuration.brushRadius * 100).rounded()))% of the canvas")
            }
            section("Motion") {
                slider("Viscosity", identifier: "viscosity", value: core.configuration.viscosity,
                       range: FluidConfiguration.viscosityRange,
                       text: String(format: "%.2f", core.configuration.viscosity))
                slider("Dye fade", identifier: "dyeFade", value: core.configuration.dyeDissipation,
                       range: FluidConfiguration.dissipationRange,
                       text: String(format: "%.1f per second", core.configuration.dyeDissipation))
                slider("Motion fade", identifier: "motionFade", value: core.configuration.velocityDissipation,
                       range: FluidConfiguration.dissipationRange,
                       text: String(format: "%.1f per second", core.configuration.velocityDissipation))
            }
            section("Quality") {
                slider("Quality", identifier: "quality", value: Double(core.configuration.pressureIterations),
                       range: 1...80,
                       text: "\(core.configuration.pressureIterations) "
                           + (core.configuration.pressureIterations == 1 ? "iteration" : "iterations"))
            }
            section("Edges") {
                ForEach(Array(BoundaryMode.allCases.enumerated()), id: \.offset) { index, mode in
                    choice(mode == .walls ? "Walls" : "Open", selected: core.configuration.boundaryMode == mode,
                           identifier: "edges." + mode.rawValue) { port.send("edges", [Double(index)]) }
                }
            }
            section("Simulation detail") {
                let current = FluidDetail(grid: core.configuration)
                ForEach(Array(FluidDetail.allCases.enumerated()), id: \.offset) { index, level in
                    choice(level.accessibilityValue, selected: current == level, identifier: "detail." + level.rawValue) {
                        if current != level { port.send("detail", [Double(index)]) }
                    }
                }
            }
            section("Tuning") {
                button("Reset tuning", identifier: "tuningReset", hint: "Every tuning value back to its default") {
                    port.send("tuningReset")
                }
            }
            section("Capture") {
                HStack {
                    button("Capture", identifier: "capture", hint: "Makes a picture of the canvas") { capture() }
                    if let captured {
                        ShareLink(item: captured, preview: SharePreview(Text(verbatim: "Fluid art")))
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel(Text(verbatim: "Share picture"))
                            .accessibilityIdentifier(port.identifier("capture.share"))
                    }
                }
                if let captureError {
                    Text(verbatim: captureError).font(.footnote).foregroundStyle(.red)
                        .accessibilityIdentifier(port.identifier("capture.message"))
                }
            }
        }
    }

    /// Renders the current picture at the capture size in the canvas's aspect and offers it to the share interface.
    private func capture() {
        captured = nil
        guard let still else {
            captureError = "The picture cannot be made now."
            return
        }
        let size = mirror.drawableSize
        let width = max(1.0, Double(size.width)), height = max(1.0, Double(size.height))
        let scale = Double(Self.captureLongEdge) / max(width, height)
        do {
            let image = try still(width: max(1, Int((width * scale).rounded())), height: max(1, Int((height * scale).rounded())))
            captured = FluidCapture(data: try StillImageEncoder.pngData(image))
            captureError = nil
        } catch {
            captureError = "The picture could not be captured. Please try again."
        }
    }

    // MARK: Building blocks

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: title).font(.headline).accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func slider(_ title: String, identifier: String, value: Double, range: ClosedRange<Double>,
                        text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(verbatim: title).font(.body)
                Spacer()
                Text(verbatim: text).font(.subheadline.monospacedDigit())
            }
            Slider(value: Binding(get: { value }, set: { port.send(identifier, [$0]) }), in: range)
                .frame(minHeight: 44)
                .accessibilityLabel(Text(verbatim: title))
                .accessibilityValue(Text(verbatim: text))
                .accessibilityIdentifier(port.identifier(identifier))
        }
    }

    private func choice(_ title: String, selected: Bool, identifier: String,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(verbatim: title).font(.body).multilineTextAlignment(.leading)
                Spacer()
                if selected { Image(systemName: "checkmark").accessibilityHidden(true) }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(port.identifier(identifier))
    }

    private func button(_ title: String, identifier: String, hint: String? = nil,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title).font(.body).frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityHint(Text(verbatim: hint ?? ""))
        .accessibilityIdentifier(port.identifier(identifier))
    }
}
