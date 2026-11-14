# Contract: A09-P01 experience types and actions

## DigitalAquariumCore (public within the package, `///`-documented)

- `SpeciesCatalog` — `static let bundled: SpeciesCatalog`; `species`, `plants`, `habitats`; `encoded() -> Data`;
  `static func decode(_ data: Data) -> (catalog: SpeciesCatalog, refused: [CatalogRefusal])` (valid items kept,
  refused ones named with `CatalogError` and id).
- `LicenseAudit` — `static func rows(_ catalog:) -> [LicenseRow]` (kind, id, name, author, license); `static func
  problems(_ catalog:) -> [String]`; `static func markdown(_ catalog:) -> String` (the document's text).
- `HabitatDocument` — `static func starter(_ index: Int, catalog:, random: inout SeededRandom) -> HabitatDocument`;
  `validate() -> [String]`.
- `AquariumSimulation` — `static let step = 1.0 / 60`; `static func advance(_ doc: inout HabitatDocument, catalog:,
  random: inout SeededRandom)`.

## Experience actions (`a09.digital-aquarium`)

`habitat.select [0…1]`, `lighting.level [0…2]`, `motion.pause [0…1]`; refused values give typed rejections with codes
`a09.*`. Snapshot schema 1 = `AquariumState`.
