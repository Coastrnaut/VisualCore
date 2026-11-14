// OdysseyControls — feature 054 (A07-P01) T-A07-104 (FR-A07-121, FR-A07-122). The native controls of Audio Odyssey:
// the world picker (Tunnel, Landscape, Star corridor), the speed picker (Slow, Medium, Fast), Pause or Resume and New
// journey. Every button sends its action through the port; every control has a VoiceOver label and hint, an identifier
// from the port (`world.0…2`, `speed.0…2`, `flight.pause` / `flight.resume`, `journey.reseed`), a hit area of at least
// 44 by 44 points and text that wraps. Nothing animates and nothing claims any effect on comfort or well-being.
import SwiftUI
import AudioOdysseyCore
import VisualCoreExperienceHost

/// The controls of Audio Odyssey.
struct OdysseyControls: View {
    let port: ExperienceActionPort
    let mirror: OdysseyMirror

    var body: some View {
        if let world = mirror.world {
            content(world: world)
        } else {
            ProgressView().accessibilityLabel(Text(verbatim: "Loading"))
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
