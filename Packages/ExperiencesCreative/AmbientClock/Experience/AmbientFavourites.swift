// AmbientFavourites — feature 133 (A18-P03) T-A18-306 (FR-A18-304, FR-A18-305; SC-A18-304; G-FAVOURITES;
// clarification Q4; research D4). The saved theme presets of Ambient Clock, kept as one file, `favourites.json`, in
// the experience's own storage through the public `ExperienceStorage` API (`write(_:to:)`, `read(_:)`, `exists(_:)`,
// `remove(_:)`), capped at 12.
//
//   - File: `{"kind": "a18.favourites", "schemaVersion": 1, "entries": [{"id": "<UUID>", "name": "…",
//     "createdAt": <seconds since 1970>, "preset": {"motion", "palette", "speed", "theme"}}]}` as JSON with sorted
//     keys; at most 12 entries and 65,536 bytes.
//   - Loading: no file gives an empty list and no problem. A file that is larger than 65,536 bytes (`too-large`), not
//     a favourites envelope (`damaged`), of a newer schema (`newer-version`), or that holds an invalid entry — a
//     preset `ThemePreset.validated()` refuses, an empty or over-60-character name, a name used twice (without regard
//     to case) or more than 12 entries (`invalid-entry`) — gives an empty list and one problem; nothing crashes. The
//     file is left as it is until the person saves; that save writes the new list in its place.
//   - Names: trimmed and cut to 60 characters; an empty name becomes "Favourite N" with N the count + 1 (the next
//     free number when that name is taken). A 13th favourite is refused as `over-cap` (checked first), a name in use
//     as `duplicate-name`, a write the storage refuses (`StorageError`) or a list above 65,536 bytes as
//     `store-failed`. A refusal writes nothing.
//   - Determinism: the creation time comes from the injected clock (`ClockSource`), never `Date()`, and the id of a
//     new entry from an injected generator (default `UUID.init`).
//   - Apply: sends `theme.select`, `theme.palette`, `theme.speed` and `theme.motion` through the port, in that order
//     (the palette after the theme, because choosing another theme resets the palette).
import AmbientClockCore
import Foundation
import Observation
import VisualCoreExperience
import VisualCoreExperienceHost

/// One saved favourite: its id, name, creation time and preset.
struct FavouriteEntry: Codable, Equatable, Identifiable, Sendable {
    /// Identity (names are unique without regard to case as well).
    var id: UUID
    /// The name: trimmed, 1–60 characters.
    var name: String
    /// When it was saved, seconds since 1970 (from the injected clock).
    var createdAt: Double
    /// The saved theme preset.
    var preset: ThemePreset
}

/// Why a favourite was not saved.
enum FavouriteRefusal: Error, Equatable, Sendable {
    /// The list already holds ``AmbientFavourites/cap`` favourites.
    case overCap
    /// Another favourite already has this name (compared without regard to case); the value is the name.
    case duplicateName(String)
    /// The storage refused the write, or the list would exceed the file limit; the value describes why.
    case storeFailed(String)

    /// The stable code: `over-cap`, `duplicate-name` or `store-failed`.
    var code: String {
        switch self {
        case .overCap: return "over-cap"
        case .duplicateName: return "duplicate-name"
        case .storeFailed: return "store-failed"
        }
    }

    /// One sentence for the person.
    var sentence: String {
        switch self {
        case .overCap:
            return "There are already \(AmbientFavourites.cap) favourites, the most that are kept."
        case .duplicateName(let name):
            return "A favourite named \(name) already exists."
        case .storeFailed(let reason):
            return "The favourite could not be saved (\(reason))."
        }
    }
}

/// Why the favourites file could not be used (the list is then empty and the file left untouched).
enum FavouritesProblem: Error, Equatable, Sendable {
    /// Not JSON, not a favourites envelope, or a schema version below 1.
    case damaged
    /// Written with a newer schema; the value is that version.
    case newerVersion(Int)
    /// Larger than ``AmbientFavourites/maxBytes``; the value is its size in bytes.
    case tooLarge(Int)
    /// An entry is invalid; the value says which and why.
    case invalidEntry(String)

    /// The stable code: `damaged`, `newer-version`, `too-large` or `invalid-entry`.
    var code: String {
        switch self {
        case .damaged: return "damaged"
        case .newerVersion: return "newer-version"
        case .tooLarge: return "too-large"
        case .invalidEntry: return "invalid-entry"
        }
    }

