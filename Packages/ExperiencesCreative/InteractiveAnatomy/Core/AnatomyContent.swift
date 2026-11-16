// AnatomyContent — feature 124 (A17-P01) T-A17-107 (data-model "ContentRefusal"; contracts/core.md). Reads,
// validates, labels and writes region content; nothing here crashes on input.
//
// `decode(_:)` refuses, in this order: `tooLarge` (more than 262,144 bytes), `damaged` (not a JSON object, no integer
// `schema`, a schema below 1), `newerVersion` (a schema above 1), `damaged` (any other decoding failure), and then
// whatever `validate(_:)` refuses.
//
// `validate(_:)` returns the first problem, checking in this order:
// a. the bounds are finite and `min` is below `max` on every axis (`nonFinite`);
// b. ids are unique across structures and meshes, and no mesh is listed twice (`duplicateID`);
// c. ids, names and descriptions are not empty; a description has 1–3 sentences and at most 400 characters
//    (`emptyText`);
// d. no description uses a clinical word, matched case-insensitively as a whole word or phrase (`clinicalText`);
// e. every structure has sources (`unsourced`) and each resolves to a citation (`missingReference`);
// f. every licence is allowed (`badLicense`);
// g. exactly one root (`parentCycle` for none, `missingReference` for several), the root without layer or meshes
//    (`damaged`), every part with a layer and 1–3 meshes (`missingReference`);
// h. parents, neighbours and meshes resolve, neighbours are symmetric and never the structure itself, and every
//    declared mesh is owned (`missingReference`);
// i. no parent chain returns to itself (`parentCycle`);
// j. no synonym equals another structure's synonym, English name or standard name, ignoring case
//    (`collidingSynonym`).
import Foundation
import VisualCoreMath

/// Reading, validating, labelling and writing anatomy region content.
public enum AnatomyContent {
    /// The largest content accepted, in bytes.
    public static let maxBytes = 262_144

    /// The clinical words and phrases a description must not use (whole words, ignoring case).
    public static let clinicalWords: [String] = ["diagnose", "diagnosis", "symptom", "symptoms", "treatment", "treat",
                                                 "cure", "injury advice", "medical advice"]

    /// The longest description accepted, in characters.
    static let maxDescriptionCharacters = 400

