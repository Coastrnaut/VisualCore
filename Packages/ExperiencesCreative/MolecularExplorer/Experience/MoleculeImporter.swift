// MoleculeImporter — feature 114 (A15-P05) T-A15-506 (FR-A15-501–506, FR-A15-540; clarifications Q1–Q3; plan
// "Lifecycle"; contracts/import.md). Opens a person's own XYZ file and hands it to the engine as ordinary actions, then
// keeps the accepted bytes for the recent list. `importFile(at:isActive:send:)` runs, in order:
//   1. only while the experience is active; otherwise it returns `.inactive` without touching the file (the person can
//      import again);
//   2. starts security-scoped access to the picked URL (stopped again once the bytes are read, on every path);
//   3. reads the size from `URL.resourceValues(forKeys: [.fileSizeKey])` and refuses above 65,536 bytes with
//      `MoleculeImport.sizeRefusal(byteCount:)` WITHOUT reading the bytes (``readCount`` counts the reads);
//   4. reads the bytes; a failure gives `MoleculeImport.unreadableSentence` (the byte count is checked again, for a
//      file whose size could not be read);
//   5. parses them with `XYZParser.parse(_:)` (a refusal gives `MoleculeImport.sentence(_:)`) and checks the atoms with
//      `ImportedMolecule.make(atoms:)`, the rule `import.end` applies, so a file the engine would refuse never replaces
//      the stored copy;
//   6. sends `MoleculeImport.actions(_:)` (begin, one atom per line, end, select 5) one by one, stopping at the first
//      refusal, as Digital Aquarium's `AquariumLibrary.open` does;
//   7. only once the engine accepted every action, writes `import.xyz` (the bytes) and `import-title.txt`
//      (`MoleculeImport.title(fileName:)` of the file's name) through `ExperienceStorage`, replacing the previous ones;
//      a refused write still imports and reports the storage error's code (the presenter shows "The molecule was opened
//      but could not be kept for the recent list (<storage code>).").
// Every refusal changes nothing: no file is written, and before step 6 no action is sent. ``replay(send:)`` sends the
// stored copy again (choosing `imported` from the recent list when the engine holds no import); it reports false for a
// missing, unreadable or refused copy. Without storage (previews and tests) the two files are kept in memory with the
// same rules. The importer never presents a picker; the controls do (`.fileImporter`).
import Foundation
import MolecularExplorerCore
import VisualCoreExperience

/// A sentence to show for a refused import, as an error value.
struct MoleculeImportSentence: Error, Equatable {
    /// The sentence.
    let text: String
}

/// Opens XYZ files into Molecular Explorer and keeps the accepted copy (see the file header).
@MainActor
final class MoleculeImporter {
    /// The stored copy of the last accepted file.
    static let fileName = "import.xyz"
    /// The stored title of the last accepted file.
    static let titleFileName = "import-title.txt"

    /// Reads the bytes of a picked file.
    typealias Reader = (URL) throws -> Data
    /// Reads the size in bytes of a picked file, or nil when it is not known.
    typealias SizeReader = (URL) -> Int?
    /// Sends one action (control and values) and returns the experience's answer.
    typealias Send = (String, [Double]) -> ActionResult

    /// What an import came to.
    enum Outcome: Equatable {
        /// The molecule was imported: its title, its atom count and the storage error code when the copy could not
        /// be kept (nil when it was).
        case imported(title: String, atoms: Int, storageCode: String?)
        /// The file was refused, with the sentence to show; nothing changed.
        case refused(String)
        /// The experience was not active: the file was not read and nothing changed.
        case inactive
    }

    /// The experience's storage, or nil to keep the copy in memory.
    let storage: ExperienceStorage?
    /// Reads a picked file's bytes.
    private let reader: Reader
    /// Reads a picked file's size.
    private let sizeReader: SizeReader
    /// The two files when there is no storage, by name.
    private var memory: [String: Data] = [:]
    /// Whether the stored copy reads and parses; nil until asked after the last write.
    private var readableCopy: Bool?
    /// How many times the bytes of a picked file were read (tests: an oversized file is never read).
    private(set) var readCount = 0

    /// An importer keeping its copy in `storage` (nil: in memory), reading picked files with `reader` and their size
    /// with `sizeReader` (nil: the file system's).
    init(storage: ExperienceStorage?, reader: Reader? = nil, sizeReader: SizeReader? = nil) {
        self.storage = storage
        self.reader = reader ?? { try Data(contentsOf: $0) }
        self.sizeReader = sizeReader ?? MoleculeImporter.fileSize
    }

