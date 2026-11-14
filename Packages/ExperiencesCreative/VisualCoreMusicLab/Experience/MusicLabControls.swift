// MusicLabControls — feature 047 (A06-P01) T-A06-104 (FR-A06-104, FR-A06-122). The native controls of VisualCore
// Music Lab: the three sources (Demo signal, Microphone, Choose file… through the system file importer, audio types
// only, read in place with security-scoped access), the demo mode (Melody, 440 Hz tone, 1 kHz tone, Silence), New
// melody, the status line and a plain message with a link to Settings when microphone access is off. The demo and mode
// buttons send actions through the port; the file and microphone choices go through the presenter, which opens the
// file or checks the permission first. Every control has a VoiceOver label, an identifier from the port, a hit area of
// at least 44 by 44 points and text that wraps.
// Feature 049 (A06-P03) T-A06-308 (FR-A06-312): the scene picker and the mapping editor — per parameter of the shown
// scene a feature picker (seven features), a gain slider (0…4, steps of 0.1) and the live value, and Reset mapping.
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisualCoreExperienceHost
import VisualCoreMusicLabCore

/// The controls of VisualCore Music Lab.
struct MusicLabControls: View {
    let port: ExperienceActionPort
    let presenter: MusicLabPresenter
    let mirror: MusicLabMirror

    @State private var importing = false

    var body: some View {
        Group {
            if let state = mirror.state {
                content(state)
            } else {
                ProgressView().accessibilityLabel(Text(verbatim: "Loading"))
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { presenter.chooseFile(url: url) }
        }
    }

    @ViewBuilder private func content(_ state: MusicLabState) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            section("Sound source") {
                choice("Demo signal", selected: state.source == .demo, identifier: "source.demo",
                       hint: "Draws the built-in signal; no permission needed") {
                    _ = port.send("source.demo")
                }
                choice("Microphone", selected: state.source == .microphone, identifier: "source.microphone",
                       hint: "Draws the live input; nothing is recorded or sent") {
                    Task { await presenter.chooseMicrophone() }
                }
                .disabled(mirror.isRequestingPermission)
                choice("Choose file…", selected: state.source == .file, identifier: "source.file",
                       hint: "Draws an audio file you pick; it is read in place, not copied") {
                    importing = true
                }
                Text(verbatim: "Playing: \(mirror.status)")
                    .font(.footnote)
                    .accessibilityIdentifier(port.identifier("status"))
                if let message = mirror.message {
                    Text(verbatim: message)
                        .font(.footnote).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(port.identifier("message"))
                    if mirror.showsSettingsLink, let url = URL(string: UIApplication.openSettingsURLString) {
                        Link(destination: url) {
                            Text(verbatim: "Open Settings").font(.body).frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel(Text(verbatim: "Open Settings"))
                        .accessibilityHint(Text(verbatim: "Opens VisualCore's settings to allow microphone access"))
                        .accessibilityIdentifier(port.identifier("settings"))
                    }
                }
            }
            section("Demo signal") {
                ForEach(Array(MusicLabState.demoModeNames.enumerated()), id: \.offset) { index, name in
                    choice(name, selected: state.demoMode == index, identifier: "demo.mode.\(index)",
                           hint: "Sets the demo signal") {
                        if state.demoMode != index { _ = port.send("demo.mode", [Double(index)]) }
                    }
                }
                button("New melody", identifier: "demo.reseed", hint: "Plays a new seeded melody") {
                    _ = port.send("demo.reseed")
                }
            }
            section("Scene") {
                ForEach(MusicLabScene.allCases, id: \.rawValue) { scene in
                    choice(scene.displayName, selected: state.scene == scene, identifier: "scene.\(scene.rawValue)",
                           hint: "Shows the \(scene.displayName) scene") {
                        if state.scene != scene { _ = port.send("scene.select", [Double(scene.rawValue)]) }
                    }
                }
            }
            mappingEditor(state)
        }
    }

    /// The mapping editor of the shown scene: one row per parameter and Reset mapping.
    @ViewBuilder private func mappingEditor(_ state: MusicLabState) -> some View {
        let scene = state.scene
        section("Mapping") {
            ForEach(Array(scene.parameters.enumerated()), id: \.offset) { slot, parameter in
                let choice = state.currentChoices[slot]
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(verbatim: parameter.title).font(.body)
                        Spacer()
                        Text(verbatim: valueText(slot))
                            .font(.footnote.monospacedDigit())
                            .accessibilityIdentifier(port.identifier("mapping.\(scene.rawValue).\(slot).value"))
                    }
                    Picker(selection: Binding(get: { choice.feature }, set: { feature in
                        _ = port.send("mapping.set", [Double(scene.rawValue), Double(slot), Double(feature), choice.gain])
                    })) {
                        ForEach(Array(MappingChoice.featureNames.enumerated()), id: \.offset) { index, name in
                            Text(verbatim: name).tag(index)
                        }
                    } label: {
                        Text(verbatim: "\(parameter.title) follows")
                    }
                    .frame(minHeight: 44)
                    .accessibilityLabel(Text(verbatim: "\(parameter.title) follows"))
                    .accessibilityIdentifier(port.identifier("mapping.\(scene.rawValue).\(slot).feature"))
                    Slider(value: Binding(get: { choice.gain }, set: { gain in
                        let stepped = (gain * 10).rounded() / 10
                        if stepped != choice.gain {
                            _ = port.send("mapping.set", [Double(scene.rawValue), Double(slot), Double(choice.feature),
                                                          stepped])
                        }
                    }), in: MappingChoice.gainRange, step: 0.1) {
                        Text(verbatim: "\(parameter.title) strength")
                    }
                    .frame(minHeight: 44)
                    .accessibilityLabel(Text(verbatim: "\(parameter.title) strength"))
                    .accessibilityValue(Text(verbatim: String(format: "%.1f", choice.gain)))
                    .accessibilityIdentifier(port.identifier("mapping.\(scene.rawValue).\(slot).gain"))
                }
            }
            button("Reset mapping", identifier: "mapping.reset", hint: "Restores this scene's default mapping") {
                _ = port.send("mapping.reset", [Double(scene.rawValue)])
            }
        }
    }

    /// The live value of parameter `slot`, two decimals; a dash before the first frame.
    private func valueText(_ slot: Int) -> String {
        slot < mirror.parameterValues.count ? String(format: "%.2f", mirror.parameterValues[slot]) : "–"
    }

    // MARK: Building blocks

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: title).font(.headline).accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func choice(_ title: String, selected: Bool, identifier: String, hint: String,
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
        .accessibilityHint(Text(verbatim: hint))
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