    /// One sentence for the person.
    var sentence: String {
        switch self {
        case .damaged:
            return "The favourites file is damaged and was not read."
        case .newerVersion(let version):
            return "The favourites file has schema version \(version), newer than version "
                + "\(AmbientFavourites.schemaVersion) that this version reads."
        case .tooLarge(let bytes):
            return "The favourites file is \(bytes) bytes, above the limit of \(AmbientFavourites.maxBytes) bytes."
        case .invalidEntry(let reason):
            return "The favourites file holds an invalid entry (\(reason)) and was not read."
        }
    }
}

/// The saved theme presets (see the file header).
@MainActor
@Observable
final class AmbientFavourites {
    /// One saved favourite.
    typealias Entry = FavouriteEntry

    /// The file name in the experience's storage.
    nonisolated static let fileName = "favourites.json"
    /// The envelope kind.
    nonisolated static let kind = "a18.favourites"
    /// The schema version this code writes and reads.
    nonisolated static let schemaVersion = 1
    /// The most favourites kept.
    nonisolated static let cap = 12
    /// The longest name kept, in characters.
    nonisolated static let maxNameLength = 60
    /// The largest file read or written, in bytes.
    nonisolated static let maxBytes = 65_536

    /// The experience's storage.
    @ObservationIgnored let storage: ExperienceStorage
    /// The source of the creation times.
    @ObservationIgnored let clock: any ClockSource
    /// The source of new ids.
    @ObservationIgnored let makeID: @MainActor () -> UUID
    /// The favourites, in the order saved (oldest first).
    private(set) var entries: [Entry] = []
    /// What went wrong at the last `reload()`; empty when the file was read or is absent.
    private(set) var problems: [FavouritesProblem] = []
    /// The last refusal of `save`, for the person; nil after a successful save.
    private(set) var lastRefusal: FavouriteRefusal?

    /// The favourites in `storage`, with creation times from `clock` and new ids from `makeID`; loads at once.
    init(storage: ExperienceStorage, clock: any ClockSource = SystemClock(),
         makeID: @escaping @MainActor () -> UUID = { UUID() }) {
        self.storage = storage
        self.clock = clock
        self.makeID = makeID
        reload()
    }

    // MARK: File

    private struct Envelope: Codable {
        var kind: String
        var schemaVersion: Int
        var entries: [Entry]
    }

    private struct Header: Decodable {
        var kind: String
        var schemaVersion: Int
    }

    /// The file's list of `data`, or the problem that stops it from being used (see the file header).
    nonisolated static func decode(_ data: Data) -> Result<[Entry], FavouritesProblem> {
        guard data.count <= maxBytes else { return .failure(.tooLarge(data.count)) }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.kind == kind,
              header.schemaVersion >= 1 else { return .failure(.damaged) }
        guard header.schemaVersion <= schemaVersion else { return .failure(.newerVersion(header.schemaVersion)) }
        guard let envelope = try? decoder.decode(Envelope.self, from: data) else { return .failure(.damaged) }
        guard envelope.entries.count <= cap else {
            return .failure(.invalidEntry("\(envelope.entries.count) entries, above \(cap)"))
        }
        var seen = Set<String>()
        for (index, entry) in envelope.entries.enumerated() {
            if case .failure(let refusal) = entry.preset.validated() {
                return .failure(.invalidEntry("entry \(index): \(refusal.sentence)"))
            }
            let trimmed = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed == entry.name, entry.name.count <= maxNameLength else {
                return .failure(.invalidEntry("entry \(index): the name is empty, untrimmed or above \(maxNameLength) "
                    + "characters"))
            }
            guard seen.insert(entry.name.lowercased()).inserted else {
                return .failure(.invalidEntry("entry \(index): the name \(entry.name) is used twice"))
            }
            guard entry.createdAt.isFinite else { return .failure(.invalidEntry("entry \(index): the time")) }
        }
        return .success(envelope.entries)
    }