    /// The size in bytes of the file at `url` from its resource values, or nil when it cannot be read.
    nonisolated static func fileSize(_ url: URL) -> Int? {
        (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
    }

    /// The sentence of an import the engine refused although the file parsed (never for a parsed file, kept total):
    /// "The molecule could not be opened (<result code>)."
    nonisolated static func engineRefusalSentence(_ code: String) -> String {
        "The molecule could not be opened (\(code))."
    }

    /// Imports the file at `url` when `isActive`, sending its actions through `send` (see the file header).
    func importFile(at url: URL, isActive: Bool, send: Send) -> Outcome {
        guard isActive else { return .inactive }
        let data: Data
        switch readPicked(url) {
        case .failure(let sentence): return .refused(sentence.text)
        case .success(let bytes): data = bytes
        }
        let parsed: ParsedXYZ
        switch Self.checked(data) {
        case .failure(let sentence): return .refused(sentence.text)
        case .success(let value): parsed = value
        }
        let title = MoleculeImport.title(fileName: url.lastPathComponent)
        // The engine answers first: a refused action leaves the stored copy as it was (FR-A15-503).
        if let refused = Self.send(parsed, through: send) {
            return .refused(Self.engineRefusalSentence(refused.code))
        }
        let code = keep(data, title: title)
        return .imported(title: title, atoms: parsed.atoms.count, storageCode: code)
    }

    /// The bytes of the picked file at `url` under security-scoped access, refused above the size limit before they
    /// are read and refused when they cannot be read.
    private func readPicked(_ url: URL) -> Result<Data, MoleculeImportSentence> {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        if let size = sizeReader(url), let refusal = MoleculeImport.sizeRefusal(byteCount: size) {
            return .failure(MoleculeImportSentence(text: refusal))
        }
        readCount += 1
        guard let data = try? reader(url) else {
            return .failure(MoleculeImportSentence(text: MoleculeImport.unreadableSentence))
        }
        if let refusal = MoleculeImport.sizeRefusal(byteCount: data.count) {
            return .failure(MoleculeImportSentence(text: refusal))
        }
        return .success(data)
    }

    /// The parse of `data` when the parser and `ImportedMolecule.make(atoms:)` accept it, else the refusal sentence.
    nonisolated static func checked(_ data: Data) -> Result<ParsedXYZ, MoleculeImportSentence> {
        switch XYZParser.parse(data) {
        case .failure(let refusal):
            return .failure(MoleculeImportSentence(text: MoleculeImport.sentence(refusal)))
        case .success(let parsed):
            if case .failure(let reason) = ImportedMolecule.make(atoms: parsed.atoms) {
                return .failure(MoleculeImportSentence(text: MoleculeImport.sentence(XYZRefusal(reason))))
            }
            return .success(parsed)
        }
    }

    /// Sends the actions of `parsed` through `send` one by one; nil when every one was accepted, else the first
    /// refused action's answer (the rest are not sent).
    static func send(_ parsed: ParsedXYZ, through send: Send) -> ActionResult? {
        for action in MoleculeImport.actions(parsed) {
            let result = send(action.control, action.values)
            if !result.isAccepted { return result }
        }
        return nil
    }

    /// Writes `data` as `import.xyz` and `title` as `import-title.txt`; nil when both were written, else the storage
    /// error's code (a file already written stays written).
    private func keep(_ data: Data, title: String) -> String? {
        readableCopy = nil
        guard let storage else {
            memory[Self.fileName] = data
            memory[Self.titleFileName] = Data(title.utf8)
            return nil
        }
        do {
            try storage.write(data, to: Self.fileName)
            try storage.write(Data(title.utf8), to: Self.titleFileName)
        } catch {
            return error.code
        }
        return nil
    }

    /// The bytes stored as `name`, or nil when there are none or they cannot be read.
    private func stored(_ name: String) -> Data? {
        guard let storage else { return memory[name] }
        return try? storage.read(name)
    }

    /// The stored copy when it reads and passes the parser and the import rule; nil otherwise.
    func storedCopy() -> ParsedXYZ? {
        guard let data = stored(Self.fileName), MoleculeImport.sizeRefusal(byteCount: data.count) == nil,
              case .success(let parsed) = Self.checked(data) else { return nil }
        return parsed
    }

    /// Whether the stored copy reads and passes (computed once after each write; ``forgetCopyCheck()`` asks again).
    var hasReadableCopy: Bool {
        if let readableCopy { return readableCopy }
        let readable = storedCopy() != nil
        readableCopy = readable
        return readable
    }

    /// Forgets whether the stored copy was readable, so the next ``hasReadableCopy`` reads it again.
    func forgetCopyCheck() {
        readableCopy = nil
    }

    /// The stored title, cleaned again as a title (a changed file shows only the characters a title keeps, at most 40,
    /// "Imported molecule" when none is left); nil when there is none, it is longer than 160 bytes or it is not UTF-8
    /// text.
    func storedTitle() -> String? {
        guard let data = stored(Self.titleFileName), data.count <= 4 * MoleculeImport.titleLimit,
              let text = String(data: data, encoding: .utf8) else { return nil }
        return MoleculeImport.title(fileName: text + ".xyz")
    }

    /// Sends the stored copy's actions through `send`; false when the copy is missing, unreadable or refused (by the
    /// parser, the import rule or the engine; the actions after a refusal are not sent).
    func replay(send: Send) -> Bool {
        guard let parsed = storedCopy() else {
            readableCopy = false
            return false
        }
        return Self.send(parsed, through: send) == nil
    }
}
