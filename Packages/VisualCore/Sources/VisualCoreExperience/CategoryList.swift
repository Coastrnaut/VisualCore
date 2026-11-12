// CategoryList — feature 187 T-U01-014 (FR-U01-022; data-model section 4).
import Foundation

/// The launcher categories with their order and titles (`Catalog/categories.json`, schema 1).
public struct CategoryList: Sendable, Equatable {
    /// One category of the list.
    public struct Entry: Sendable, Equatable {
        /// The category.
        public let id: ExperienceCategory
        /// The title the launcher shows (1 to 40 characters).
        public let title: String
    }

    /// The categories in launcher order.
    public let categories: [Entry]

    init(entries: [Entry]) { categories = entries }

    /// Loads and validates the category list: the size cap of the catalog, schema 1, exactly the seven categories in
    /// launcher order, each with a title. Throws one `CatalogError`.
    public init(data: Data) throws(CatalogError) {
        guard data.count <= CatalogManifest.maxBytes else { throw .tooLarge(bytes: data.count, limit: CatalogManifest.maxBytes) }
        let top = try JSONFields.root(of: data, name: "categories")
        let schema = try top.whole("schema", Int(Int32.min)...Int(Int32.max))
        guard schema == CatalogManifest.supportedSchema else {
            throw .unsupportedSchema(found: schema, supported: CatalogManifest.supportedSchema)
        }
        try top.requireOnly(["schema", "categories"])
        guard let list = top.object["categories"] as? [Any] else { throw .wrongType(entry: top.entry, field: "categories") }
        var entries: [Entry] = []
        for (index, item) in list.prefix(ExperienceCategory.allCases.count + 1).enumerated() {
            let position = "#\(index)"
            guard let object = item as? [String: Any] else { throw .wrongType(entry: position, field: "categories") }
            let fields = JSONFields(entry: position, object: object)
            try fields.requireOnly(["id", "title"])
            guard let id = ExperienceCategory(rawValue: try fields.text("id")) else {
                throw .invalidValue(entry: position, field: "id", reason: "one of the seven launcher categories")
            }
            entries.append(Entry(id: id, title: try fields.text("title", 1...40)))
        }
        guard list.count == ExperienceCategory.allCases.count, entries.map(\.id) == ExperienceCategory.allCases else {
            throw .invalidValue(entry: top.entry, field: "categories", reason: "exactly the seven categories in launcher order")
        }
        categories = entries
    }

    /// The title of a category, if the list holds it.
    public func title(of category: ExperienceCategory) -> String? { categories.first { $0.id == category }?.title }
}
