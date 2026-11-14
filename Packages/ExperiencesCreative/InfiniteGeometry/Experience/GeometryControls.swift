// GeometryControls — feature 040 (A05-P01) T-A05-105 (FR-A05-120, FR-A05-121). The native controls of Infinite
// Geometry: the four curated presets, the symmetry order (disabled for the tilings, whose lattice fixes it), the
// repetitions, the scale, the palette and a new motif seed. Every change is an action through the port; every control
// has a VoiceOver label, an identifier from the port, a hit area of at least 44 by 44 points and text that wraps.
import InfiniteGeometryCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreParameters

/// The controls of Infinite Geometry.
struct GeometryControls: View {
    let port: ExperienceActionPort
    let mirror: GeometryMirror

    var body: some View {
        Group {
            if let core = mirror.core {
                content(core)
            } else {
                ProgressView().accessibilityLabel(Text(verbatim: "Loading"))
            }
        }
    }

    @ViewBuilder private func content(_ core: GeometryCore) -> some View {
        let preset = core.preset
        VStack(alignment: .leading, spacing: 16) {
            section("Preset") {
                ForEach(Array(GeometryPreset.curated.enumerated()), id: \.offset) { index, curated in
                    choice(GeometryCore.kindName(curated.kind), selected: core.presetIndex == index,
                           identifier: "preset.\(index)") {
                        if core.presetIndex != index { _ = port.send("preset.select", [Double(index)]) }
                    }
                }
                Text(verbatim: "Symmetry: \(GeometryCore.symmetryText(preset)); \(core.elementCount) elements")
                    .font(.footnote).accessibilityIdentifier(port.identifier("summary"))
            }
            section("Symmetry") {
                stepper("Symmetry order", identifier: "symmetry.order", value: preset.order,
                        range: GeometryPreset.orderRange,
                        text: preset.usesOrder ? "\(preset.order)-fold" : "Fixed by the lattice",
                        hint: preset.usesOrder ? "Sets the number of symmetric copies"
                            : "A tiling has its lattice's symmetry")
                    .disabled(!preset.usesOrder)
                stepper("Repetitions", identifier: "repeats.set", value: preset.repeats,
                        range: GeometryPreset.repeatsRange, text: "\(preset.repeats)",
                        hint: "Sets the number of rings around the centre")
                slider("Scale", identifier: "scale.set", value: preset.scale, range: GeometryPreset.scaleRange,
                       text: String(format: "×%.2f", preset.scale))
            }
            section("Palette") {
                ForEach(Array(Palette.builtIns.enumerated()), id: \.offset) { index, palette in
                    if GeometryPreset.paletteRange.contains(index) {
                        choice(palette.name, selected: preset.palette == index, identifier: "palette.\(palette.id)") {
                            if preset.palette != index { _ = port.send("palette.set", [Double(index)]) }
                        }
                    }
                }
            }
            section("Motif") {
                button("New motif", identifier: "reseed", hint: "Draws a new motif with the next seed") {
                    _ = port.send("reseed")
                }
            }
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

    private func stepper(_ title: String, identifier: String, value: Int, range: ClosedRange<Int>, text: String,
                         hint: String) -> some View {
        Stepper(value: Binding(get: { value }, set: { _ = port.send(identifier, [Double($0)]) }), in: range) {
            HStack {
                Text(verbatim: title).font(.body)
                Spacer()
                Text(verbatim: text).font(.subheadline.monospacedDigit()).multilineTextAlignment(.trailing)
            }
        }
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: text))
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(identifier))
    }

    private func slider(_ title: String, identifier: String, value: Double, range: ClosedRange<Double>,
                        text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(verbatim: title).font(.body)
                Spacer()
                Text(verbatim: text).font(.subheadline.monospacedDigit())
            }
            Slider(value: Binding(get: { value }, set: { _ = port.send(identifier, [$0]) }), in: range)
                .frame(minHeight: 44)
                .accessibilityLabel(Text(verbatim: title))
                .accessibilityValue(Text(verbatim: text))
                .accessibilityIdentifier(port.identifier(identifier))
        }
    }

    private func choice(_ title: String, selected: Bool, identifier: String, action: @escaping () -> Void) -> some View {
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

    private func button(_ title: String, identifier: String, hint: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title).font(.body).frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(identifier))
    }
}