    /// The file of `entries`: the envelope as JSON with sorted keys.
    nonisolated static func encode(_ entries: [Entry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(Envelope(kind: kind, schemaVersion: schemaVersion, entries: entries))
    }

    /// Re-reads the file: no file gives an empty list and no problem; an unusable file an empty list and one problem
    /// (the file is left untouched).
    func reload() {
        guard storage.exists(Self.fileName) else {
            entries = []
            problems = []
            return
        }
        let data: Data
        do {
            data = try storage.read(Self.fileName)
        } catch {
            entries = []
            problems = [.damaged]
            return
        }
        switch Self.decode(data) {
        case .success(let read):
            entries = read
            problems = []
        case .failure(let problem):
            entries = []
            problems = [problem]
        }
    }

    /// Writes `list` as the file (replacing whatever was there); the storage's error or the size limit as a refusal.
    private func write(_ list: [Entry]) -> FavouriteRefusal? {
        let data: Data
        do {
            data = try Self.encode(list)
        } catch {
            return .storeFailed("encoding: \(error)")
        }
        guard data.count <= Self.maxBytes else {
            return .storeFailed("the list is \(data.count) bytes, above \(Self.maxBytes)")
        }
        do {
            try storage.write(data, to: Self.fileName)
        } catch {
            return .storeFailed(error.code)
        }
        return nil
    }

    // MARK: Names

    /// The name a favourite saved as `raw` gets: trimmed and cut to ``maxNameLength`` characters; an empty name
    /// becomes "Favourite N", N the count + 1, or the next number whose name is free.
    func normalizedName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else {
            return String(trimmed.prefix(Self.maxNameLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var number = entries.count + 1
        while isTaken("Favourite \(number)") { number += 1 }
        return "Favourite \(number)"
    }

    /// Whether a favourite already has `name`, compared without regard to case.
    func isTaken(_ name: String) -> Bool {
        entries.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    // MARK: Changes

    /// Saves `preset` as a new favourite named `name` (``normalizedName(_:)``) at the clock's time and writes the
    /// list (replacing an unusable file; its problem is then cleared). Refused, writing nothing, as
    /// ``FavouriteRefusal/overCap`` at the cap, ``FavouriteRefusal/duplicateName(_:)`` for a name in use and
    /// ``FavouriteRefusal/storeFailed(_:)`` for an invalid preset, a refused write or a list above the size limit.
    @discardableResult
    func save(name: String, preset: ThemePreset) -> Result<Entry, FavouriteRefusal> {
        let result = attemptSave(name: name, preset: preset)
        switch result {
        case .success: lastRefusal = nil
        case .failure(let refusal): lastRefusal = refusal
        }
        return result
    }

    private func attemptSave(name: String, preset: ThemePreset) -> Result<Entry, FavouriteRefusal> {
        guard entries.count < Self.cap else { return .failure(.overCap) }
        let normalized = normalizedName(name)
        guard !isTaken(normalized) else { return .failure(.duplicateName(normalized)) }
        if case .failure(let refusal) = preset.validated() { return .failure(.storeFailed(refusal.code)) }
        let entry = Entry(id: makeID(), name: normalized, createdAt: clock.now.timeIntervalSince1970, preset: preset)
        let list = entries + [entry]
        if let refusal = write(list) { return .failure(refusal) }
        entries = list
        problems = []
        return .success(entry)
    }

    /// Removes the favourite `id` and writes the list (the file is removed when the list becomes empty); false when
    /// no favourite has that id or the storage refuses (then nothing changes).
    @discardableResult
    func remove(id: UUID) -> Bool {
        guard entries.contains(where: { $0.id == id }) else { return false }
        let list = entries.filter { $0.id != id }
        if list.isEmpty {
            do {
                try storage.remove(Self.fileName)
            } catch {
                return false
            }
        } else if write(list) != nil {
            return false
        }
        entries = list
        return true
    }

    /// The favourite with `id`.
    func entry(_ id: UUID) -> Entry? { entries.first { $0.id == id } }

    /// Applies the favourite `id` through `port`: `theme.select`, `theme.palette`, `theme.speed`, `theme.motion`.
    /// Returns the four results, or an empty list when no favourite has that id.
    @discardableResult
    func apply(id: UUID, port: ExperienceActionPort) -> [ActionResult] {
        guard let preset = entry(id)?.preset else { return [] }
        return [port.send("theme.select", [Double(preset.theme)]),
                port.send("theme.palette", [Double(preset.palette)]),
                port.send("theme.speed", [preset.speed]),
                port.send("theme.motion", [preset.motion ? 1 : 0])]
    }
}
