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
//
// Feature 091 (A12-P03) T-A12-303 (FR-A12-303, FR-A12-310, FR-A12-321, FR-A12-322; clarifications Q2–Q5) adds three
// groups:
//   Props: the prop kind picker (`prop-kind`: Tree, Rock, House, Lantern; presentation state only), Place
//     (`place` → `prop.place [kind, x, z]` at the last tapped ground point, else the world centre), Select previous and
//     Select next (`select-previous`, `select-next` → `prop.select [index]`, wrapping; disabled without props), Move
//     west, east, south and north (`move-west`, `move-east`, `move-south`, `move-north` → `prop.move [∓0.5, 0]`,
//     `[0, ∓0.5]`), Rotate left and right (`rotate-left`, `rotate-right` → `prop.rotate [−45]` / `[45]`) and Delete
//     (`delete` → `prop.delete`), the move, rotate and delete buttons disabled without a selection; the line of the
//     last answer (`message`);
//   Light: azimuth (`light-azimuth`, a stepper of 15° wrapping in 0…360 → `light.azimuth`), elevation
//     (`light-elevation`, 5° steps in 10…85 → `light.elevation`) and ambient (`light-ambient`, 0.05 steps in 0.1…0.6 →
//     `light.ambient`);
//   Saved worlds: four slot rows (`slot-<n>-picture` when a thumbnail is stored, `slot-<n>-save`, `slot-<n>-open`,
//     `slot-<n>-clear` and the status `slot-<n>-status`, n = 0…3), handled by the presenter (`WorldsSlotActions`), not
//     by actions; Save hands over the host's still renderer (`experienceStillRenderer`) for the thumbnail.
// Editing and light actions go through `WorldsEditActions`, which sends them through the port and answers them in
// words.
import SwiftUI
import TinyWorldsCore
import UIKit
import VisualCoreExperienceHost

/// What the editing and light controls do: send an action through the port (answered in words), or place a prop of a
/// kind at the presenter's place point.
struct WorldsEditActions {
    /// Sends the action with its values.
    var send: (String, [Double]) -> Void
    /// Places a prop of the kind (0…3).
    var place: (Int) -> Void

    /// Edit actions that do nothing (previews).
    static var none: WorldsEditActions { WorldsEditActions(send: { _, _ in }, place: { _ in }) }
}

/// What the slot buttons do: the presenter saves, opens and clears slots outside the action replay.
struct WorldsSlotActions {
    /// Saves the current world to the slot, with a thumbnail drawn by the still renderer when there is one.
    var save: (Int, ExperienceStillRenderer?) -> Void
    /// Opens the world saved in the slot.
    var open: (Int) -> Void
    /// Removes the world saved in the slot.
    var clear: (Int) -> Void

    /// Slot actions that do nothing (previews).
    static var none: WorldsSlotActions { WorldsSlotActions(save: { _, _ in }, open: { _ in }, clear: { _ in }) }
}

/// The controls of Tiny Worlds.
struct WorldsControls: View {
    /// The port the controls send through.
    let port: ExperienceActionPort
    /// What the controls show.
    let mirror: WorldsMirror
    /// The editing and light actions (feature 091).
    var edit: WorldsEditActions = .none
    /// The slot buttons' handlers (feature 091).
    var slots: WorldsSlotActions = .none
    /// The host's still renderer for thumbnails; nil outside the host view.
    @Environment(\.experienceStillRenderer) private var still

    /// The step of one prop move, in metres.
    static let moveStep = 0.5
    /// The step of one prop rotation, in degrees.
    static let rotateStep = 45.0
    /// The azimuth step, in degrees.
    static let azimuthStep = 15.0
    /// The elevation step, in degrees.
    static let elevationStep = 5.0
    /// The ambient step.
    static let ambientStep = 0.05

    /// The index Select next chooses among `count` props from `selection` (wrapping; the first without a selection).
    static func nextIndex(_ selection: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        return selection >= 0 && selection < count ? (selection + 1) % count : 0
    }

    /// The index Select previous chooses among `count` props from `selection` (wrapping; the last without one).
    static func previousIndex(_ selection: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        return selection > 0 && selection < count ? selection - 1 : count - 1
    }

