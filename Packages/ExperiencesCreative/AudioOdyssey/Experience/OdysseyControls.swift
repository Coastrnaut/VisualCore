// OdysseyControls — feature 054 (A07-P01) T-A07-104 (FR-A07-121, FR-A07-122). The native controls of Audio Odyssey:
// the world picker (Tunnel, Landscape, Star corridor), the speed picker (Slow, Medium, Fast), Pause or Resume and New
// journey. Every button sends its action through the port; every control has a VoiceOver label and hint, an identifier
// from the port (`world.0…2`, `speed.0…2`, `flight.pause` / `flight.resume`, `journey.reseed`), a hit area of at least
// 44 by 44 points and text that wraps. Nothing animates and nothing claims any effect on comfort or well-being.
// Feature 055 (A07-P02) T-A07-205 (FR-A07-220, FR-A07-221): the sound source (Demo signal, Microphone, Choose file…
// through the system file importer, audio types only, read in place), the status line and a plain message with a link
// to Settings when microphone access is off, worded as Music Lab's. The demo button sends its action through the port;
// the microphone and file choices go through the presenter, which checks the permission or opens the file first.
// Identifiers `source.demo`, `source.microphone`, `source.file`, `source.status`, `source.message`, `settings`.
// Nothing claims to measure sound.
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AudioOdysseyCore
import VisualCoreExperienceHost

/// The controls of Audio Odyssey.
struct OdysseyControls: View {
    let port: ExperienceActionPort
    let presenter: OdysseyPresenter
    let mirror: OdysseyMirror

    @State private var importing = false

    var body: some View {
        Group {
            if let world = mirror.world {
                content(world: world)
            } else {
                ProgressView().accessibilityLabel(Text(verbatim: "Loading"))
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { presenter.chooseFile(url: url) }
        }
    }

    @ViewBuilder private func content(world: JourneyWorld) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            section("World") {
                ForEach(JourneyWorld.allCases, id: \.rawValue) { option in
                    choice(option.displayName, selected: world == option, identifier: "world.\(option.rawValue)",
                           hint: "Flies through the \(option.displayName.lowercased()) from the same place") {
                        if world != option { _ = port.send("world.select", [Double(option.rawValue)]) }
                    }
                }
            }
            section("Speed") {
                ForEach(SpeedChoice.allCases, id: \.rawValue) { option in
                    choice(option.displayName, selected: mirror.speedChoice == option,
                           identifier: "speed.\(option.rawValue)", hint: "Eases the flight to \(option.displayName.lowercased()) speed") {
                        if mirror.speedChoice != option { _ = port.send("speed.select", [Double(option.rawValue)]) }
                    }
                }
            }
            section("Flight") {
                if mirror.paused {
                    button("Resume", identifier: "flight.resume", hint: "Continues the flight from where it stopped") {
                        _ = port.send("flight.resume")
                    }
                } else {
                    button("Pause", identifier: "flight.pause", hint: "Eases the flight to a stop") {
                        _ = port.send("flight.pause")
                    }
                }
                button("New journey", identifier: "journey.reseed", hint: "Builds a new path and new surroundings") {
                    _ = port.send("journey.reseed")
                }
            }
            section("Sound source") {
                choice("Demo signal", selected: mirror.source == .demo, identifier: "source.demo",
                       hint: "The tunnel follows the built-in signal; no permission needed") {
                    if mirror.source != .demo { _ = port.send("source.demo") }
                }
                choice("Microphone", selected: mirror.source == .microphone, identifier: "source.microphone",
                       hint: "The tunnel follows the live input; nothing is recorded or sent") {
                    Task { await presenter.chooseMicrophone() }
                }
                .disabled(mirror.isRequestingPermission)
                choice("Choose file…", selected: mirror.source == .file, identifier: "source.file",
                       hint: "The tunnel follows an audio file you pick; it is read in place, not copied") {
                    importing = true
                }
                Text(verbatim: "Playing: \(mirror.sourceName)")
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(port.identifier("source.status"))
                if let message = mirror.message {
                    Text(verbatim: message)
                        .font(.footnote).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(port.identifier("source.message"))
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
        }
    }

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
