// GenerativeArtCore — feature 193 (UA-F07) T-U07-008 (FR-U07-001 to FR-U07-004; research R1, data-model section 2).
// The pure state of Generative Art Studio as an experience: the composition being edited, its preset, the parameter
// baseline that reset returns to, and the playback clock. Every edit goes through the app's own
// `CompositionEditor`, so that values are clamped and validated exactly as in the standalone app.
//
// Differences from the standalone app (FR-U07-003):
//   1. Time advances in fixed steps of 1/120 s (`update(step:)`) instead of by the frame delta of `SceneClock`;
//      it wraps at the same 120 s and scrubs to the same range.
//   2. Reduce Motion is the control `rate` (0…4, as `SceneClock.speedRange`): the controls send 0.5 when the
//      person's setting asks for reduced motion, instead of a clock flag the state cannot see.
//   3. `seed.shuffle` derives the next seed from the current one (a deterministic `SeededRandom`), instead of the
//      system generator, so that a script replays it.
//   4. The four families are one experience: `family` switches to a family's default preset, where the standalone
//      app opens a new screen from the gallery. The time restarts at 0 and playback starts, as on a new screen. A
//      preparation opens the Particles family at its default preset (the standalone app opens on its gallery):
//      the first frame then has a background whose colour follows from the palette alone, so the verification
//      runner can check it (FR-U07-010).
//   5. Opening a saved composition is the actions `open`, `value.<name>` and `rebase`, because an action carries at
//      most eight numbers. The document id comes from the preparation seed, not from `UUID()`.
//   6. `save` counts saved compositions; the controls write the file through the experience's storage. The
//      outcome `work-saved` follows from the count.
import Foundation
import GenerativeArtStudioCore
import VisualCoreExperience
import VisualCoreParameters
import VisualCorePersistence
import VisualCoreSimulation

