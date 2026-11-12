// CatalogSearch — feature 187 T-U01-014 (FR-U01-023, FR-U01-024; research R4; data-model section 9).
// Search that gives the same results on every device: no step depends on a language or region setting.
import Foundation

/// Text folding for the catalog search.
public enum CatalogSearch {
    /// Folds text for comparison: compatibility decomposition, removal of combining marks, lower case by the
    /// language-independent Unicode mapping, the dotless i read as i, and every run of white space as one space
    /// (none at the ends).
    public static func fold(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        var spacePending = false
        for scalar in text.decomposedStringWithCompatibilityMapping.unicodeScalars {
            switch scalar.properties.generalCategory {
            case .nonspacingMark, .spacingMark, .enclosingMark:
                continue
            default:
                break
            }
            if scalar.properties.isWhitespace {
                spacePending = !scalars.isEmpty
                continue
            }
            if spacePending {
                scalars.append(" ")
                spacePending = false
            }
            scalars.append(scalar)
        }
        var folded = ""
        for character in String(scalars).lowercased() {
            folded.append(character == "\u{0131}" ? "i" : character)
        }
        return folded
    }

    /// The folded fields of one entry, computed once when the catalog is loaded.
    struct Fields: Sendable, Equatable {
        let title: String
        let tags: [String]
        let summary: String

        init(_ entry: ExperienceDescriptor) {
            title = fold(entry.title)
            tags = entry.tags.map(fold)
            summary = fold(entry.summary)
        }

        /// The best field that contains the word: 0 title, 1 tags, 2 summary; `nil` when none does.
        func rank(of word: String) -> Int? {
            if title.contains(word) { return 0 }
            if tags.contains(where: { $0.contains(word) }) { return 1 }
            return summary.contains(word) ? 2 : nil
        }
    }
}

extension CatalogManifest {
    /// Searches title, tags and summary. Every word of the text must be contained in a folded field; an entry's
    /// rank is the weakest field any word needed (title, then tags, then summary); results are ordered by rank and
    /// then by catalog order. An empty text returns every entry in catalog order.
    public func search(_ text: String) -> [ExperienceDescriptor] {
        let words = CatalogSearch.fold(text).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return experiences }
        var hits: [(rank: Int, index: Int)] = []
        for (index, fields) in searchFields.enumerated() {
            var weakest = 0
            var matches = true
            for word in words {
                guard let rank = fields.rank(of: word) else { matches = false; break }
                weakest = max(weakest, rank)
            }
            if matches { hits.append((weakest, index)) }
        }
        return hits.sorted { ($0.rank, $0.index) < ($1.rank, $1.index) }.map { experiences[$0.index] }
    }
}
