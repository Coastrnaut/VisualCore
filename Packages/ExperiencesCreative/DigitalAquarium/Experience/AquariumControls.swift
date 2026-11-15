// AquariumControls — feature 068 (A09-P01) T-A09-103 (FR-A09-121, FR-A09-123). The native controls of Digital
// Aquarium in one section:
//   the habitat picker (`habitat.select`: the starter habitats of the bundled catalog, "Reef" and "Kelp"),
//   the lighting picker (`lighting.level`: Dim, Soft, Bright),
//   the pause toggle (`motion.pause`: "Pause motion"),
//   and the status line (`aquarium.status`: habitat, fish and plant counts, swimming or paused).
// Feature 070 (A09-P03) T-A09-307 (FR-A09-312): the native alternatives of the canvas gestures in two more sections.
//   Feeding: the Feed button (`food.feed` → `food.drop [0.5, 0.95]`, pellets at the top middle of the water) and the
//   pellet count (`food.count`).
//   Decorations: the kind picker (`decor.kind`: the catalog's decor kinds, showing the core's chosen kind), the Add
//   button (`decor.add` → `decor.place [0.5, 0.15]`), the piece picker (`decor.piece`: "Piece 1 (Round rock)" …, a
//   view-only selection), Move left, right, up and down (`decor.left`, `decor.right`, `decor.up`, `decor.down` →
//   `decor.move [i, x, y]` half a tank unit from the piece's current position, 0.5/16 across or 0.5/9 up, clamped to
//   0…1) and Remove (`decor.remove` → `decor.remove [i]`). The piece buttons are disabled while there is no piece.
//   The positions come from the presenter's mirror, which is updated from the habitat document on every sync.
// Every control has an accessible label and value and an identifier from the port; hit areas are at least 44 points
// high and text wraps.
import SwiftUI
import DigitalAquariumCore
import VisualCoreExperienceHost
import VisualCoreMath

/// The controls of Digital Aquarium.
struct AquariumControls: View {
    let port: ExperienceActionPort
    let mirror: AquariumMirror
    /// The piece the move and remove buttons act on (view-only; clamped to the pieces present).
    @State private var piece = 0

    /// One move step across the tank as a fraction of its width (half a tank unit of 16).
    static let stepX = 0.5 / 16
    /// One move step up the tank as a fraction of its height (half a tank unit of 9).
    static let stepY = 0.5 / 9
    /// Where the Feed button drops pellets (tank fractions): the top middle of the water.
    static let feedPoint = [0.5, 0.95]
    /// Where the Add button places a piece (tank fractions): the middle of the floor.
    static let placePoint = [0.5, 0.15]

    /// The picker names of the decoration kinds.
    static var decorOptions: [String] { AquariumCore.catalog.decor.map(\.name) }

    /// The piece picker's names: "Piece 1 (Round rock)", ….
    static func pieceOptions(_ names: [String]) -> [String] {
        names.enumerated().map { "Piece \($0.offset + 1) (\($0.element))" }
    }

    /// `index` clamped to the pieces present (0 when there is none).
    static func clampedPiece(_ index: Int, count: Int) -> Int { count == 0 ? 0 : min(max(index, 0), count - 1) }

    /// The `decor.move` values that move piece `index` at `fraction` by `dx`, `dy` (fractions), clamped to 0…1.
    static func moveValues(index: Int, fraction: Vec2, dx: Double, dy: Double) -> [Double] {
        [Double(index), min(max(fraction.x + dx, 0), 1), min(max(fraction.y + dy, 0), 1)]
    }

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
            feeding
            decorations
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var feeding: some View {
        Text(verbatim: "Feeding").font(.headline).accessibilityAddTraits(.isHeader)
        actionButton("Feed", identifier: "food.feed", hint: "Drops three food pellets at the top of the water") {
            _ = port.send("food.drop", Self.feedPoint)
        }
        Text(verbatim: Self.sentence(AquariumPresenter.foodWords(mirror.foodCount)) + " in the water")
            .font(.footnote)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(port.identifier("food.count"))
    }

    @ViewBuilder private var decorations: some View {
        let count = mirror.decorNames.count
        let selected = Self.clampedPiece(piece, count: count)
        Text(verbatim: "Decorations").font(.headline).accessibilityAddTraits(.isHeader)
        choicePicker("Decoration kind", identifier: "decor.kind", selection: mirror.decorKind,
                     options: Self.decorOptions, hint: "The kind the Add button and a long press place") { index in
            _ = port.send("decor.kind", [Double(index)])
        }
        actionButton("Add decoration", identifier: "decor.add",
                     hint: "Places a piece of the chosen kind on the floor in the middle") {
            _ = port.send("decor.place", Self.placePoint)
        }
        if count > 0 {
            choicePicker("Piece", identifier: "decor.piece", selection: selected,
                         options: Self.pieceOptions(mirror.decorNames),
                         hint: "The piece the move and remove buttons act on") { index in
                piece = index
            }
        } else {
            Text(verbatim: "No decorations")
                .font(.footnote)
                .accessibilityIdentifier(port.identifier("decor.piece"))
        }
        HStack(spacing: 8) {
            moveButton("Move left", identifier: "decor.left", piece: selected, dx: -Self.stepX, dy: 0)
            moveButton("Move right", identifier: "decor.right", piece: selected, dx: Self.stepX, dy: 0)
        }
        HStack(spacing: 8) {
            moveButton("Move up", identifier: "decor.up", piece: selected, dx: 0, dy: Self.stepY)
            moveButton("Move down", identifier: "decor.down", piece: selected, dx: 0, dy: -Self.stepY)
        }
        actionButton("Remove decoration", identifier: "decor.remove", hint: "Removes the chosen piece",
                     disabled: count == 0) {
            _ = port.send("decor.remove", [Double(selected)])
            piece = Self.clampedPiece(selected, count: count - 1)
        }
    }

    /// A button that moves piece `piece` by `dx`, `dy` (tank fractions) from its current position.
    private func moveButton(_ title: String, identifier: String, piece: Int, dx: Double, dy: Double) -> some View {
        let fractions = mirror.decorFractions
        return actionButton(title, identifier: identifier, hint: "Moves the chosen piece half a unit",
                            disabled: !fractions.indices.contains(piece)) {
            guard fractions.indices.contains(piece) else { return }
            _ = port.send("decor.move", Self.moveValues(index: piece, fraction: fractions[piece], dx: dx, dy: dy))
        }
    }

    /// A bordered button with an accessible label, hint and identifier, at least 44 points high.
    private func actionButton(_ title: String, identifier: String, hint: String, disabled: Bool = false,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title).font(.body).frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(disabled)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(identifier))
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