/// The state of Generative Art Studio inside the one app. Codable; schema version 1.
public struct GenerativeArtCore: ExperienceCore, Codable, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a01.generative-art-studio"
    /// The length of the playback loop in seconds, as `SceneClock`'s default.
    public static let duration = SceneClock().duration
    /// The largest number of saves counted.
    public static let maxSaves = 1_000_000
    /// The largest seed half `seed.set` and `open` take (32 bits each).
    public static let maxSeedHalf = Double(UInt32.max)

    /// The seed the state was prepared from.
    public private(set) var seed: UInt64
    /// The composition being edited, always validated.
    public private(set) var document: ArtDocument
    /// The id of the selected preset; nil after opening a saved composition.
    public private(set) var presetID: String?
    /// The parameter values a reset returns to: the selected preset's or the opened composition's.
    public private(set) var baseline: [String: Double]
    /// The playback time in seconds, 0 ..< `duration`.
    public private(set) var time: Double
    /// Whether the time advances.
    public private(set) var playing: Bool
    /// The playback rate, 0…4 (0.5 under Reduce Motion).
    public private(set) var rate: Double
    /// How many times the composition was saved.
    public private(set) var saves: Int

    /// The family of the composition.
    public var family: SceneFamily { document.family ?? FamilyCatalog.all[0] }
    /// The index of the family in the gallery.
    public var familyIndex: Int { FamilyCatalog.all.firstIndex { $0.id == family.id } ?? 0 }

    // MARK: Contract

    public static var migrations: MigrationChain { MigrationChain(currentVersion: 1) }

    /// The controls: see data-model section 2 of feature 193.
    public static var controls: [ExperienceControl] {
        let maxPresets = FamilyCatalog.all.map(\.presets.count).max() ?? 1
        var list = [
            ExperienceControl(id: "family", ranges: [0...Double(FamilyCatalog.all.count - 1)]),
            ExperienceControl(id: "preset", ranges: [0...Double(maxPresets - 1)]),
            ExperienceControl(id: "palette", ranges: [0...Double(FamilyCatalog.palettes.count - 1)]),
            ExperienceControl(id: "resetAll"),
            ExperienceControl(id: "seed.shuffle"),
            ExperienceControl(id: "seed.set", ranges: [0...maxSeedHalf, 0...maxSeedHalf]),
            ExperienceControl(id: "play"),
            ExperienceControl(id: "pause"),
            ExperienceControl(id: "scrub", ranges: [0...duration]),
            ExperienceControl(id: "rate", ranges: [SceneClock.speedRange]),
            ExperienceControl(id: "save"),
            ExperienceControl(id: "open", ranges: [0...Double(FamilyCatalog.all.count - 1),
                                                   0...Double(FamilyCatalog.palettes.count - 1),
                                                   0...maxSeedHalf, 0...maxSeedHalf, 0...ArtDocument.maxPreviewTime]),
            ExperienceControl(id: "rebase"),
        ]
        for (name, range) in parameterRanges {
            list.append(ExperienceControl(id: "parameter." + name, ranges: [0...1]))
            list.append(ExperienceControl(id: "value." + name, ranges: [range]))
            list.append(ExperienceControl(id: "reset." + name))
        }
        return list
    }

    /// Every parameter name of the four families with the union of its ranges, in name order.
    public static var parameterRanges: [(name: String, range: ClosedRange<Double>)] {
        var ranges: [String: ClosedRange<Double>] = [:]
        for definition in FamilyCatalog.all.flatMap(\.schema.definitions) {
            if let known = ranges[definition.name] {
                ranges[definition.name] = min(known.lowerBound, definition.minimum)...max(known.upperBound,
                                                                                          definition.maximum)
            } else {
                ranges[definition.name] = definition.range
            }
        }
        return ranges.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    /// The family a preparation opens.
    public static let startFamily = SceneFamilyID.particles

    /// The state of a fresh preparation: the Particles family at its default preset, time 0, playing.
    public static func prepare(seed: UInt64) async throws -> GenerativeArtCore {
        try Task.checkCancellation()
        return GenerativeArtCore(seed: seed)
    }

    private init(seed: UInt64) {
        self.seed = seed
        let editor = CompositionEditor(family: FamilyCatalog.family(Self.startFamily))
        var document = editor.composition
        document.id = Self.documentID(seed: seed)
        self.document = document
        presetID = editor.presetID
        baseline = editor.editor.baseline
        time = 0
        playing = true
        rate = 1
        saves = 0
    }

    /// The document id of a preparation with `seed`: 16 bytes of `SeededRandom(seed:)`.
    public static func documentID(seed: UInt64) -> UUID {
        var random = SeededRandom(seed: seed ^ 0xA01A_01A0_1A01_A01A)
        let a = random.next(), b = random.next()
        let bytes = (0..<8).map { UInt8(truncatingIfNeeded: a >> ($0 * 8)) }
            + (0..<8).map { UInt8(truncatingIfNeeded: b >> ($0 * 8)) }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    /// One fixed step: the time advances by the step length times the rate while playing and wraps at the loop.
    public mutating func update(step: Int) {
        guard playing else { return }
        time = (time + Self.stepDuration * rate).truncatingRemainder(dividingBy: Self.duration)
    }

    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let values = action.values
        switch action.control {
        case "family":
            let index = Int(values[0].rounded())
            guard FamilyCatalog.all.indices.contains(index) else { return .rejected(.outOfRange(index: 0)) }
            let editor = CompositionEditor(family: FamilyCatalog.all[index])
            take(editor, presetID: editor.presetID, keepID: true)
            time = 0
            playing = true
        case "preset":
            let index = Int(values[0].rounded())
            guard family.presets.indices.contains(index) else { return rule("a01.no-preset") }
            var editor = makeEditor()
            editor.choosePreset(family.presets[index].id)
            take(editor, presetID: editor.presetID)
        case "palette":
            let index = Int(values[0].rounded())
            guard FamilyCatalog.palettes.indices.contains(index) else { return .rejected(.outOfRange(index: 0)) }
            var editor = makeEditor()
            editor.choosePalette(FamilyCatalog.palettes[index].id)
            take(editor, presetID: presetID)
        case "resetAll":
            var editor = makeEditor()
            editor.resetAll()
            take(editor, presetID: presetID)
        case "seed.shuffle":
            var editor = makeEditor()
            var random = SeededRandom(seed: document.seed)
            editor.shuffleSeed(using: &random)
            take(editor, presetID: presetID)
        case "seed.set":
            var editor = makeEditor()
            editor.setSeed(Self.seed(high: values[0], low: values[1]))
            take(editor, presetID: presetID)
        case "play":
            playing = true
        case "pause":
            playing = false
        case "scrub":
            var clock = SceneClock(duration: Self.duration)
            clock.scrub(to: values[0])
            time = clock.time
        case "rate":
            rate = values[0]
        case "save":
            saves = min(saves + 1, Self.maxSaves)
        case "open":
            let familyIndex = Int(values[0].rounded()), paletteIndex = Int(values[1].rounded())
            guard FamilyCatalog.all.indices.contains(familyIndex) else { return .rejected(.outOfRange(index: 0)) }
            guard FamilyCatalog.palettes.indices.contains(paletteIndex) else {
                return .rejected(.outOfRange(index: 1))
            }
            let family = FamilyCatalog.all[familyIndex]
            let opened = ArtDocument(id: document.id, family: family.id, seed: Self.seed(high: values[2], low: values[3]),
                                     paletteID: FamilyCatalog.palettes[paletteIndex].id,
                                     parameters: family.schema.defaults, previewTime: values[4])
            guard let valid = try? opened.validated().document else { return rule("a01.invalid-document") }
            document = valid
            presetID = nil
            baseline = valid.parameters
            var clock = SceneClock(duration: Self.duration)
            clock.scrub(to: valid.previewTime)
            time = clock.time
        case "rebase":
            baseline = document.parameters
        default:
            return applyParameter(action)
        }
        return .accepted
    }

    /// `parameter.<name>`, `value.<name>` and `reset.<name>`.
    private mutating func applyParameter(_ action: ExperienceAction) -> ActionResult {
        let parts = action.control.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2, ["parameter", "value", "reset"].contains(parts[0]) else {
            return .rejected(.unknownControl(action.control))
        }
        let name = parts[1]
        guard family.schema.definition(name) != nil else { return rule("a01.no-parameter") }
        var editor = makeEditor()
        switch parts[0] {
        case "parameter":
            editor.setParameter(name, normalized: action.values[0])
        case "value":
            var values = editor.editor
            _ = values.set(name, to: action.values[0])
            editor.updateEditor(values)
        default:
            editor.resetParameter(name)
        }
        take(editor, presetID: presetID)
        return .accepted
    }

    public mutating func reset() {
        self = GenerativeArtCore(seed: seed)
    }

    /// `work-saved` once the composition was saved (feature 193; data-model section 2).
    public var outcome: ExperienceOutcome? {
        saves > 0 ? ExperienceOutcome(code: "work-saved") : nil
    }

    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(seed)
        builder.add(document.familyID)
        builder.add(presetID ?? "")
        builder.add(document.seed)
        builder.add(document.paletteID)
        builder.add(count: document.parameters.count)
        for name in document.parameters.keys.sorted() {
            builder.add(name)
            try builder.add(document.parameters[name] ?? 0)
        }
        builder.add(count: baseline.count)
        for name in baseline.keys.sorted() {
            builder.add(name)
            try builder.add(baseline[name] ?? 0)
        }
        try builder.add(time)
        builder.add(playing)
        try builder.add(rate)
        builder.add(saves)
    }

    // MARK: Helpers

    /// The document as the standalone app would save it now: the composition with the current time as its
    /// preview time.
    public var savedDocument: ArtDocument {
        var saved = document
        saved.previewTime = min(time, ArtDocument.maxPreviewTime)
        return saved
    }

    /// The seed made of two 32-bit halves.
    public static func seed(high: Double, low: Double) -> UInt64 {
        (UInt64(UInt32(clamping: Int64(high.rounded()))) << 32) | UInt64(UInt32(clamping: Int64(low.rounded())))
    }

    /// The two 32-bit halves of `seed`, as action values.
    public static func halves(of seed: UInt64) -> (high: Double, low: Double) {
        (Double(seed >> 32), Double(seed & 0xFFFF_FFFF))
    }

    /// The app's editor on the current composition with the current baseline.
    private func makeEditor() -> CompositionEditor {
        var base = document
        base.parameters = baseline
        var editor = CompositionEditor(family: family, document: base)
        var values = editor.editor
        for (name, value) in document.parameters { _ = values.set(name, to: value) }
        editor.updateEditor(values)
        return editor
    }

    /// Takes the editor's composition and baseline; the document id stays the experience's.
    private mutating func take(_ editor: CompositionEditor, presetID: String?, keepID: Bool = true) {
        var next = editor.composition
        if keepID { next.id = document.id }
        document = next
        baseline = editor.editor.baseline
        self.presetID = presetID
    }

    private func rule(_ code: String) -> ActionResult {
        .rejected(.rule(code: code))
    }
}
