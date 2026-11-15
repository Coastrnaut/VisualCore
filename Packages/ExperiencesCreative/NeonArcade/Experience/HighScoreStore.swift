// HighScoreStore — feature 078 (A10-P04) T-A10-403 (FR-A10-411, FR-A10-412, FR-A10-413; clarification 2; research
// D2 and D3; edge cases "Storage full or refused", "Where the scores live and how they go away"). The local high-score
// table of Neon Arcade kept in the experience's own storage as the file `high-scores.json` (the `HighScoreTable` JSON
// with sorted keys; no date, name or device data).
//   - Load (on creation): no file → an empty table and no problem; a file that cannot be read, does not decode, has a
//     newer board version or breaks the table's rules → an empty table and the problem "high scores could not be
//     read: <reason>", reported once. The damaged file is left in place until the next completed run writes a valid
//     table. Play is never stopped.
//   - Save: `ExperienceStorage.write`, which replaces the file atomically (a reader sees the complete old or the
//     complete new table; the temporary file of an interrupted write is hidden and never read). A refused write keeps
//     the table in memory for the session and reports "high scores could not be saved: <code>" once.
//   - `record(run:number:live:)` processes the end of a run: a run that is not over is ignored; otherwise its entry
//     (score, wave, run number) goes through `HighScoreTable.enter`, which processes a run number once (a restored
//     game-over screen is not entered again), and a changed table is saved. The core's run number restarts at 1 after
//     a reset or a refused saved state; an ending the presenter watched happen (`live`) whose number the table has
//     already processed is therefore entered under the next number after the table's last run, so new runs are never
//     lost. The entry of the last run processed is kept as the new entry the screens mark (nil when it did not rank).
// The store never touches the core, so the table cannot change a state digest. Without storage (tests) the table
// lives in memory only.
import Foundation
import NeonArcadeCore
import VisualCoreExperience

/// The high-score table of Neon Arcade in its storage file (see the file header).
final class HighScoreStore {
    /// The storage file of the table.
    static let fileName = "high-scores.json"
    /// The beginning of the problem text of a table that could not be read.
    static let readProblem = "high scores could not be read"
    /// The beginning of the problem text of a table that could not be saved.
    static let saveProblem = "high scores could not be saved"

    /// The experience's storage, or nil for a table kept in memory only.
    let storage: ExperienceStorage?
    /// The table: the stored one, or empty when there was none or it could not be read.
    private(set) var table = HighScoreTable()
    /// The current problem, or nil: the table could not be read (until a valid table is written) or saved.
    private(set) var problem: String?
    /// Every problem reported, in order; each kind at most once per store.
    private(set) var reports: [String] = []
    /// The entry of the last run processed when it entered the table (the screens mark it), otherwise nil.
    private(set) var newEntry: HighScoreEntry?
    /// The number of tables written.
    private(set) var writes = 0
    private var saveRefusalReported = false

    /// A store over `storage` with its table loaded (an empty in-memory table without storage).
    init(storage: ExperienceStorage?) {
        self.storage = storage
        load()
    }

    /// The best entry, or nil for an empty table.
    var best: HighScoreEntry? { table.best }

    /// The index of ``newEntry`` in the table, or nil when there is none or it has been pushed out.
    var newEntryIndex: Int? {
        guard let entry = newEntry else { return nil }
        return table.entries.firstIndex(of: entry)
    }

    /// Reads the stored table (see the file header): nothing stored → empty; unreadable or invalid → empty with a
    /// problem.
    private func load() {
        guard let storage else { return }
        let data: Data
        do {
            data = try storage.read(Self.fileName)
        } catch {
            if case .notFound = error { return }
            report(Self.readProblem + ": " + error.code)
            return
        }
        switch HighScoreTable.decode(data) {
        case .success(let stored): table = stored
        case .failure(let failure): report(Self.readProblem + ": " + failure.reason)
        }
    }

    /// Processes the end of `run` under run number `number` (see the file header) and returns the entry's 0-based
    /// rank, or nil when the run is not over, was processed already, scored 0 or did not rank. `live` is true when the
    /// caller watched the run end (the screen changed to game over while drawn).
    @discardableResult
    func record(run: GameRun, number: Int, live: Bool = false) -> Int? {
        guard run.over else { return nil }
        var number = number
        if number <= table.lastRun {
            guard live else { return nil }
            number = table.lastRun + 1
        }
        let before = table
        let entry = HighScoreEntry(score: run.score, wave: run.wave, run: number)
        let rank = table.enter(entry)
        newEntry = rank == nil ? nil : entry
        if table != before { save() }
        return rank
    }

    /// Writes the table atomically; a refused write is reported once and the table stays in memory.
    private func save() {
        guard let storage else { return }
        do {
            try storage.write(table.encoded(), to: Self.fileName)
            writes += 1
            if problem?.hasPrefix(Self.readProblem) == true { problem = nil }
        } catch {
            guard !saveRefusalReported else { return }
            saveRefusalReported = true
            report(Self.saveProblem + ": " + error.code)
        }
    }

    /// Sets `text` as the problem and adds it to ``reports``.
    private func report(_ text: String) {
        problem = text
        reports.append(text)
    }
}
