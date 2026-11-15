// WorldsControls — feature 089 (A12-P01) T-A12-104 (FR-A12-121; clarification 4). The native controls of Tiny Worlds
// in one section:
//   the preset picker (`preset` → `world.preset [0…2]`: Island, Asteroid garden, Miniature city);
//   New seed (`new-seed` → `world.seed`: the next seed from the session's generator);
//   Turn left and Turn right (`turn-left`, `turn-right` → `view.orbit [−15, 0]` / `[15, 0]`);
//   Tilt up and Tilt down (`tilt-up`, `tilt-down` → `view.orbit [0, 10]` / `[0, −10]`; disabled at 75° and 10°);
//   Zoom in and Zoom out (`zoom-in`, `zoom-out` → `view.zoom [1.25]` / `[0.8]`; disabled at 10 m and 30 m);
//   Reset view (`reset-view` → `view.reset`: from the north-east, 35 degrees up, 18 metres away);
//   the status line (`status`: world, seed and view in words).
// Every control has an accessible label and value (and a hint) and the identifier `experience.a12.tiny-worlds.<name>`
// from the port; hit areas are at least 44 points high and text wraps.
import SwiftUI
import TinyWorldsCore
import VisualCoreExperienceHost

/// The controls of Tiny Worlds.
struct WorldsControls: View {
    /// The port the controls send through.
    let port: ExperienceActionPort
    /// What the controls show.
    let mirror: WorldsMirror

    /// The yaw step of one turn, in degrees.
    static let turnStep = 15.0
    /// The pitch step of one tilt, in degrees.
    static let tiltStep = 10.0
    /// The zoom factors of Zoom in and Zoom out.
    static let zoomInFactor = 1.25, zoomOutFactor = 0.8

    /// `status` with a capital first letter ("Loading" when empty).
    static func sentence(_ status: String) -> String {
        guard let first = status.first else { return "Loading" }
        return first.uppercased() + String(status.dropFirst())
    }

    /// Whether the view can tilt further up (pitch below 75°).
    static func canTiltUp(_ view: WorldView) -> Bool { view.pitch < WorldView.pitchRange.upperBound }
    /// Whether the view can tilt further down (pitch above 10°).
    static func canTiltDown(_ view: WorldView) -> Bool { view.pitch > WorldView.pitchRange.lowerBound }
    /// Whether the view can move closer (distance above 10 m).
    static func canZoomIn(_ view: WorldView) -> Bool { view.distance > WorldView.distanceRange.lowerBound }
    /// Whether the view can move farther (distance below 30 m).
    static func canZoomOut(_ view: WorldView) -> Bool { view.distance < WorldView.distanceRange.upperBound }

    /// The controls, or a progress indicator before the first state.
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
        let view = mirror.view
        let direction = WorldsPresenter.directionWords(view)
        let pitch = WorldsPresenter.pitchWords(view)
        let distance = WorldsPresenter.distanceWords(view)
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Tiny Worlds").font(.headline).accessibilityAddTraits(.isHeader)
            Picker(selection: Binding(get: { mirror.presetIndex },
                                      set: { index in
                                          if index != mirror.presetIndex {
                                              _ = port.send("world.preset", [Double(index)])
                                          }
                                      })) {
                ForEach(WorldPreset.all.indices, id: \.self) { index in
                    Text(verbatim: WorldPreset.all[index].name).tag(index)
                }
            } label: {
                Text(verbatim: "World")
            }
            .pickerStyle(.segmented)
            .frame(minHeight: 44)
            .accessibilityLabel(Text(verbatim: "World"))
            .accessibilityValue(Text(verbatim: WorldPreset.preset(index: mirror.presetIndex)?.name ?? "Island"))
            .accessibilityIdentifier(port.identifier("preset"))
            button("New seed", name: "new-seed", value: "Seed \(mirror.seed)",
                   hint: "Makes a new world of the same kind", enabled: true) { _ = port.send("world.seed") }
            HStack(spacing: 8) {
                button("Turn left", name: "turn-left", value: direction, hint: "Turns the view by 15 degrees",
                       enabled: true) { _ = port.send("view.orbit", [-Self.turnStep, 0]) }
                button("Turn right", name: "turn-right", value: direction, hint: "Turns the view by 15 degrees",
                       enabled: true) { _ = port.send("view.orbit", [Self.turnStep, 0]) }
            }
            HStack(spacing: 8) {
                button("Tilt up", name: "tilt-up", value: pitch,
                       hint: Self.canTiltUp(view) ? "Looks down from 10 degrees higher" : "The view is at its highest",
                       enabled: Self.canTiltUp(view)) { _ = port.send("view.orbit", [0, Self.tiltStep]) }
                button("Tilt down", name: "tilt-down", value: pitch,
                       hint: Self.canTiltDown(view) ? "Looks from 10 degrees lower" : "The view is at its lowest",
                       enabled: Self.canTiltDown(view)) { _ = port.send("view.orbit", [0, -Self.tiltStep]) }
            }
            HStack(spacing: 8) {
                button("Zoom in", name: "zoom-in", value: distance,
                       hint: Self.canZoomIn(view) ? "Moves closer to the world" : "The view is at its closest",
                       enabled: Self.canZoomIn(view)) { _ = port.send("view.zoom", [Self.zoomInFactor]) }
                button("Zoom out", name: "zoom-out", value: distance,
                       hint: Self.canZoomOut(view) ? "Moves away from the world" : "The view is at its farthest",
                       enabled: Self.canZoomOut(view)) { _ = port.send("view.zoom", [Self.zoomOutFactor]) }
            }
            button("Reset view", name: "reset-view", value: WorldsPresenter.viewWords(view),
                   hint: "Returns to the view from the north-east", enabled: true) { _ = port.send("view.reset") }
            Text(verbatim: Self.sentence(mirror.status))
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("status"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A bordered button `title` with the identifier `name`, the accessible value `value` and the hint `hint`.
    private func button(_ title: String, name: String, value: String, hint: String, enabled: Bool,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title)
                .font(.body)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(!enabled)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: value))
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(name))
    }
}
