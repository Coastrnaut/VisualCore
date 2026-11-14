// MusicLabControls — feature 047 (A06-P01) T-A06-104 (FR-A06-104, FR-A06-122). The native controls of VisualCore
// Music Lab: the three sources (Demo signal, Microphone, Choose file… through the system file importer, audio types
// only, read in place with security-scoped access), the demo mode (Melody, 440 Hz tone, 1 kHz tone, Silence), New
// melody, the status line and a plain message with a link to Settings when microphone access is off. The demo and mode
// buttons send actions through the port; the file and microphone choices go through the presenter, which opens the
// file or checks the permission first. Every control has a VoiceOver label, an identifier from the port, a hit area of
// at least 44 by 44 points and text that wraps.
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
