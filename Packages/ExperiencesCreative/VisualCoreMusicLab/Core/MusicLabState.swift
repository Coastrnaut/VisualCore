// MusicLabState — feature 047 (A06-P01) T-A06-104 (FR-A06-102, FR-A06-104, FR-A06-121; data-model "MusicLabState",
// schema 1). The domain state of VisualCore Music Lab: which source is selected, the demo signal's seed and mode, the
// picked file's display name and the mirrored microphone permission. Samples are never state.
// Feature 049 (A06-P03) T-A06-305 (FR-A06-310, 313): schema 2 adds the scene and the mapping choices per scene.
//
// Persisted (snapshot, digest): `source`, `demoSeed`, `demoMode`, `scene`, `mappings`. Not persisted:
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
    /// A mapping slot beyond the scene's parameter count (feature 049).
    public static let noSuchParameter = "a06.no-such-parameter"
}

/// The state of Music Lab. Schema version 2.
public struct MusicLabState: Sendable, Equatable, Codable {
    /// The schema version of the persisted fields (2 since feature 049: scene and mappings).
    public static let schemaVersion = 3
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
    /// The selected scene (feature 049).
    public private(set) var scene: MusicLabScene = .bars
    /// The mapping choices per scene, in scene order; each list holds exactly its scene's parameter count.
    public private(set) var mappings: [[MappingChoice]] = MusicLabScene.defaultMappings()
    /// The colour palette (feature 051, schema 3).
    public private(set) var palette: MusicLabPalette = .aurora

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

    /// Selects `palette` (feature 051, FR-A06-512).
    public mutating func select(palette: MusicLabPalette) {
        self.palette = palette
    }

    /// Selects `scene` (FR-A06-310).
    public mutating func select(scene: MusicLabScene) {
        self.scene = scene
    }

    /// Sets the choice of `slot` in `scene`; returns `MusicLabRule.noSuchParameter` (and changes nothing) for a slot
    /// beyond the scene's parameter count, nil otherwise.
    @discardableResult
    public mutating func setMapping(scene: MusicLabScene, slot: Int, choice: MappingChoice) -> String? {
        guard mappings[scene.rawValue].indices.contains(slot) else { return MusicLabRule.noSuchParameter }
        mappings[scene.rawValue][slot] = choice
        return nil
    }

    /// Restores the default choices of `scene`.
    public mutating func resetMappings(scene: MusicLabScene) {
        mappings[scene.rawValue] = scene.defaultChoices
    }

    /// The choices of the selected scene.
    public var currentChoices: [MappingChoice] { mappings[scene.rawValue] }

    /// Whether `mappings` has one list per scene, each with its scene's parameter count, all choices valid.
    public static func isValid(_ mappings: [[MappingChoice]]) -> Bool {
        guard mappings.count == MusicLabScene.allCases.count else { return false }
        return MusicLabScene.allCases.allSatisfy { scene in
            mappings[scene.rawValue].count == scene.parameters.count && mappings[scene.rawValue].allSatisfy(\.isValid)
        }
    }

    /// The name of the current demo mode.
    public var demoModeName: String { Self.demoModeNames[demoMode] }

    // MARK: Coding (persisted fields only)

    private enum CodingKeys: String, CodingKey {
        case source, demoSeed, demoMode, scene, mappings, palette
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
        let sceneIndex = try c.decode(Int.self, forKey: .scene)
        guard let scene = MusicLabScene(rawValue: sceneIndex) else {
            throw DecodingError.dataCorruptedError(forKey: .scene, in: c,
                                                   debugDescription: "\(MusicLabRule.invalidState): scene \(sceneIndex)")
        }
        let mappings = try c.decode([[MappingChoice]].self, forKey: .mappings)
        guard Self.isValid(mappings) else {
            throw DecodingError.dataCorruptedError(forKey: .mappings, in: c,
                                                   debugDescription: "\(MusicLabRule.invalidState): mappings")
        }
        self.scene = scene
        self.mappings = mappings
        let paletteIndex = try c.decode(Int.self, forKey: .palette)
        guard let palette = MusicLabPalette(rawValue: paletteIndex) else {
            throw DecodingError.dataCorruptedError(forKey: .palette, in: c,
                                                   debugDescription: "\(MusicLabRule.invalidState): palette \(paletteIndex)")
        }
        self.palette = palette
    }

    /// Encodes the persisted fields: source, demo seed, demo mode, scene index and mapping choices.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(source, forKey: .source)
        try c.encode(demoSeed, forKey: .demoSeed)
        try c.encode(demoMode, forKey: .demoMode)
        try c.encode(scene.rawValue, forKey: .scene)
        try c.encode(mappings, forKey: .mappings)
        try c.encode(palette.rawValue, forKey: .palette)
    }
}
