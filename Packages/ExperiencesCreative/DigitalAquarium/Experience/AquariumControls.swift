// AquariumControls — feature 068 (A09-P01) T-A09-103 (FR-A09-121, FR-A09-123). The native controls of Digital
// Aquarium in one section:
//   the habitat picker (`habitat.select`: the starter habitats of the bundled catalog, "Reef" and "Kelp"),
//   the lighting picker (`lighting.level`: Dim, Soft, Bright),
//   the pause toggle (`motion.pause`: "Pause motion"),
//   and the status line (`aquarium.status`: habitat, fish and plant counts, swimming or paused).
// Every control has an accessible label and value and an identifier from the port; hit areas are at least 44 points
// high and text wraps.
import SwiftUI
import DigitalAquariumCore
import VisualCoreExperienceHost

/// The controls of Digital Aquarium.
struct AquariumControls: View {
    let port: ExperienceActionPort
    let mirror: AquariumMirror

    /// The picker names of the lighting levels.
    static let lightingOptions = ["Dim", "Soft", "Bright"]

    /// The picker names of the starter habitats.
    static var habitatOptions: [String] { AquariumCore.catalog.habitats.map(\.name) }

    var body: some View {
        Group {
            if mirror.ready {
                content
            } else {
                ProgressView().accessibilityLabel(Text(verbatim: "Loading"))
            }
        }
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Aquarium").font(.headline).accessibilityAddTraits(.isHeader)
            choicePicker("Habitat", identifier: "habitat.select", selection: mirror.habitatIndex,
                         options: Self.habitatOptions,
                         hint: "Chooses a starter aquarium with its own fish, plants and water colour") { index in
                _ = port.send("habitat.select", [Double(index)])
            }
            choicePicker("Lighting", identifier: "lighting.level", selection: mirror.lightingLevel,
                         options: Self.lightingOptions, hint: "How bright the aquarium is lit") { index in
                _ = port.send("lighting.level", [Double(index)])
            }
            Toggle(isOn: Binding(get: { mirror.paused },
                                 set: { on in if on != mirror.paused { _ = port.send("motion.pause", [on ? 1 : 0]) } })) {
                Text(verbatim: "Pause motion").font(.body)
            }
            .frame(minHeight: 44)
            .accessibilityLabel(Text(verbatim: "Pause motion"))
            .accessibilityValue(Text(verbatim: mirror.paused ? "Paused" : "Swimming"))
            .accessibilityHint(Text(verbatim: "Stops and resumes the fish and the plants"))
            .accessibilityIdentifier(port.identifier("motion.pause"))
            Text(verbatim: Self.sentence(mirror.status))
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("aquarium.status"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `status` with a capital first letter ("Loading" when empty).
    static func sentence(_ status: String) -> String {
        guard let first = status.first else { return "Loading" }
        return first.uppercased() + String(status.dropFirst())
    }

    /// A menu picker over `options` whose selection is the index `selection`; a new index calls `send`.
    private func choicePicker(_ title: String, identifier: String, selection: Int, options: [String], hint: String,
                              send: @escaping (Int) -> Void) -> some View {
        Picker(selection: Binding(get: { selection },
                                  set: { index in if index != selection { send(index) } })) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, name in
                Text(verbatim: name).tag(index)
            }
        } label: {
            Text(verbatim: title)
        }
        .pickerStyle(.menu)
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: options.indices.contains(selection) ? options[selection] : ""))
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(identifier))
    }
}
