// MazeControls — feature 096 (A13-P01) T-A13-104 (FR-A13-121; clarification Q5). The native controls of Light Maze in
// one section:
//   Previous level and Next level (`previous-level`, `next-level` → `level.previous` / `level.next`; disabled on the
//     first and the last level);
//   Select previous and Select next (`select-previous`, `select-next` → `tile.select [index]` of the previous or next
//     turnable tile, wrapping; from no selection Select next takes the first and Select previous the last; disabled
//     on a level without turnable tiles);
//   Turn (`turn` → `tile.turn`: toggles the selected mirror or prism; disabled with nothing selected);
//   Restart (`reset-level` → `level.reset`: the level's starting orientations and no moves; "Reset level" before
//     feature 098);
//   the status line (`status`: level, tiles, where the beam ends and whether it is solved) and the answer to a refused
//     action (`message`, shown only when there is one).
// Feature 096 T-A13-115 (FR-A13-121; convergence): the Level menu (`level` → `level.select [index]`) lists the 20
//   levels by number and name, so every action has a native control.
// Feature 098 (A13-P03) T-A13-304 (FR-A13-302, FR-A13-311; clarifications Q1 and Q3): Undo (`undo` → `move.undo`,
//   value "3 moves", disabled with no moves) takes the last turn back; Reset level is now labelled Restart (same
//   identifier `reset-level`); the Level menu lists locked levels disabled with "(locked)" and solved ones with their
//   best count, and a choice goes through the presenter (`chooseLevel(_:port:)`), which refuses a locked level in words;
//   Next level is disabled when the next level is locked.
// Feature 099 (A13-P04) T-A13-406 (FR-A13-402, FR-A13-411; clarifications Q1–Q2): Hint (`hint` → `hint.show` through
//   the presenter's `showHint(port:)`, which answers with the tile to turn or "Level N is already solved."; disabled
//   while the level is solved) and Describe (`describe`: the presenter's `describeBoard()` shows and speaks the full
//   board description; no action).
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
    /// The presenter a level choice goes through (it refuses a locked level).
    let presenter: MazePresenter

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

    /// The Level menu's item for level index `index` named `name` under `progress`: "3. Bounce (locked)", "1. First
    /// light (solved, best 1)" or "2. Around the corner".
    static func menuWords(index: Int, name: String, progress: LightMazeCore.Progress) -> String {
        let base = "\(index + 1). \(name)"
        if !progress.isOpen(index) { return base + " (locked)" }
        if progress.isSolved(index), let best = progress.best(index) {
            return base + " (solved, best \(best))"
        }
        return base
    }

    /// Whether Next level is enabled at level index `index` of `count` under `progress`: there is a next level and it
    /// is open.
    static func nextEnabled(index: Int, count: Int, progress: LightMazeCore.Progress) -> Bool {
        index < count - 1 && progress.isOpen(index + 1)
    }

    /// The Undo button's value: "0 moves", "1 move", "3 moves".
    static func movesWords(_ count: Int) -> String { MazeCore.counted(count, "move") }

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
                       hint: nextHint,
                       enabled: Self.nextEnabled(index: mirror.levelIndex, count: mirror.levelCount,
                                                 progress: mirror.progress)) { send("level.next") }
            }
            Menu {
                ForEach(LevelCatalog.bundled.levels.indices, id: \.self) { index in
                    Button {
                        presenter.chooseLevel(index, port: port)
                    } label: {
                        Text(verbatim: Self.menuWords(index: index, name: LevelCatalog.bundled.levels[index].name,
                                                      progress: mirror.progress))
                    }
                    .disabled(!mirror.progress.isOpen(index))
                }
            } label: {
                Text(verbatim: "Level")
                    .font(.body)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(Text(verbatim: "Level"))
            .accessibilityValue(Text(verbatim: level))
            .accessibilityHint(Text(verbatim: "Opens any open level"))
            .accessibilityIdentifier(port.identifier("level"))
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
            }
            HStack(spacing: 8) {
                button("Undo", name: "undo", value: Self.movesWords(mirror.moveCount),
                       hint: mirror.moveCount > 0 ? "Takes the last turn back" : "There is no move to undo",
                       enabled: mirror.moveCount > 0) { send("move.undo") }
                button("Restart", name: "reset-level", value: mirror.solved ? "Solved" : "Not solved",
                       hint: "Returns every tile of the level to its starting position", enabled: true) {
                    send("level.reset")
                }
            }
            HStack(spacing: 8) {
                button("Hint", name: "hint", value: mirror.solved ? "Solved" : "Not solved",
                       hint: mirror.solved ? "This level is already solved" : "Selects a tile to turn and says where",
                       enabled: !mirror.solved) { presenter.showHint(port: port) }
                button("Describe", name: "describe", value: mirror.solved ? "Solved" : "Not solved",
                       hint: "Speaks every tile, the beam's path and each target", enabled: true) {
                    presenter.describeBoard()
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

    /// The hint of Next level: why it is disabled, or what it does.
    private var nextHint: String {
        if mirror.levelIndex >= mirror.levelCount - 1 { return "This is the last level" }
        if !mirror.progress.isOpen(mirror.levelIndex + 1) {
            return "Level \(mirror.levelIndex + 2) is locked; solve level \(mirror.levelIndex + 1) first"
        }
        return "Opens the next level"
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
