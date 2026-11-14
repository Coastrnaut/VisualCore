// MusicLabState — feature 047 (A06-P01) T-A06-104 (FR-A06-102, FR-A06-104, FR-A06-121; data-model "MusicLabState",
// schema 1). The domain state of VisualCore Music Lab: which source is selected, the demo signal's seed and mode, the
// picked file's display name and the mirrored microphone permission. Samples are never state.
//
// Persisted (snapshot, digest): `source`, `demoSeed`, `demoMode`. Not persisted:
//   - `fileName` is display only (≤ 120 characters). A picked file is reachable only through the security-scoped URL
//     the system file importer hands out in this run, so neither the URL nor the name can be restored, and an
//     experience action carries numbers only; the presenter records the name in its display copy of the state.
//   - `permission` mirrors the system's microphone permission; the system stays the authority, so a restore starts
//     from `notDetermined` and the presenter mirrors the live value again before the microphone is chosen.
import Foundation

/// The rule codes of Music Lab.
public enum MusicLabRule {
    /// The microphone was chosen while its permission is denied or restricted (FR-A06-104).
    public static let permissionDenied = "a06.permission-denied"
    /// A payload or preparation whose values lie outside the state's rules.
    public static let invalidState = "a06.invalid-state"
}

/// The state of Music Lab. Schema version 1.
public struct MusicLabState: Sendable, Equatable, Codable {
    /// The schema version of the persisted fields.
    public static let schemaVersion = 1
    /// The longest display name of a picked file, in characters.
    public static let fileNameLimit = 120
    /// The demo modes by index: melody (seeded tone sequence), 440 Hz tone, 1 kHz tone, silence.
    public static let demoModeNames = ["Melody", "440 Hz tone", "1 kHz tone", "Silence"]
    /// The legal demo mode indices.
    public static let demoModeRange = 0...3
    /// The step `reseed()` adds to the demo seed (the golden-ratio increment).
    public static let seedStep: UInt64 = 0x9E37_79B9_7F4A_7C15

    /// The selected source.
    public private(set) var source: SourceKind
    /// The seed of the demo signal's melody.
    public private(set) var demoSeed: UInt64
    /// The demo mode index (0 melody, 1 440 Hz tone, 2 1 kHz tone, 3 silence).
    public private(set) var demoMode: Int
    /// The display name of the file being played; nil unless the source is a file. Not persisted.
    public private(set) var fileName: String?
    /// The mirrored microphone permission. Not persisted.
    public var permission: MicrophoneAccess = .notDetermined

    /// The first state: the demo signal's melody with `seed`, no file, permission not determined.
    public init(seed: UInt64) {
        source = .demo
        demoSeed = seed
        demoMode = 0
    }

    /// A state with the persisted fields given; nil when `demoMode` lies outside `demoModeRange`.
    public init?(source: SourceKind, demoSeed: UInt64, demoMode: Int) {
        guard Self.demoModeRange.contains(demoMode) else { return nil }
        self.source = source
        self.demoSeed = demoSeed
        self.demoMode = demoMode
    }

    // MARK: Rules

    /// Selects `kind`. The microphone is refused with `MusicLabRule.permissionDenied` while the mirrored permission is
    /// denied or restricted, and the state is unchanged; while it is not determined the selection is taken (the
    /// presenter then asks once). Leaving the file source clears the file name. Returns the refusal code, or nil.
    @discardableResult
    public mutating func select(_ kind: SourceKind) -> String? {
        if kind == .microphone, permission.refusesMicrophone { return MusicLabRule.permissionDenied }
        source = kind
        if kind != .file { fileName = nil }
        return nil
    }

    /// Sets the demo mode; false (and no change) when `mode` lies outside `demoModeRange`.
    @discardableResult
    public mutating func setDemoMode(_ mode: Int) -> Bool {
        guard Self.demoModeRange.contains(mode) else { return false }
        demoMode = mode
        return true
    }

    /// Moves the demo seed on by `seedStep` (wrapping), for a new melody.
    public mutating func reseed() {
        demoSeed &+= Self.seedStep
    }

    /// Records the display name of the picked file (`displayFileName(_:)`); only while the source is a file.
    public mutating func recordFileName(_ name: String) {
        guard source == .file else { return }
        fileName = Self.displayFileName(name)
    }

    /// `name` trimmed of surrounding white space and cut to `fileNameLimit` characters; nil when nothing is left.
    public static func displayFileName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(fileNameLimit))
    }

    /// The name of the current demo mode.
    public var demoModeName: String { Self.demoModeNames[demoMode] }

    // MARK: Coding (persisted fields only)

    private enum CodingKeys: String, CodingKey {
        case source, demoSeed, demoMode
    }

    /// Decodes the persisted fields; a demo mode outside `demoModeRange` is refused as corrupt data.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let mode = try c.decode(Int.self, forKey: .demoMode)
        guard Self.demoModeRange.contains(mode) else {
            throw DecodingError.dataCorruptedError(forKey: .demoMode, in: c,
                                                   debugDescription: "\(MusicLabRule.invalidState): demo mode \(mode)")
        }
        source = try c.decode(SourceKind.self, forKey: .source)
        demoSeed = try c.decode(UInt64.self, forKey: .demoSeed)
        demoMode = mode
    }

    /// Encodes the persisted fields: source, demo seed, demo mode.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(source, forKey: .source)
        try c.encode(demoSeed, forKey: .demoSeed)
        try c.encode(demoMode, forKey: .demoMode)
    }
}