    /// The azimuth `steps` azimuth steps from `azimuth`, wrapped into 0…360 (360 excluded).
    static func azimuth(_ azimuth: Double, steps: Int) -> Double {
        var next = (azimuth + Double(steps) * azimuthStep).truncatingRemainder(dividingBy: 360)
        if next < 0 { next += 360 }
        return next >= 360 ? 0 : next
    }

    /// `value` moved by `delta` and clamped into `range`, rounded to 1e-9 (so 0.35 + 0.05 is 0.4).
    static func stepped(_ value: Double, by delta: Double, in range: ClosedRange<Double>) -> Double {
        let next = ((value + delta) * 1e9).rounded() / 1e9
        return min(max(next, range.lowerBound), range.upperBound)
    }

    /// The slot rows' title: "Slot 1" … "Slot 4".
    static func slotTitle(_ slot: Int) -> String { "Slot \(slot + 1)" }

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
            Group {
                propsGroup
                lightGroup
                slotsGroup
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The props group (feature 091).
    @ViewBuilder private var propsGroup: some View {
        let count = mirror.props.count
        let selected = mirror.props.indices.contains(mirror.selection) ? mirror.props[mirror.selection] : nil
        let selectedWords = selected.map { "The \(WorldsPresenter.propName($0.kind)), prop \(mirror.selection + 1) of \(count)" }
            ?? (count == 0 ? "No props" : "None selected")
        Text(verbatim: "Props").font(.headline).accessibilityAddTraits(.isHeader)
        Picker(selection: Binding(get: { mirror.placeKind }, set: { mirror.placeKind = $0 })) {
            ForEach(PropKind.allCases, id: \.rawValue) { kind in
                Text(verbatim: kind.name).tag(kind.rawValue)
            }
        } label: {
            Text(verbatim: "Prop")
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: "Prop to place"))
        .accessibilityValue(Text(verbatim: PropKind(rawValue: mirror.placeKind)?.name ?? "Tree"))
        .accessibilityIdentifier(port.identifier("prop-kind"))
        button("Place", name: "place", value: "\(count) of \(WorldEditing.maxProps) props",
               hint: "Places the chosen prop where you last tapped the ground, or at the centre",
               enabled: count < WorldEditing.maxProps) { edit.place(mirror.placeKind) }
        HStack(spacing: 8) {
            button("Select previous", name: "select-previous", value: selectedWords, hint: "Selects the previous prop",
                   enabled: count > 0) {
                if let index = Self.previousIndex(mirror.selection, count: count) {
                    edit.send("prop.select", [Double(index)])
                }
            }
            button("Select next", name: "select-next", value: selectedWords, hint: "Selects the next prop",
                   enabled: count > 0) {
                if let index = Self.nextIndex(mirror.selection, count: count) {
                    edit.send("prop.select", [Double(index)])
                }
            }
        }
        let hasSelection = selected != nil
        let position = selected.map { "x \(WorldsPresenter.decimal($0.x)), z \(WorldsPresenter.decimal($0.z))" }
            ?? "No prop selected"
        HStack(spacing: 8) {
            button("Move west", name: "move-west", value: position, hint: "Moves the selected prop half a metre west",
                   enabled: hasSelection) { edit.send("prop.move", [-Self.moveStep, 0]) }
            button("Move east", name: "move-east", value: position, hint: "Moves the selected prop half a metre east",
                   enabled: hasSelection) { edit.send("prop.move", [Self.moveStep, 0]) }
        }
        HStack(spacing: 8) {
            button("Move south", name: "move-south", value: position,
                   hint: "Moves the selected prop half a metre south",
                   enabled: hasSelection) { edit.send("prop.move", [0, -Self.moveStep]) }
            button("Move north", name: "move-north", value: position,
                   hint: "Moves the selected prop half a metre north",
                   enabled: hasSelection) { edit.send("prop.move", [0, Self.moveStep]) }
        }
        let turn = selected.map { "\(Int(($0.rotation / WorldView.radiansPerDegree).rounded())) degrees" }
            ?? "No prop selected"
        HStack(spacing: 8) {
            button("Rotate left", name: "rotate-left", value: turn, hint: "Turns the selected prop by 45 degrees",
                   enabled: hasSelection) { edit.send("prop.rotate", [-Self.rotateStep]) }
            button("Rotate right", name: "rotate-right", value: turn, hint: "Turns the selected prop by 45 degrees",
                   enabled: hasSelection) { edit.send("prop.rotate", [Self.rotateStep]) }
        }
        button("Delete", name: "delete", value: selectedWords, hint: "Deletes the selected prop",
               enabled: hasSelection) { edit.send("prop.delete", []) }
        if !mirror.message.isEmpty {
            Text(verbatim: mirror.message)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("message"))
        }
    }

    /// The light group (feature 091).
    @ViewBuilder private var lightGroup: some View {
        let light = mirror.light
        Text(verbatim: "Light").font(.headline).accessibilityAddTraits(.isHeader)
        Stepper(onIncrement: {
            edit.send("light.azimuth", [Self.azimuth(light.azimuth, steps: 1)])
        }, onDecrement: {
            edit.send("light.azimuth", [Self.azimuth(light.azimuth, steps: -1)])
        }) {
            Text(verbatim: "Sun direction: \(Int(light.azimuth.rounded())) degrees")
        }
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: "Sun direction"))
        .accessibilityValue(Text(verbatim: "\(Int(light.azimuth.rounded())) degrees"))
        .accessibilityIdentifier(port.identifier("light-azimuth"))
        Stepper(onIncrement: {
            edit.send("light.elevation", [Self.stepped(light.elevation, by: Self.elevationStep,
                                                       in: WorldLight.elevationRange)])
        }, onDecrement: {
            edit.send("light.elevation", [Self.stepped(light.elevation, by: -Self.elevationStep,
                                                       in: WorldLight.elevationRange)])
        }) {
            Text(verbatim: "Sun height: \(Int(light.elevation.rounded())) degrees up")
        }
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: "Sun height"))
        .accessibilityValue(Text(verbatim: "\(Int(light.elevation.rounded())) degrees up"))
        .accessibilityIdentifier(port.identifier("light-elevation"))
        Stepper(onIncrement: {
            edit.send("light.ambient", [Self.stepped(light.ambient, by: Self.ambientStep,
                                                     in: WorldLight.ambientRange)])
        }, onDecrement: {
            edit.send("light.ambient", [Self.stepped(light.ambient, by: -Self.ambientStep,
                                                     in: WorldLight.ambientRange)])
        }) {
            Text(verbatim: "Shadow brightness: " + String(format: "%.2f", light.ambient))
        }
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: "Shadow brightness"))
        .accessibilityValue(Text(verbatim: String(format: "%.2f", light.ambient)))
        .accessibilityIdentifier(port.identifier("light-ambient"))
    }

    /// The saved-worlds group: four slot rows (feature 091).
    @ViewBuilder private var slotsGroup: some View {
        Text(verbatim: "Saved worlds").font(.headline).accessibilityAddTraits(.isHeader)
        ForEach(Array(WorldStore.slots), id: \.self) { slot in
            slotRow(slot)
        }
    }

    /// The row of `slot`: its thumbnail, Save, Open, Clear and its status.
    @ViewBuilder private func slotRow(_ slot: Int) -> some View {
        let title = Self.slotTitle(slot)
        let stored = mirror.slotNames[slot]
        let holding = stored.isEmpty ? "Empty" : stored
        VStack(alignment: .leading, spacing: 4) {
            if let data = mirror.slotPictures[slot], let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(CGFloat(WorldStore.thumbnailWidth) / CGFloat(WorldStore.thumbnailHeight),
                                 contentMode: .fit)
                    .frame(maxWidth: 160)
                    .accessibilityLabel(Text(verbatim: "\(title) picture: \(holding)"))
                    .accessibilityIdentifier(port.identifier("slot-\(slot)-picture"))
            }
            HStack(spacing: 8) {
                button("Save", name: "slot-\(slot)-save", value: holding,
                       hint: "Saves the world in \(title.lowercased())", enabled: true) {
                    slots.save(slot, still)
                }
                button("Open", name: "slot-\(slot)-open", value: holding,
                       hint: "Opens the world saved in \(title.lowercased())", enabled: !stored.isEmpty) {
                    slots.open(slot)
                }
                button("Clear", name: "slot-\(slot)-clear", value: holding,
                       hint: "Removes the world saved in \(title.lowercased())", enabled: !stored.isEmpty) {
                    slots.clear(slot)
                }
            }
            Text(verbatim: "\(title): \(mirror.slotStatus[slot])")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("slot-\(slot)-status"))
        }
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
