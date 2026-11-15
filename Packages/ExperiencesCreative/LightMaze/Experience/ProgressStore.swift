// ProgressStore — feature 098 (A13-P03) T-A13-303 (FR-A13-320; SC-A13-303; clarifications Q1 and Q2; contract
// contracts/progress.md). The level progress of Light Maze in the experience's own storage, one file: `progress.json`,
// a `Progress` document (file schema 1, sorted keys, at most 16 KB, exactly the 20 catalog levels in order).
//   - Save: the progress's `encoded()` bytes written through `ExperienceStorage.write`, which replaces the file
//     atomically (a reader sees the complete old or the complete new file; a refused or interrupted write leaves what
//     was stored byte for byte). A refused write is reported with the storage error's code and changes nothing.
//   - Load: no file (a first launch, or after the app's data reset) → fresh progress (level 1 open, nothing solved) and
//     no refusal; a file that cannot be read → fresh progress and the storage error's code; otherwise
//     `Progress.decode` with the bundled catalog: `damaged` (not JSON, truncated, unknown ids, a different count or an
//     inconsistent level), `too-large` (above 16 KB) or `newer-version` (file schema above 1), each giving fresh
//     progress and the refusal's code. Loading never writes: a refused file stays byte for byte as it was until the
//     next real change replaces it.
// Without storage (tests and previews) the bytes are kept in memory with the same rules. The store sits outside the
// engine state, so neither loading nor saving can change a state digest or a replay.
import Foundation
import LightMazeCore
import VisualCoreExperience

/// The level progress of Light Maze in its storage file (see the file header).
final class ProgressStore {
    /// The storage file: `progress.json`.
    static let fileName = "progress.json"

    /// The experience's storage, or nil for progress kept in memory only.
    let storage: ExperienceStorage?
    /// The stored bytes when there is no storage.
    private var memory: Data?
    /// The number of files written (or bytes set in memory).
    private(set) var writes = 0

    /// A store over `storage` (in memory without storage). Nothing is read or written here.
    init(storage: ExperienceStorage?) {
        self.storage = storage
    }

    /// The stored bytes: nil when there is no file, otherwise the bytes or the storage's refusal.
    func bytes() -> Result<Data, StorageError>? {
        guard let storage else { return memory.map { .success($0) } }
        do {
            return .success(try storage.read(Self.fileName))
        } catch {
            if case .notFound = error { return nil }
            return .failure(error)
        }
    }

    /// The stored progress, or fresh progress with the code of the reason the file was refused (nil when there was no
    /// file or it was accepted). Nothing is written.
    func load() -> (progress: LightMazeCore.Progress, refusal: String?) {
        switch bytes() {
        case nil:
            return (LightMazeCore.Progress.fresh(), nil)
        case .failure(let error):
            return (LightMazeCore.Progress.fresh(), error.code)
        case .success(let data):
            switch LightMazeCore.Progress.decode(data, catalog: .bundled) {
            case .success(let progress): return (progress, nil)
            case .failure(let refusal): return (LightMazeCore.Progress.fresh(), refusal.rawValue)
            }
        }
    }

    /// Saves `progress`, replacing the stored file; nil on success, otherwise the storage error's code (the previous
    /// file is left as it was).
    @discardableResult
    func save(_ progress: LightMazeCore.Progress) -> String? {
        let data = progress.encoded()
        if let storage {
            do {
                try storage.write(data, to: Self.fileName)
            } catch {
                return error.code
            }
        } else {
            memory = data
        }
        writes += 1
        return nil
    }
}