    /// Decodes and validates region content; the result is the region or the first refusal.
    public static func decode(_ data: Data) -> Result<AnatomyRegion, ContentRefusal> {
        guard data.count <= maxBytes else {
            return .failure(ContentRefusal(.tooLarge, "The content is \(data.count) bytes, more than the limit of \(maxBytes)."))
        }
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return .failure(ContentRefusal(.damaged, "The content is not a JSON object."))
        }
        guard let number = object["schema"] as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              let schema = Int(exactly: number.doubleValue) else {
            return .failure(ContentRefusal(.damaged, "The content has no whole-number schema."))
        }
        if schema > AnatomyRegion.schemaVersion {
            return .failure(ContentRefusal(.newerVersion, "The content uses schema \(schema), newer than schema \(AnatomyRegion.schemaVersion)."))
        }
        if schema < 1 {
            return .failure(ContentRefusal(.damaged, "The content uses schema \(schema), which does not exist."))
        }
        let region: AnatomyRegion
        do {
            region = try JSONDecoder().decode(AnatomyRegion.self, from: data)
        } catch {
            return .failure(ContentRefusal(.damaged, "The content does not match schema \(schema)."))
        }
        if let refusal = validate(region) { return .failure(refusal) }
        return .success(region)
    }

    /// Validates a region and returns its first problem, or nil when it is valid.
    public static func validate(_ region: AnatomyRegion) -> ContentRefusal? {
        let structures = region.structures
        // a. Bounds.
        let (low, high) = (region.bounds.min, region.bounds.max)
        guard low.isFinite, high.isFinite else {
            return ContentRefusal(.nonFinite, "The bounds of \(region.id) are not finite.")
        }
        guard low.x < high.x, low.y < high.y, low.z < high.z else {
            return ContentRefusal(.nonFinite, "The bounds of \(region.id) are empty.")
        }
        // b. Unique ids; each mesh listed once.
        var seen = Set<String>()
        for id in structures.map(\.id) + region.meshes.map(\.id) where !seen.insert(id).inserted {
            return ContentRefusal(.duplicateID, "The id \(id) is used more than once.")
        }
        var owner: [String: String] = [:]
        for structure in structures {
            for mesh in structure.meshIDs {
                if let first = owner[mesh] {
                    return ContentRefusal(.duplicateID, "The mesh \(mesh) is listed by both \(first) and \(structure.id).")
                }
                owner[mesh] = structure.id
            }
        }
        // c. Text.
        for structure in structures {
            if let refusal = textRefusal(structure) { return refusal }
        }
        // d. Clinical words.
        for structure in structures {
            if let word = clinicalWord(in: structure.description) {
                return ContentRefusal(.clinicalText, "The description of \(structure.id) uses the clinical word \"\(word)\".")
            }
        }
        // e. Sources.
        let citations = Set(region.manifest.citations.map(\.id))
        for structure in structures {
            if structure.sourceRefs.isEmpty {
                return ContentRefusal(.unsourced, "The structure \(structure.id) has no source.")
            }
            for ref in structure.sourceRefs where !citations.contains(ref) {
                return ContentRefusal(.missingReference, "The structure \(structure.id) cites \(ref), which is not in the manifest.")
            }
        }
        // f. Licences.
        let allowed = ContentManifest.allowedLicenses
        if !allowed.contains(region.manifest.textLicense) {
            return ContentRefusal(.badLicense, "The text licence \(region.manifest.textLicense) is not allowed.")
        }
        if !allowed.contains(region.manifest.geometryLicense) {
            return ContentRefusal(.badLicense, "The geometry licence \(region.manifest.geometryLicense) is not allowed.")
        }
        for citation in region.manifest.citations where !allowed.contains(citation.license) {
            return ContentRefusal(.badLicense, "The citation \(citation.id) has the licence \(citation.license), which is not allowed.")
        }
        // g. Root and parts.
        let roots = structures.filter { $0.parent == nil }
        guard let root = roots.first else {
            return ContentRefusal(.parentCycle, "No structure of \(region.id) is without a parent.")
        }
        if roots.count > 1 {
            return ContentRefusal(.missingReference, "The structure \(roots[1].id) has no parent.")
        }
        if root.layer != nil || !root.meshIDs.isEmpty {
            return ContentRefusal(.damaged, "The root \(root.id) must have no layer and no meshes.")
        }
        for part in structures where part.parent != nil {
            if part.layer == nil {
                return ContentRefusal(.missingReference, "The structure \(part.id) has no layer.")
            }
            if part.meshIDs.isEmpty {
                return ContentRefusal(.missingReference, "The structure \(part.id) has no mesh.")
            }
            if part.meshIDs.count > 3 {
                return ContentRefusal(.missingReference, "The structure \(part.id) has \(part.meshIDs.count) meshes, more than 3.")
            }
        }
        // h. References.
        let byID = Dictionary(structures.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let meshIDs = Set(region.meshes.map(\.id))
        for structure in structures {
            if let parent = structure.parent, byID[parent] == nil {
                return ContentRefusal(.missingReference, "The structure \(structure.id) has the parent \(parent), which does not exist.")
            }
            for neighbour in structure.neighbours {
                guard let other = byID[neighbour] else {
                    return ContentRefusal(.missingReference, "The structure \(structure.id) lists the neighbour \(neighbour), which does not exist.")
                }
                if neighbour == structure.id {
                    return ContentRefusal(.missingReference, "The structure \(structure.id) lists itself as a neighbour.")
                }
                if !other.neighbours.contains(structure.id) {
                    return ContentRefusal(.missingReference, "\(structure.id) lists \(neighbour) as a neighbour, but \(neighbour) does not list \(structure.id).")
                }
            }
            for mesh in structure.meshIDs where !meshIDs.contains(mesh) {
                return ContentRefusal(.missingReference, "The structure \(structure.id) lists the mesh \(mesh), which is not declared.")
            }
        }
        for mesh in region.meshes where owner[mesh.id] == nil {
            return ContentRefusal(.missingReference, "The mesh \(mesh.id) belongs to no structure.")
        }
        // i. Parent cycles.
        for structure in structures {
            var visited: Set<String> = [structure.id]
            var current = structure.parent
            while let id = current {
                if !visited.insert(id).inserted {
                    return ContentRefusal(.parentCycle, "The parents of \(structure.id) form a cycle.")
                }
                current = byID[id]?.parent
            }
        }
        // j. Synonyms.
        for structure in structures {
            for synonym in structure.synonyms {
                let key = synonym.lowercased()
                for other in structures where other.id != structure.id {
                    let names = other.synonyms + [other.englishName, other.standardName]
                    if names.contains(where: { $0.lowercased() == key }) {
                        return ContentRefusal(.collidingSynonym, "The synonym \"\(synonym)\" of \(structure.id) is also a name of \(other.id).")
                    }
                }
            }
        }
        return nil
    }

    /// The labels of a region: one per part, in structure order, with its English name at its first mesh; the root
    /// has none.
    public static func labels(_ region: AnatomyRegion) -> [AnatomyLabel] {
        region.structures.compactMap { structure in
            guard structure.parent != nil, let mesh = structure.meshIDs.first else { return nil }
            return AnatomyLabel(structureID: structure.id, text: structure.englishName, anchorMeshID: mesh)
        }
    }

    /// The bundled right knee (`Content/knee-right.pack.json`, a content pack of schema 2 since feature 127,
    /// A17-P04, T-A17-404), decoded by `AnatomyContentPack.decode(_:)` and validated; throws the `ContentRefusal`.
    public static func bundledRightKnee() throws -> AnatomyRegion {
        guard let url = Bundle.module.url(forResource: "knee-right.pack", withExtension: "json", subdirectory: "Content"),
              let data = try? Data(contentsOf: url) else {
            throw ContentRefusal(.damaged, "The bundled file knee-right.pack.json is missing.")
        }
        return try AnatomyContentPack.decode(data).get()
    }

    /// The region as JSON with sorted keys, pretty printed, slashes unescaped.
    public static func encoded(_ region: AnatomyRegion) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        return (try? encoder.encode(region)) ?? Data()
    }

    /// The first text problem of a structure, or nil.
    static func textRefusal(_ structure: AnatomicalStructure) -> ContentRefusal? {
        let fields = [("id", structure.id), ("standard name", structure.standardName),
                      ("English name", structure.englishName), ("description", structure.description)]
        for (name, value) in fields where value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let subject = structure.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "A structure" : "The structure \(structure.id)"
            return ContentRefusal(.emptyText, "\(subject) has an empty \(name).")
        }
        let text = structure.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count > maxDescriptionCharacters {
            return ContentRefusal(.emptyText, "The description of \(structure.id) has \(text.count) characters, more than \(maxDescriptionCharacters).")
        }
        let count = sentenceCount(text)
        if !(1...3).contains(count) || !(text.last.map { ".!?".contains($0) } ?? false) {
            return ContentRefusal(.emptyText, "The description of \(structure.id) must be one to three complete sentences.")
        }
        return nil
    }

    /// The number of '.', '!' or '?' characters followed by whitespace or the end of the text.
    static func sentenceCount(_ text: String) -> Int {
        let characters = Array(text)
        return characters.indices.filter { index in
            ".!?".contains(characters[index])
                && (index + 1 == characters.count || characters[index + 1].isWhitespace)
        }.count
    }

    /// The first clinical word or phrase the text uses as a whole word, ignoring case, or nil.
    static func clinicalWord(in text: String) -> String? {
        let words = text.lowercased().split { !$0.isLetter }.joined(separator: " ")
        let padded = " \(words) "
        return clinicalWords.first { padded.contains(" \($0) ") }
    }
}
