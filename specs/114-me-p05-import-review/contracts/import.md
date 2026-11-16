# Contract: import and review (feature 114)

```swift
// Core
public enum MoleculeImport {
    public static let maxBytes = XYZParser.maxBytes                       // 65_536
    public static let titleLimit = 40
    public static func title(fileName: String) -> String                   // sanitized; "Imported molecule" when empty
    public static func sizeRefusal(byteCount: Int) -> String?               // "This file is larger than 64 KB, the limit for a molecule file."
    public static func sentence(_ refusal: XYZRefusal) -> String            // "This file could not be opened: <reason> (line N)."
    public static let unreadableSentence = "The file could not be read."
    public static func actions(_ parsed: ParsedXYZ) -> [(control: String, values: [Double])]  // begin, atom × n, end, select 5
}
public struct ImportedMolecule: Codable, Equatable, Sendable { public let molecule: Molecule }   // no title in the engine
// ImportedMolecule.make(atoms: [Atom]) -> Result<ImportedMolecule, XYZRefusal.Reason>: the single check of the import
// limits (count, elements, finite, magnitude, minimum distance) with inferred single bonds; used by import.end and the fuzz test.
public enum MoleculeReview {
    public static let inferredStatement = "Bonds marked inferred are estimated from atom distances."
    public static let claimWords: [String]                                  // clarification Q5
    public static func document() -> String                                 // docs/apps/molecular-explorer/data-review.md
    public static func claimWords(in sentence: String) -> [String]
}
```

Engine actions (adapter `MoleculeCore`): `import.begin [1…500]`, `import.atom [Z ∈ {1,6,7,8,9,15,16,17,35,53},
x, y, z ∈ −1000…1000]`, `import.end []`; refusal `a15.invalid-import`. `molecule.select` ranges 0…5 (5 refused
without an import). The title travels outside the actions: `import.end` names the molecule "Imported molecule" and the
presenter shows the file title stored beside `import.xyz` (`import-title.txt`, ≤ 40 characters).

Experience: `MoleculeImporter.importFile(at: URL) -> String?` (nil on success, else the sentence); the Import button
`import` (label "Import XYZ file", hint "Opens a small XYZ file from Files"); panel line `inferred-note`.
