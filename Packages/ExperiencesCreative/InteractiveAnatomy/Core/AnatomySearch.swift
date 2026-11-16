// AnatomySearch — feature 126 (A17-P03) T-A17-303 (FR-A17-301; SC-A17-301; clarification Q1; data-model
// "AnatomySearch.Result"; contracts/layers-search.md). The structure search of Interactive Anatomy.
//
// The query and every field are folded with `CatalogSearch.fold` (compatibility decomposition, no combining marks,
// language-independent lower case, white space runs as one space, none at the ends). A field matches when it equals
// the query, or when the field's text from the start of one of its words begins with the query (a word starts at the
// beginning of the field or after a character that is neither a letter nor a digit), so multi-word queries such as
// "patellar ten" match. Ranks: 0 an exact English or standard name, 1 a name word prefix, 2 an exact synonym, 3 a
// synonym word prefix, 4 a description word prefix (only for queries of 3 or more characters). Each part appears once
// at its best rank; results are ordered by rank, then by inventory index (the parts are the structures with a parent,
// in content order), at most 14. An empty query lists every part in inventory order, each with rank 0 and its English
// name as the matched text.
import Foundation
import VisualCoreExperience

/// The structure search (see the file header).
public enum AnatomySearch {
    /// The most results a search returns (the knee's 14 parts).
    public static let maxResults = 14
    /// The shortest folded query that may match a description.
    public static let descriptionMinimumLength = 3

    /// One search result.
    public struct Result: Equatable, Sendable {
        /// The part's inventory index (among the structures with a parent, in content order).
        public let index: Int
        /// The rank of the best match: 0 exact name, 1 name word prefix, 2 exact synonym, 3 synonym word prefix,
        /// 4 description word prefix.
        public let rank: Int
        /// The unfolded field text that matched (a name, a synonym or the description).
        public let matched: String

        /// Creates a result.
        public init(index: Int, rank: Int, matched: String) {
            self.index = index
            self.rank = rank
            self.matched = matched
        }
    }

    /// The parts of `region` matching `query`, ranked (see the file header).
    public static func results(_ query: String, region: AnatomyRegion) -> [Result] {
        let parts = region.structures.filter { $0.parent != nil }
        let folded = CatalogSearch.fold(query)
        if folded.isEmpty {
            return parts.enumerated().prefix(maxResults).map { Result(index: $0.offset, rank: 0, matched: $0.element.englishName) }
        }
        var hits: [Result] = []
        for (index, part) in parts.enumerated() {
            if let hit = bestMatch(folded, part: part, index: index) { hits.append(hit) }
        }
        hits.sort { ($0.rank, $0.index) < ($1.rank, $1.index) }
        return Array(hits.prefix(maxResults))
    }

    /// The best match of the folded `query` in `part`, or nil.
    static func bestMatch(_ query: String, part: AnatomicalStructure, index: Int) -> Result? {
        let names = [part.englishName, part.standardName]
        if let name = names.first(where: { CatalogSearch.fold($0) == query }) {
            return Result(index: index, rank: 0, matched: name)
        }
        if let name = names.first(where: { wordPrefixMatches(query, CatalogSearch.fold($0)) }) {
            return Result(index: index, rank: 1, matched: name)
        }
        if let synonym = part.synonyms.first(where: { CatalogSearch.fold($0) == query }) {
            return Result(index: index, rank: 2, matched: synonym)
        }
        if let synonym = part.synonyms.first(where: { wordPrefixMatches(query, CatalogSearch.fold($0)) }) {
            return Result(index: index, rank: 3, matched: synonym)
        }
        if query.count >= descriptionMinimumLength, wordPrefixMatches(query, CatalogSearch.fold(part.description)) {
            return Result(index: index, rank: 4, matched: part.description)
        }
        return nil
    }

    /// Whether the folded `field`, from the start of one of its words, begins with the folded `query`.
    static func wordPrefixMatches(_ query: String, _ field: String) -> Bool {
        guard !query.isEmpty else { return false }
        var previous: Character?
        var position = field.startIndex
        while position < field.endIndex {
            let character = field[position]
            let startsWord = previous.map { !($0.isLetter || $0.isNumber) } ?? true
            if startsWord, field[position...].hasPrefix(query) { return true }
            previous = character
            position = field.index(after: position)
        }
        return false
    }
}
