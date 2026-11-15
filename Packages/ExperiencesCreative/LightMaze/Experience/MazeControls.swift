// MazeControls — feature 096 (A13-P01) T-A13-104 (FR-A13-121; clarification Q5). The native controls of Light Maze in
// one section:
//   Previous level and Next level (`previous-level`, `next-level` → `level.previous` / `level.next`; disabled on the
//     first and the last level);
//   Select previous and Select next (`select-previous`, `select-next` → `tile.select [index]` of the previous or next
//     turnable tile, wrapping; from no selection Select next takes the first and Select previous the last; disabled
//     on a level without turnable tiles);
//   Turn (`turn` → `tile.turn`: toggles the selected mirror or prism; disabled with nothing selected);
//   Reset level (`reset-level` → `level.reset`: the level's starting orientations);
//   the status line (`status`: level, tiles, where the beam ends and whether it is solved) and the answer to a refused
//     action (`message`, shown only when there is one).
// Every control has an accessible label and value (and a hint) and the identifier `experience.a13.light-maze.<name>`
// from the port; hit areas are at least 44 points high and text wraps.
import LightMazeCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost

/// The controls of Light Maze.
struct MazeControls: View {
    /// The port the controls send through.
    let port: ExperienceActionPort
    /// What the controls show.
    let mirror: MazeMirror

    /// `status` with a capital first letter ("Loading" when empty).
    static func sentence(_ status: String) -> String {
        guard let first = status.first else { return "Loading" }
        return first.uppercased() + String(status.dropFirst())
    }

    /// The tile Select next chooses from `selection` among `count` turnable tiles (wrapping; the first from no
    /// selection); nil without turnable tiles.
    static func nextTile(selection: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        return selection < 0 ? 0 : (selection + 1) % count
    }

    /// The tile Select previous chooses from `selection` among `count` turnable tiles (wrapping; the last from no
    /// selection); nil without turnable tiles.
    static func previousTile(selection: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        return selection < 0 ? count - 1 : (selection - 1 + count) % count
    }

    /// The level in words: "Level 1 of 20".
    static func levelWords(index: Int, count: Int) -> String { "Level \(index + 1) of \(count)" }

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
        let level = Self.levelWords(index: mirror.levelIndex, count: mirror.levelCount)
        let next = Self.nextTile(selection: mirror.selection, count: mirror.turnableCount)
        let previous = Self.previousTile(selection: mirror.selection, count: mirror.turnableCount)
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Light Maze").font(.headline).accessibilityAddTraits(.isHeader)
            HStack(spacing: 8) {
                button("Previous level", name: "previous-level", value: level,
                       hint: mirror.levelIndex > 0 ? "Opens the previous level" : "This is the first level",
                       enabled: mirror.levelIndex > 0) { send("level.previous") }
                button("Next level", name: "next-level", value: level,
                       hint: mirror.levelIndex < mirror.levelCount - 1 ? "Opens the next level"
                           : "This is the last level",
                       enabled: mirror.levelIndex < mirror.levelCount - 1) { send("level.next") }
            }
            HStack(spacing: 8) {
                button("Select previous", name: "select-previous", value: mirror.selectedWords,
                       hint: "Selects the previous mirror or prism", enabled: previous != nil) {
                    if let previous { send("tile.select", [Double(previous)]) }
                }
                button("Select next", name: "select-next", value: mirror.selectedWords,
                       hint: "Selects the next mirror or prism", enabled: next != nil) {
                    if let next { send("tile.select", [Double(next)]) }
                }
            }
            HStack(spacing: 8) {
                button("Turn", name: "turn", value: mirror.selectedWords,
                       hint: mirror.selection >= 0 ? "Turns the selected tile to its other diagonal"
                           : "Select a mirror or prism first",
                       enabled: mirror.selection >= 0) { send("tile.turn") }
                button("Reset level", name: "reset-level", value: mirror.solved ? "Solved" : "Not solved",
                       hint: "Returns every tile of the level to its starting position", enabled: true) {
                    send("level.reset")
                }
            }
            Text(verbatim: Self.sentence(mirror.status))
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(verbatim: "Status"))
                .accessibilityValue(Text(verbatim: Self.sentence(mirror.status)))
                .accessibilityIdentifier(port.identifier("status"))
            if !mirror.message.isEmpty {
                Text(verbatim: mirror.message)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(verbatim: "Message"))
                    .accessibilityValue(Text(verbatim: mirror.message))
                    .accessibilityIdentifier(port.identifier("message"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Sends `control` with `values` through the port and shows the answer when it is refused.
    private func send(_ control: String, _ values: [Double] = []) {
        let result = port.send(control, values)
        mirror.message = MazePresenter.answerWords(control: control, result: result)
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
